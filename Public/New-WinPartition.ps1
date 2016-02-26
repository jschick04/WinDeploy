Function New-WinPartition {
<#
.SYNOPSIS 
Creates partitions on disk for Windows.

.DESCRIPTION
Erases disk and creates partitions for MBR, GPT or USB disks for Windows to be installed on.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 1

C:\PS> New-WinPartition -Disk $disk -USB

Formats a USB device for WinPE and auto assigns a drive letter.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 0

C:\PS> New-WinPartition -Disk $disk -OSDriveLetter C -BootDriveLetter S -MBR

Creates a MBR formated disk for Windows Server to be installed on.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 0

C:\PS> New-WinPartition -Disk $disk -OSDriveLetter C -BootDriveLetter S -Client

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
        [ValidateRange('A','Z')][char]$OSDriveLetter,
        [ValidateRange('A','Z')][char]$BootDriveLetter,
        [Parameter(ParameterSetName='MBR')][switch]$MBR,
        [Parameter(ParameterSetName='USB')][switch]$USB,
        [Parameter(ParameterSetName='GPT')]
            [ValidateSet('Client','Server')][string]$Platform = 'Server'
    )
    Begin {
        if (!$BootDriveLetter) {
            $bootParam = @{AssignDriveLetter=$true}
        } else {
            $bootParam = @{DriveLetter=$BootDriveLetter}
        }
        if (!$OSDriveLetter) {
            $osParam = @{AssignDriveLetter=$true}
        } else {
            $osParam = @{DriveLetter=$OSDriveLetter}
        }
    }
    Process {
        try {
            Clear-WinPartition -Disk $Disk -ErrorAction Stop
            if ($USB) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR -ErrorAction SilentlyContinue
                $partition = New-Partition @osParam -InputObject $Disk -UseMaximumSize -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'WinPE' -Partition $partition -Confirm:$false
                $OSDriveLetter = $partition.DriveLetter
            } elseif ($MBR) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR -ErrorAction SilentlyContinue
                $bootPartition = New-Partition @bootParam –InputObject $Disk -Size 350MB -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Partition $bootPartition -Confirm:$false
                $osPartition = New-Partition @osParam –InputObject $Disk -UseMaximumSize
                Format-Volume -FileSystem NTFS -Partition $osPartition -Confirm:$false
                $BootDriveLetter = $bootPartition.DriveLetter
                $OSDriveLetter = $osPartition.DriveLetter
            } else {
                if (!$BootDriveLetter -or !$OSDriveLetter) {
                    throw 'Boot and OS drive letters must be specified'
                }
                $diskpartTemp = "$env:TEMP\diskpart.txt"
                $diskpartLog = "$env:TEMP\WinDeploy.log"
                if ($Platform = 'Client') {
                    New-WinDiskpartScript -DiskNumber $Disk.Number -BootDriveLetter $BootDriveLetter -OSDriveLetter $OSDriveLetter -Platform Client | Out-File -FilePath $diskpartTemp -Encoding ascii
                } else {
                    New-WinDiskpartScript -DiskNumber $Disk.Number -BootDriveLetter $BootDriveLetter -OSDriveLetter $OSDriveLetter | Out-File -FilePath $diskpartTemp -Encoding ascii
                }
                diskpart.exe /s $diskpartTemp | Out-File -FilePath "$env:TEMP\WinDeploy.log"
                Remove-Item -Path $diskpartTemp
                Write-Output "Format Log: $diskpartLog"
            }
        } catch {
            throw $_
        }
        if (!(Test-Path -Path "$($OSDriveLetter):\")) {
            throw 'OS drive letter is missing'
            if ($BootDriveLetter) {
                if (!(Test-Path -Path "$($BootDriveLetter):\")) {
                    throw 'Boot drive letter is missing'
                }
            }
        }
    }
    End {
        if (!(Test-Path -Path "$($OSDriveLetter):\")) {
            throw 'OS drive letter is missing'
            if ($BootDriveLetter) {
                if (!(Test-Path -Path "$($BootDriveLetter):\")) {
                    throw 'Boot drive letter is missing'
                }
            }
        }
    }
}