#requires -Version 3 -Modules Storage
Function Test-Volume {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][ValidateRange('A','Z')][char]$DriveLetter
    )
    Process {
        $volume = Get-Volume
        if ($volume.DriveLetter -contains $DriveLetter) {
            $volumeUsed = $true
        } else {
            $volumeUsed = $false
        }
        return $volumeUsed
    }
}