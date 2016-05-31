Function Install-WinPEUSB {
<#
.SYNOPSIS 
   Creates a bootable WinPE USB.

.DESCRIPTION
   Creates a bootable WinPE USB drive and adds any specified images to the device for an easy way to deploy WIM files to physical devices.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 1

   PS C:\> Install-WinPEUSB -USB $USBDrive

   Creates a bootable WinPE USB drive.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 1

   PS C:\> Install-WinPEUSB -USB $USBDrive -ImagePath C:\Images

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
        [string[]]$ImagePath,
        [string[]]$DriverPath
    )
    Begin {}
    Process {
        try {
            Write-Verbose 'Formating USB'
            $null = New-WinPartition -Disk $USB -USB
            Write-Verbose 'Generating WinPE Media'
            $winPEMedia = New-WinPEMedia
            $usbVolume = Get-Volume -FileSystemLabel 'WinPE'
            Copy-Item -Path "$winPEMedia\Media\*" -Destination "$($usbVolume.DriveLetter):\" -Recurse
            if ($ImagePath) {
                $imageDirectory = "$($usbVolume.DriveLetter):\Images"
                if (!(Test-Path -Path $imageDirectory)) {
                    $null = New-Item -Path $imageDirectory -ItemType Directory
                }
                $images = Get-ChildItem -Path $ImagePath -Include *.wim -Recurse
                foreach ($image in $images) {
                    Copy-Item -Path $image.FullName -Destination $imageDirectory -Force
                }
            }
            if ($DriverPath) {
                $driverDirectory = "$($usbVolume.DriveLetter):\Drivers"
                if (!(Test-Path -Path $driverDirectory)) {
                    $null = New-Item -Path $driverDirectory -ItemType Directory
                }
                $drivers = Get-ChildItem -Path $DriverPath
                foreach ($driver in $drivers) {
                    Copy-Item -Path $driver.FullName -Destination $driverDirectory -Recurse -Force
                }
            }
            $moduleDirectory = "$($usbVolume.DriveLetter):\Modules"
            if (!(Test-Path -Path $moduleDirectory)) {
                $null = New-Item -Path $moduleDirectory -ItemType Directory
            }
            $winDeployModule = Split-Path -Path (Get-Module -ListAvailable WinDeploy).Path
            Copy-Item -Path $winDeployModule -Destination $moduleDirectory -Recurse -Force
            $bootResult = Set-WinBoot -OSDriveLetter $usbVolume.DriveLetter -USB
            Write-Verbose $bootResult
        } catch {
            throw $_
        }
    }
    End {}
}
