Import-Module .\DeployWindowsServer-functions.psm1 -Force

$unattendPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V"
$autoISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\auto.iso"
$windowsISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.iso"

"Input values:"
"Unattended Path: " + $unattendPath
"AutoISO Path: " + $autoISOPath
"Windows ISO Path: " + $windowsISOPath
""

Deploy-WindowsServer -unattendPath $unattendPath `
                     -autoISOPath $autoISOPath `
                     -windowsISOpath $windowsISOPath `
                     -vhdPathArray @(($unattendPath + "\boot.vhdx"),($unattendPath + "\install.vhdx"),($unattendPath + "\data.vhdx")) `
                     -name "Hyper-V Server 2012" `
                     -switch "vSwitch" `
                     -ramSize (2GB) `
                     -vhdSizeArray @(50GB,10GB,10GB) `
                     -vhdBlockSizeArray @(32MB) `
                     -vhdSectorSizeArray @(512,512,512) `
                     -numDrives 3 `
                     -killVM `
                     -confirmVMSettings



                     

