Import-Module .\DeployWindowsServer-functions.psm1 -Force

$vhdPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V"
$unattendPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V"
$autoISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\auto.iso"
#$windowsISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\Win2012ServerSTD_unattend.iso"
$windowsISOPath = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.iso"

New-HyperVWindowsServer -unattendPath $unattendPath `
                        -autoISOPath $autoISOPath `
                        -windowsISOpath $windowsISOPath `
                        -vhdPathArray @(($vhdPath + "\boot.vhdx"),($vhdPath + "\install.vhdx"),($vhdPath + "\data.vhdx")) `
                        -name "Hyper-V Server 2012" `
                        -ramSize (2GB) `
                        -vhdSizeArray @(50GB,10GB,10GB) `
                        -vhdBlockSizeArray @(32MB) `
                        -vhdSectorSizeArray @(512,512,512) `
                        -numDrives 1 `
                        -killVM `
                        -confirmVMSettings `
                        -showProgress `
                        -includeSetupVHD `
                        -setupVHDXPath "C:\Users\ABCD Family Admin\Documents\Hyper-V\SetupFile.vhdx"



                     

