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