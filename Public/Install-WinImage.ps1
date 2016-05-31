#requires -Version 3
Function Install-WinImage {
<#
.SYNOPSIS 
   Deploys a WIM file.

.DESCRIPTION
   Creates a bootable disk from a WIM file.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 0

   PS C:\ Install-WinImage -Disk $disk -OSDriveLetter C -BootDriveLetter S -WIM D:\Images\WS2012R2.WIM -WIMIndex 3

   Installs the 'Windows Server 2012 R2 Datacenter Core' Image to Disk 0 which is formated for UEFI and boots into C:\Windows.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 0

   PS C:\> Install-WinImage -Disk $disk -OSDriveLetter C -BootDriveLetter S -WIM D:\Images\Win10_Ent_1511.WIM -WIMIndex 1 -MBR

   Installs the 'Windows 10 Enterprise' Image to Disk 0 which is formated for MBR and boots into C:\Windows.

.LINK
   http://blog.acubyte.com

.LINK
   Install-WinPEUSB

.LINK
   New-WinPEUSB

.LINK
   New-WinPartition

.LINK
   Set-WinBoot
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipeline)][ciminstance]$Disk,
        [ValidateRange('A','Z')][char]$OSDriveLetter = 'C',
        [ValidateRange('A','Z')][char]$BootDriveLetter = 'S',
        [switch]$MBR,
        [Parameter(Mandatory)][string]$WIM,
        [Parameter(Mandatory)][int]$WIMIndex,
        [string]$DriverPath,
        [string]$LogPath = "$env:TEMP\WinImage.log"
    )
    Begin {
        Write-Verbose 'Validating Resources'
        $PSDefaultParameterValues = @{'Write-Log:Path'=$LogPath}
        Write-Log -Message "Image Path: $WIM"
        Write-Log -Message "Index Number: $WIMIndex"
        Write-Log -Message 'Validating Image'
        $image = Get-WindowsImage -ImagePath $WIM
        if ($image.ImageIndex -notcontains $WIMIndex) {
            Write-Log -Message 'Invalid Image Index' -Type Error
            throw "$WIMIndex is not a valid Image Index"
        } else {
            Write-Log -Message "Using $($image.Where({$_.ImageIndex -eq $WIMIndex}).ImageName)"
        }
    }
    Process {
        try {
            if ($image.ImageName -like '*Server*') {
                Write-Verbose "Formating Disk $($Disk.Number) for Server OS"
                Write-Log -Message "Formating Drive Number $($Disk.Number) for Server OS"
                $format = New-WinPartition -Disk $Disk -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter -ErrorAction Stop
                Write-Log -Message $format
            } elseif ($MBR) {
                "Formating Disk $($Disk.Number) for MBR"
                Write-Log -Message "Formating Drive Number $($Disk.Number) for MBR"
                $format = New-WinPartition -Disk $Disk -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter -MBR -ErrorAction Stop
                Write-Log -Message $format
            } else {
                "Formating Disk $($Disk.Number) for Client OS"
                Write-Log -Message "Formating Drive Number $($Disk.Number) for Client OS"
                $format = New-WinPartition -Disk $Disk -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter -Platform Client -ErrorAction Stop
                Write-Log -Message $format
            }
            Write-Verbose "Installing $($image.Where({$_.ImageIndex -eq $WIMIndex}).ImageName)"
            Write-Log -Message "Installing $($image.Where({$_.ImageIndex -eq $WIMIndex}).ImageName)"
            $imageInstall = Expand-WindowsImage -ImagePath $WIM -Index $WIMIndex -ApplyPath "$($OSDriveLetter):\"
            Write-Log -Message "DISM Log: $($imageInstall.LogPath)"
            Write-Verbose 'Configuring Bootloader'
            Write-Log -Message "Setting disk to boot from volume $BootDriveLetter to OS volume $OSDriveLetter"
            $imageBoot = Set-WinBoot -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter
            Write-Log -Message $imageBoot
            if ($DriverPath) {
                Write-Verbose 'Installing Drivers'
                Write-Log -Message "Installing Drivers from $DriverPath"
                $drivers = Add-WindowsDriver -Driver $DriverPath -Path "$($OSDriveLetter):\" -SystemDrive "$($BootDriveLetter):\" -LogLevel Errors -Recurse
                foreach ($driver in $drivers) {
                    Write-Log -Message "[$($driver.Driver)][$($driver.CatalogFile)][$($driver.ProviderName)]$($driver.ClassDescription) - $($driver.Version)"
                }
                Write-Verbose "Driver Log: $($drivers[0].LogPath)"
            }
        } catch {
            Write-Log -Message "$($_.Exception.Message)" -Type Error
            throw "Installation Failed`nDeployment Log: $LogPath"
        }
    }
    End {
        Write-Log 'Installation Complete'
        Write-Output "Installation Complete`nDeployment Log: $LogPath"
    }
}