Function Deploy-WindowsServer
{

    Param(
        [string]$path = [Environment]::GetFolderPath('UserProfile') + "\Downloads",
        [string]$autoISO = "auto.iso",
        [string]$windowsISOpath = $path + "\en_microsoft_hyper-v_server_2012_x64_dvd_915600.iso",
        [array]$vhdPathArray = @($path + "\hyper-v.vhd"),
        [string]$name = "Hyper-V Server 2012",
        [string]$switch = "vSwitch",
        [long]$ramSize = 2GB,
        [array]$vhdSizeArray = @(10GB),
        [array]$vhdBlockSizeArray = @(4KB),
        [array]$vhdSectorSizeArray = @(512),
        [int]$numDrives = 1
    )


    for ($i=0;$i -lt $numDrives; $i++) {
        echo "vhd path: " + $vhdPathArray[$i]
        echo "Size Array: " + $vhdSizeArray[$i]
        echo "Block Array: " + $vhdBlockSizeArray[$i]
        echo "Sector Array: " + $vhdSectorSizeArray[$i]
    }


}