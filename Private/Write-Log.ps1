function Write-Log {
  param (
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet('Info','Warning','Error')][string]$Type = 'Info',
    [Parameter(Mandatory)][string]$Path,
    [switch]$Replace
  )
  if (!(Test-Path $Path)) {
    $null = New-Item -Path $Path -ItemType File -Force
  } elseif ($Replace) {
    Remove-Item -Path $Path -ErrorAction SilentlyContinue
    $null = New-Item -Path $Path -ItemType File -Force
  }
  Write-Verbose -Message "[$(Get-Date)][$Type]$Message"
  "[$(Get-Date)][$Type]$Message" | Out-File -FilePath $Path -Append -Verbose:$false
}