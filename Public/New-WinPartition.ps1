#requires -Version 3 -Modules Storage
Function New-WinPartition {
<#
.SYNOPSIS 
   Creates partitions on disk for Windows.

.DESCRIPTION
   Erases disk and creates partitions for MBR, GPT or USB disks for Windows to be installed on.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 1

   PS C:\> New-WinPartition -Disk $disk -USB

   Formats a USB device for WinPE and auto assigns a drive letter.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 0

   PS C:\> New-WinPartition -Disk $disk -OSDriveLetter C -BootDriveLetter S -MBR

   Creates a MBR formated disk for Windows Server to be installed on.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 0

   PS C:\> New-WinPartition -Disk $disk -OSDriveLetter C -BootDriveLetter S -Client

   Creates a GPT formated disk for Windows Client to be installed on.
 
.LINK
   http://blog.acubyte.com

.LINK
   Clear-WinPartition

.LINK
   Set-WinBoot
#>
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName = 'GPT')]
    Param (
        [Parameter(Mandatory,ValueFromPipeline)][ciminstance]$Disk,
        [ValidateRange('A','Z')][char]$OSDriveLetter = 'C',
        [ValidateRange('A','Z')][char]$BootDriveLetter = 'S',
        [Parameter(ParameterSetName='MBR')][switch]$MBR,
        [Parameter(ParameterSetName='USB')][switch]$USB,
        [Parameter(ParameterSetName='GPT')]
            [ValidateSet('Client','Server')][string]$Platform = 'Server'
    )
    Begin {
    }
    Process {
        try {
            Clear-WinPartition -Disk $Disk -ErrorAction Stop
            if (Test-Volume -DriveLetter $OSDriveLetter) {
                throw "$OSDriveLetter is already in use"
            } elseif ((Test-Volume -DriveLetter $BootDriveLetter) -and !($USB)) {
                throw "$BootDriveLetter is already in use"
            }
            if ($USB) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR -ErrorAction SilentlyContinue
                $partition = New-Partition -DriveLetter $OSDriveLetter -InputObject $Disk -UseMaximumSize -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'WinPE' -Partition $partition -Confirm:$false
            } elseif ($MBR) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR -ErrorAction SilentlyContinue
                $bootPartition = New-Partition -DriveLetter $BootDriveLetter –InputObject $Disk -Size 350MB -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Partition $bootPartition -Confirm:$false
                $osPartition = New-Partition -DriveLetter $OSDriveLetter –InputObject $Disk -UseMaximumSize
                Format-Volume -FileSystem NTFS -Partition $osPartition -Confirm:$false
            } else {
                $diskpartTemp = "$env:TEMP\diskpart.txt"
                $diskpartLog = "$env:TEMP\WinDeploy.log"
                if ($Platform = 'Client') {
                    New-WinDiskpartScript -DiskNumber $Disk.Number -BootDriveLetter $BootDriveLetter -OSDriveLetter $OSDriveLetter -Platform Client | Out-File -FilePath $diskpartTemp -Encoding ascii
                } else {
                    New-WinDiskpartScript -DiskNumber $Disk.Number -BootDriveLetter $BootDriveLetter -OSDriveLetter $OSDriveLetter | Out-File -FilePath $diskpartTemp -Encoding ascii
                }
                diskpart.exe /s $diskpartTemp | Out-File -FilePath $diskpartLog
                Remove-Item -Path $diskpartTemp
                Write-Output "Format Log: $diskpartLog"
            }
        } catch {
            throw $_
        }
    }
}