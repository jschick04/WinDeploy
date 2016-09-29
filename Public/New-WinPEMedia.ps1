#requires -Version 2 -Modules Dism
Function New-WinPEMedia {
<#
.SYNOPSIS 
   Generates the files needed for a bootable WinPE media.

.DESCRIPTION
   Creates a custom boot.wim and collects all of the necessary files to create a bootable WinPE media.

.EXAMPLE
   PS C:\> New-WinPEMedia

   Generates all of the files in the temp directory and copies them to the users desktop.

.LINK
   http://blog.acubyte.com
#>
    [CmdletBinding()]
    Param (
        [string]$Temp = "$env:TEMP\WinPE",
        [string]$Destination = "$env:HOME\Desktop\WinPE",
        [string]$AdkPath = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64'
    )
    Begin {
    }
    Process {
        if (!(Test-Path -Path $AdkPath)) {
            throw 'Windows ADK is not installed'
        }
        if (Test-Path $Temp) {
            Remove-Item -Path $Temp -Recurse -Force
        }
        $null = New-Item -Path $Temp -ItemType Directory -Force
        Copy-Item -Path "$AdkPath\Media" -Destination $Temp -Recurse -Force
        $null = New-Item -Path "$Temp\Media\Sources" -ItemType Directory -Force
        Copy-Item -Path "$AdkPath\en-us\winpe.wim" -Destination "$Temp\Media\Sources\boot.wim"
        $null = New-Item -Path "$Temp\Mount" -ItemType Directory -Force

        $null = Mount-WindowsImage -ImagePath "$Temp\Media\Sources\boot.wim" -Index 1 -Path "$Temp\Mount"
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-WMI.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-WMI_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-NetFx.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-NetFx_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-Scripting.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-PowerShell.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-DismCmdlets.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-EnhancedStorage.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-EnhancedStorage_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\WinPE-StorageWMI.cab" -Path "$Temp\Mount" -IgnoreCheck
        $null = Add-WindowsPackage -PackagePath "$AdkPath\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab" -Path "$Temp\Mount" -IgnoreCheck

        $wpeInitStartup = 'powershell.exe -executionpolicy unrestricted -noexit'
        Add-Content -Path "$Temp\Mount\Windows\System32\Startnet.cmd" -Value $wpeInitStartup
        
        $null = Dismount-WindowsImage -path "$Temp\Mount" -Save

        if (! $Destination) {
          $null = New-Item -Path $Destination -ItemType Directory -Force
        }
        Copy-Item -Path "$Temp\Media" -Destination $Destination -Recurse -Force
        Remove-Item -Path $Temp -Recurse -Force
        
        Write-Output $Destination
    }
    End {
    }
}