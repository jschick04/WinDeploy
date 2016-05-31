#requires -Version 3
Function New-WinDiskpartScript {
<#
.SYNOPSIS 
   Creates script for Diskpart.

.DESCRIPTION
   Creates the commands to script a GTP formated disk in diskpart.

.EXAMPLE
   PS C:\> New-WinDiskpartScript -DiskNumber 0 -OSDriveLetter C -BootDriveLetter S | Out-File -Path c:\script.txt

   PS C:\> diskpart /s c:\script.txt

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
    Write-Output $diskpart
}