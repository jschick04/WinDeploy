#requires -Version 3 -Modules Storage
Function Clear-WinPartition {
<#
.SYNOPSIS 
   Completely erases a disk.

.DESCRIPTION
   Removes all partitions and completely erases the disk.

.EXAMPLE
   PS C:\> $disk = Get-Disk -Number 1

   PS C:\> Clear-WinPartition -Disk $disk

   Removes all data on disk.

.LINK
   http://blog.acubyte.com

.LINK
   New-WinPartition
#>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory,ValueFromPipeline)][ciminstance]$Disk,
        [switch]$Force
    )
    Begin {}
    Process {
        try {
            if (($Disk.BusType -eq 'USB') -and !($Force)) {
                Write-Error -Message 'You have specified a USB drive, use -Force to override' -ErrorAction Stop
            } elseif ($Disk.PartitionStyle -ne 'RAW') {
                Clear-Disk -InputObject $Disk -RemoveData -RemoveOEM -Confirm:$false
            }
        } catch {
            throw $_
        }
    }
    End {}
}