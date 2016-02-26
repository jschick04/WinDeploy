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