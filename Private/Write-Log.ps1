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
            $Null = New-Item -Path $Path -ItemType File -Force
        } elseif ($Replace) {
            Remove-Item -Path $Path -ErrorAction SilentlyContinue
            $Null = New-Item -Path $Path -ItemType File -Force
        }
        "[$(Get-Date)][$Type]$Message" | Out-File -FilePath $Path -Append
    }
    End {}
}