



function Add-AutoUnattendDisk
{
    Param(
        [Parameter(Mandatory=$True)][int]$DiskNumber,
        [switch]$IsBootDisk
    )

    if ($IsBootDisk) {
                
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>350</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Extend>true</Extend>
                            <Order>2</Order>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
    } else {
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Extend>true</Extend>
                            <Order>1</Order>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
    }

    return $Pass1_DiskConfig

}


function Set-AutoUnattendDisk
{
    Param(
        [Parameter(Mandatory=$True)][int]$DiskNumber,
        [string]$DriveLetter,
        [switch]$IsBootDisk,
        [switch]$IsSetupDisk
    )
    if ($IsBootDisk -or $IsSetupDisk) {
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Letter>' + $DriveLetter + '</Letter>
                            <PartitionID>2</PartitionID>
                            <Order>1</Order>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>false</WillWipeDisk>
                </Disk>'
    } else {
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Letter>' + $DriveLetter + '</Letter>
                            <PartitionID>1</PartitionID>
                            <Order>1</Order>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
        
    }

    return $Pass1_DiskConfig
}