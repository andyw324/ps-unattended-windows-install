Import-Module .\Param-Test.psm1 -Force

$unattendPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V"
$autoISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\auto.iso"
$windowsISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.iso"

"Input values:"
"Unattended Path: " + $unattendPath
"AutoISO Path: " + $autoISOPath
"Windows ISO Path: " + $windowsISOPath
""

Test-Deploy-WindowsServer -unattendPath $unattendPath `
                     -autoISOPath $autoISOPath `
                     -windowsISOpath $windowsISOPath `
                     -name "Hyper-V Server 2012" `
                     -switch "vSwitch" `
                     -numCores 1 `
                     -ramSize (2GB) `
                     -vhdPathArray @(($unattendPath + "\boot.vhdx"),($unattendPath + "\install.vhdx"),($unattendPath + "\data.vhdx")) `
                     -vhdSizeArray @(10GB,10GB,10GB) `
                     -vhdBlockSizeArray @(4KB,4KB,64KB) `
                     -vhdSectorSizeArray @(512,512,512) `
                     -numDrives 3 `
                     -killVM `
                     -confirmVMSettings

