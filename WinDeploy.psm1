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
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR
                $partition = New-Partition @osParam -InputObject $Disk -UseMaximumSize -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'WinPE' -Partition $partition -Confirm:$false
                $OSDriveLetter = [char](Get-Volume -Partition $partition).DriveLetter
            } elseif ($MBR) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR
                $bootPartition = New-Partition @bootParam –InputObject $Disk -Size 350MB -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Partition $bootPartition -Confirm:$false
                $osPartition = New-Partition @osParam –InputObject $Disk -UseMaximumSize
                Format-Volume -FileSystem NTFS -Partition $osPartition -Confirm:$false
                $BootDriveLetter = [char](Get-Volume -Partition $bootPartition).DriveLetter
                $OSDriveLetter = [char](Get-Volume -Partition $osPartition).DriveLetter
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
    End {}
}

Function Clear-WinPartition {
<#
.SYNOPSIS 
Completely erases a disk.

.DESCRIPTION
Removes all partitions and completely erases the disk.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 1

C:\PS> Clear-WinPartition -Disk $disk

Removes all data on disk.

.LINK
http://blog.acubyte.com

.LINK
New-WinPartition
#>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory,ValueFromPipeline)][ciminstance]$Disk
    )
    Begin {}
    Process {
        try {
            if ($Disk.PartitionStyle -ne 'RAW') {
                Get-Partition -Disk $Disk | Remove-partition -Confirm:$false
                Clear-Disk -InputObject $Disk -RemoveData -RemoveOEM -Confirm:$false
            }
        } catch {
            throw $_
        }
    }
    End {}
}

Function New-WinDiskpartScript {
<#
.SYNOPSIS 
Creates script for Diskpart.

.DESCRIPTION
Creates the commands to script a GTP formated disk in diskpart.

.EXAMPLE
C:\PS> New-WinDiskpartScript -DiskNumber 0 -OSDriveLetter C -BootDriveLetter S | Out-File -Path c:\script.txt

C:\PS> diskpart /s c:\script.txt

Creates a text file for diskpart to use as a script.

.LINK
http://blog.acubyte.com

.LINK
New-WinPartition
#>
    Param (
        [Parameter(Mandatory)][int]$DiskNumber,
        [Parameter(Mandatory)][ValidateRange('A','Z')][char]$OSDriveLetter,
        [Parameter(Mandatory)][ValidateRange('A','Z')][char]$BootDriveLetter,
        [ValidateSet('Server','Client')]$Platform = 'Server'
    )
    if ($Platform = 'Client') {
        $diskpart = @"
Select disk $DiskNumber
Clean
Convert GPT
Create partition primary size=450 id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
Format quick label="Recovery"
Create partition efi size=100
Format quick FS=FAT32 label="System"
Assign letter="$BootDriveLetter"
Create partition msr size=16
Create partition primary
Format quick FS=NTFS
Assign letter="$OSDriveLetter"
"@
    } else {
        $diskpart = @"
Select disk $DiskNumber
Clean
Convert GPT
Create partition primary size=300 id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
Format quick FS=NTFS label="Recovery"
Create partition efi size=100
Format quick FS=FAT32 label="System"
Assign letter="$BootDriveLetter"
Create partition msr size=128
Create partition primary
Format quick FS=NTFS
Assign letter="$OSDriveLetter"
"@
    }
    return $diskpart
}

