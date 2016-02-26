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
