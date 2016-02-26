$private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1")
$public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1")

foreach ($function in @($private + $public)) {
    try {
        . $function.FullName
    } catch {
        Write-Error -Message "Could not load function $($function.FullName): $_"
    }
}