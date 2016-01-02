Function New-WinPartition {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][object]$Disk,
        [Parameter(ParameterSetName='MBR')][switch]$MBR,
        [Parameter(ParameterSetName='USB')][switch]$USB,
        [Parameter(ParameterSetName='GPT')][switch]$Client,
        [ValidateRange(A,Z)][char]$BootDriveLetter,
        [ValidateRange(A,Z)][char]$OSDriveLetter
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
        Clear-WinPartition -Disk $Disk
        try {
            if ($USB) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR
                $partition = New-Partition @osParam -InputObject $Disk -UseMaximumSize -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'WinPE' -Partition $partition -Confirm:$false
            } elseif ($MBR) {
                Initialize-Disk -InputObject $Disk -PartitionStyle MBR
                $bootPartition = New-Partition @bootParam –InputObject $Disk -Size 350MB -IsActive
                Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Partition $bootPartition -Confirm:$false
                $osPartition = New-Partition @osParam –InputObject $Disk -UseMaximumSize
                Format-Volume -FileSystem NTFS -Partition $osPartition -confirm:$false
            } else {
                if (!$BootDriveLetter -or !$OSDriveLetter) {
                    throw 'Boot and OS drive letters must be specified'
                }
                $diskpartTemp = "$env:TEMP\diskpart.txt"
                if ($Client) {
                    New-WinDiskpartScript -DiskNumber $Disk.Number -BootDriveLetter $BootDriveLetter -OSDriveLetter $OSDriveLetter -Platform Client | Out-File -FilePath $diskpartTemp
                } else {
                    New-WinDiskpartScript -DiskNumber $Disk.Number -BootDriveLetter $BootDriveLetter -OSDriveLetter $OSDriveLetter | Out-File -FilePath $diskpartTemp
                }
                diskpart.exe /s $diskpartTemp
            }
        } catch {
            throw $_
        }
    }
    End {}
}

Function Clear-WinPartition {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][object]$Disk
    )
    Begin {}
    Process {
        try {
            Get-Disk -Number $Disk.number | Get-Partition | Remove-partition -Confirm:$false
            Clear-Disk -Number $Disk.Number -RemoveData -RemoveOEM -Confirm:$false
        } catch {
            throw $_
        }
    }
    End {}
}

Function New-WinDiskpartScript {
    Param (
        [Parameter(Mandatory)][int]$DiskNumber,
        [Parameter(Mandatory)][ValidateRange(A,Z)][char]$BootDriveLetter,
        [Parameter(Mandatory)][ValidateRange(A,Z)][char]$OSDriveLetter,
        [ValidateSet('Server','Client')]$Platform = 'Server'
    )
    if ($Platform = 'Client') {
        $diskpart = @"
Select disk $DiskNumber
Clean
Convert GPT
Create partition primary size=450 id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
Format quick FS=NTFS label="Recovery"
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

        $wpeInitStartup = "powershell.exe -executionpolicy unrestricted -noexit -command 'Clear-Host'"
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
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][ValidateRange(A,Z)][char]$BootDriveLetter,
        [Parameter(Mandatory)][ValidateRange(A,Z)][char]$OSDriveLetter,
        [switch]$USB
    )
    if ($USB) {
        bootsect.exe /nt60 "$($OSDriveLetter):"
    } else {
        bcdboot.exe "$($OSDriveLetter):\Windows" /s "$($BootDriveLetter):" /f All
    }
}

Function Install-WinPEUSB {
    [CmdletBinding()]
    Param ()
}

Export-ModuleMember -Function New-WinPartition,Clear-WinPartition,New-WinPEMedia,Set-WinBoot