Function New-WinPEMedia {
<#
.SYNOPSIS 
Generates the files needed for a bootable WinPE media.

.DESCRIPTION
Creates a custom boot.wim and collects all of the necessary files to create a bootable WinPE media.

.EXAMPLE
C:\PS> New-WinPEMedia

Generates all of the files in the temp directory and copies them to the users desktop.

.LINK
http://blog.acubyte.com
#>
    [CmdletBinding()]
    Param (
        [string]$Temp = "$env:TEMP\WinPE",
        [string]$Destination = "$env:HOME\Desktop\WinPE"
    )
    Begin {
    }
    Process {
        $wpeADK = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64'
        if (Test-Path $Temp) {
            Remove-Item -Path $Temp -Recurse -Force
        }
        New-Item -Path $Temp -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$wpeADK\Media" -Destination $Temp -Recurse -Force
        New-Item -Path "$Temp\Media\Sources" -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$wpeADK\en-us\winpe.wim" -Destination "$Temp\Media\Sources\boot.wim"
        New-Item -Path "$Temp\Mount" -ItemType Directory -Force | Out-Null

        Mount-WindowsImage -ImagePath "$Temp\Media\Sources\boot.wim" -Index 1 -Path "$Temp\Mount" | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-WMI.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-WMI_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-NetFx.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-NetFx_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-Scripting.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-PowerShell.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-DismCmdlets.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-EnhancedStorage.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-EnhancedStorage_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\WinPE-StorageWMI.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$wpeADK\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck | Out-Null

        $wpeInitStartup = 'powershell.exe -executionpolicy unrestricted -noexit'
        Add-Content -Path "$Temp\Mount\Windows\System32\Startnet.cmd" -Value $wpeInitStartup
        
        Dismount-WindowsImage -path "$Temp\Mount" -Save | Out-Null
        
        if (Test-Path $Destination) {
            Remove-Item -Path $Destination -Recurse -Force
        }
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$Temp\Media" -Destination "$Destination" -Recurse -Force
        Remove-Item -Path $Temp -Recurse -Force
        
        return $Destination
    }
    End {
    }
}

Function Set-WinBoot {
<#
.SYNOPSIS 
Sets the boot code.

.DESCRIPTION
Configures the boot directory to make the drive bootable.

.EXAMPLE
C:\PS> Set-WinBoot -OSDriveLetter C -BootDriveLetter S

Sets the boot partition to boot from the S drive to load c:\windows.

.EXAMPLE
C:\PS> Set-WinBoot -OSDriveLetter N -USB

Sets the USB device to become bootable.

.LINK
http://blog.acubyte.com

.LINK
New-WinPartition
#>
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName = 'OS')]
    Param (
        [Parameter(Mandatory)][ValidateRange('A','Z')][char]$OSDriveLetter,
        [Parameter(Mandatory,ParameterSetName='OS')]
            [ValidateRange('A','Z')][char]$BootDriveLetter,
        [Parameter(ParameterSetName='OS')][switch]$MBR,
        [Parameter(ParameterSetName='USB')][switch]$USB
    )
    if ($USB) {
        $result = bootsect.exe /nt60 "$($OSDriveLetter):"
    } else {
        if (!(Test-Path "$($OSDriveLetter):\Windows")) {
            throw "No Windows installation found at $($OSDriveLetter):\Windows"
        } elseif ($MBR) {
            $result = bcdboot.exe "$($OSDriveLetter):\Windows" /s "$($BootDriveLetter):" /f BIOS
        } else {
            $result = bcdboot.exe "$($OSDriveLetter):\Windows" /s "$($BootDriveLetter):" /f UEFI
        }
    }
    return $result
}

Function Install-WinPEUSB {
<#
.SYNOPSIS 
Creates a bootable WinPE USB.

.DESCRIPTION
Creates a bootable WinPE USB drive and adds any specified images to the device for an easy way to deploy WIM files to physical devices.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 1

C:\PS> Install-WinPEUSB -USB $USBDrive

Creates a bootable WinPE USB drive.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 1

C:\PS> Install-WinPEUSB -USB $USBDrive -Images C:\Images

Creates a bootable WinPE USB drive and adds all of the WIM files in the C:\Images directory to the USB device.

.LINK
http://blog.acubyte.com

.LINK
New-WinPEUSB

.LINK
New-WinPartition

.LINK
Set-WinBoot
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipeline)][ciminstance]$USB,
        [string[]]$Images
    )
    Begin {}
    Process {
        try {
            New-WinPartition -Disk $USB -USB | Out-Null
            $winPEMedia = New-WinPEMedia
            $usbVolume = Get-Volume -FileSystemLabel 'WinPE'
            Copy-Item -Path "$winPEMedia\Media\*" -Destination "$($usbVolume.DriveLetter):\" -Recurse
            if ($Images) {
                $imageDirectory = "$($usbVolume.DriveLetter):\Images"
                if (!(Test-Path -Path $imageDirectory)) {
                    New-Item -Path $imageDirectory -ItemType Directory | Out-Null
                }
                foreach ($image in $Images) {
                    if (!(Test-Path -Path $image)) {
                        Write-Warning "$image is not a valid directory"
                    } else {
                        $imageFiles = Get-ChildItem -Path $image -Include '*.wim' -Recurse
                        foreach ($imageFile in $imageFiles) {
                            Copy-Item -Path $imageFile.FullName -Destination $imageDirectory -Force
                        }
                    }
                }
            }
            $moduleDirectory = "$($usbVolume.DriveLetter):\Modules"
            if (!(Test-Path -Path $moduleDirectory)) {
                New-Item -Path $moduleDirectory -ItemType Directory | Out-Null
            }
            $winDeployModule = Split-Path -Path (Get-Module -ListAvailable WinDeploy).Path
            Copy-Item -Path $winDeployModule -Destination $moduleDirectory -Recurse -Force
            $bootResults = Set-WinBoot -OSDriveLetter $usbVolume.DriveLetter -USB
        } catch {
            throw $_
        }
    }
    End {}
}

