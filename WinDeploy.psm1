Function New-WinPartition {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][object]$Disk,
        [switch]$MBR,
        [switch]$USB,
        [switch]$OS,
        [ValidateRange('A..Z')][char]$BootDriveLetter,
        [ValidateRange('A..Z')][char]$OSDriveLetter
    )

    Clear-WinPartition -Disk $Disk
    try {
        if ($MBR) {
            Initialize-Disk -Number $Disk.Number -PartitionStyle MBR -ErrorAction Stop
                if ($USB) {
                    $partition = New-Partition -DiskNumber $Disk.Number -DriveLetter $OSDriveLetter -UseMaximumSize -IsActive
                    Format-Volume -Partition $partition  -FileSystem FAT32 -NewFileSystemLabel 'WinPE'
                } else {
                    $bootPartition = New-Partition –InputObject $Disk -Size 350MB -IsActive
                    Format-Volume -NewFileSystemLabel 'Boot' -FileSystem FAT32 -Partition $bootPartition -Confirm:$False
                    Set-Partition -InputObject $bootPartition -NewDriveLetter $BootDriveLetter

                    $osPartition = New-Partition –InputObject $Disk -UseMaximumSize
                    Format-Volume -NewFileSystemLabel 'Windows' -FileSystem NTFS -Partition $osPartition -confirm:$False
                    Set-Partition -InputObject $osPartition -NewDriveLetter $OSDriveLetter
                }
        } else {
            Initialize-Disk -Number $Disk.Number -PartitionStyle GPT -ErrorAction Stop
            if ($OS) {
                $recoveryPartition = New-Partition -DiskNumber $Disk.Number -Size 450MB
                Format-Volume -Partition $recoveryPartition -FileSystem NTFS -NewFileSystemLabel 'Recovery' -Confirm:$False
                Set-Partition -InputObject $recoveryPartition -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'

                $systemPartition = New-Partition -DiskNumber $Disk.Number -Size 100MB -DriveLetter $BootDriveLetter
                Format-Volume -Partition $systemPartition -FileSystem FAT32 -Confirm:$False
                Set-Partition -InputObject $systemPartition -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'

                $reservedPartition = New-Partition -DiskNumber $Disk.Number -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'

                $osPartition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter $OSDriveLetter
                Format-Volume -Partition $osPartition -FileSystem NTFS
            }

            <#$Partition=New-Partition -DiskNumber $Disk.Number -Size 128MB ; # Create Microsoft Basic Partition
            Format-Volume -Partition $Partition -FileSystem Fat32 -NewFileSystemLabel 'MSR'
            Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

            $Partition=New-Partition -DiskNumber $Disk.Number -Size 300MB -DriveLetter $bootLetter ; # Create Microsoft Basic Partition and Set System as bootable
            Format-Volume -Partition $Partition  -FileSystem Fat32 -NewFileSystemLabel 'Boot'
            Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber

            $Partition=New-Partition -DiskNumber $Disk.Number -DriveLetter $osDrive -UseMaximumSize ; # Take remaining Disk space for Operating System
            Format-Volume -Partition $Partition  -FileSystem NTFS -NewFileSystemLabel 'Windows'#>
        }
    } catch {
        throw $_
    }
}

Function Clear-WinPartition {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][object]$Disk
    )
    try {
        Get-Disk -Number $Disk.number | Get-Partition | Remove-partition -Confirm:$false -ErrorAction Stop
        Clear-Disk -Number $Disk.Number -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    } catch {
        throw $_
    }
}

Function Install-WinImage {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]$Image
    )
}