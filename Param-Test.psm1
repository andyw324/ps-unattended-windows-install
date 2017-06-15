Function Test-Deploy-WindowsServer
{

    Param(
        [Parameter(Mandatory=$true)][string]$unattendPath,
        [Parameter(Mandatory=$true)][string]$autoISOPath,
        [Parameter(Mandatory=$true)][string]$windowsISOpath,
        [string]$name = "Hyper-V Server 2012",
        [string]$switch = "vSwitch",
        [int]$numCores = 1,
        [long]$ramSize = 2GB,
        [array]$vhdPathArray = @('$path + "\hyper-v.vhd"'),
        [array]$vhdSizeArray = @(10GB),
        [array]$vhdBlockSizeArray = @(32MB),
        [array]$vhdSectorSizeArray = @(512),
        [int]$numDrives = 1,
        [switch]$killVM,
        [switch]$confirmVMSettings
    )


    if ($confirmVMSettings) {        
        "VM Settings:"
        "VM Name: " + $name
        "Cores: " + $numCores
        "RAM: " + $ramSize
        "Switch Name: " + $switch
        "Kill VM: " + $killVM
        "Confirm VM: " + $confirmVMSettings
        ""
        $continue = Read-Host -Prompt "Do you wish to continue with the server deployment using these settings?[Y/N]: "

        if ($continue -eq "N") {
            "User aborted process - exiting"
            Return
        }

    }

    "Virtual Drive Creation Details:"
    "_______________________________"
    for ($i=0;$i -lt $numDrives; $i++) {
        "vhd path: " + $vhdPathArray[$i]
        "Size Array: " + $vhdSizeArray[$i]
        "Block Array: " + $vhdBlockSizeArray[$i]
        "Sector Array: " + $vhdSectorSizeArray[$i]
        "--------------------------------------------------"
        ""
    }




}