Function Install-WinImage {
<#
.SYNOPSIS 
Deploys a WIM file.

.DESCRIPTION
Creates a bootable disk from a WIM file.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 0

C:\PS> Install-WinImage -Disk $disk -OSDriveLetter C -BootDriveLetter S -WIM D:\Images\WS2012R2.WIM -WIMIndex 3

Installs the 'Windows Server 2012 R2 Datacenter Core' Image to Disk 0 which is formated for UEFI and boots into C:\Windows.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 0

C:\PS> Install-WinImage -Disk $disk -OSDriveLetter C -BootDriveLetter S -WIM D:\Images\Win10_Ent_1511.WIM -WIMIndex 1 -MBR

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
        [Parameter(Mandatory)][ValidateRange('A','Z')][char]$OSDriveLetter,
        [Parameter(Mandatory)][ValidateRange('A','Z')][char]$BootDriveLetter,
        [switch]$MBR,
        [Parameter(Mandatory)][string]$WIM,
        [Parameter(Mandatory)][int]$WIMIndex,
        [string]$LogPath = "$env:TEMP\WinImage.log"
    )
    Begin {
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
                Write-Log -Message "Formating Drive Number $($Disk.Number) for Server OS"
                $format = New-WinPartition -Disk $Disk -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter -ErrorAction Stop
                Write-Log -Message $format
            } elseif ($MBR) {
                Write-Log -Message "Formating Drive Number $($Disk.Number) for MBR"
                $format = New-WinPartition -Disk $Disk -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter -MBR -ErrorAction Stop
                Write-Log -Message $format
            } else {
                Write-Log -Message "Formating Drive Number $($Disk.Number) for Client OS"
                $format = New-WinPartition -Disk $Disk -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter -Platform Client -ErrorAction Stop
                Write-Log -Message $format
            }
            Write-Log -Message "Installing $($image.Where({$_.ImageIndex -eq $WIMIndex}).ImageName)"
            $imageInstall = Expand-WindowsImage -ImagePath $WIM -Index $WIMIndex -ApplyPath "$($OSDriveLetter):\"
            Write-Log -Message "DISM Log: $($imageInstall.LogPath)"
            Write-Log -Message "Setting disk to boot from volume $BootDriveLetter to OS volume $OSDriveLetter"
            $imageBoot = Set-WinBoot -OSDriveLetter $OSDriveLetter -BootDriveLetter $BootDriveLetter
            Write-Log -Message $imageBoot
        } catch {
            Write-Log -Message $Error[0].Exception.Message -Type Error
            throw "Installation Failed`nDeployment Log: $LogPath"
        }
    }
    End {
        Write-Log 'Installation Complete'
        Write-Output "Installation Complete`nDeployment Log: $LogPath"
    }
}

Function Write-Log {
    Param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Type = 'Info',
        [Parameter(Mandatory)][string]$Path,
        [switch]$Replace
    )
    Begin {
        $VerbosePreference = 'Continue'
    }
    Process {
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -ItemType File -Force | Out-Null
        } elseif ($Replace) {
            Remove-Item -Path $Path
            New-Item -Path $Path -ItemType File -Force | Out-Null
        }
        "[$(Get-Date)][$Type]$Message" | Out-File -FilePath $Path -Append
    }
    End {}
}