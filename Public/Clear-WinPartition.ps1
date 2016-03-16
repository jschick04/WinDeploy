Function Clear-WinPartition {
<#
.SYNOPSIS 
Completely erases a disk.

.DESCRIPTION
Removes all partitions and completely erases the disk.

.EXAMPLE
C:\PS> $disk = Get-Disk -Number 1

C:\PS> Clear-WinPartition -Disk $disk

Removes all data on disk.

.LINK
http://blog.acubyte.com

.LINK
New-WinPartition
#>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory,ValueFromPipeline)][ciminstance]$Disk
    )
    Begin {}
    Process {
        try {
            if ($Disk.PartitionStyle -ne 'RAW') {
                Clear-Disk -InputObject $Disk -RemoveData -RemoveOEM -Confirm:$false
            }
        } catch {
            throw $_
        }
    }
    End {}
}