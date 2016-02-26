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
        if (!(Test-Path $wpeADK)) {
            throw 'Windows ADK is not installed'
        }
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