﻿Import-Module ..\ps-module\DeployWindowsServer-functions.psm1 -Force

$vhdPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\Win-Test"
$unattendPath = "C:\Users\ABCD Family Admin\Documents\PS Scripts\ps-unattended-windows-install\answer-file"
$autoISOPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\auto.iso"
$windowsISOPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\Win2012ServerSTD_unattend.iso"
#$windowsISOPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.iso"
$unattendTemplatePath = "C:\Users\ABCD Family Admin\Documents\PS Scripts\ps-unattended-windows-install\answer-file\AutoUnattend_Template.xml"
$SQLConfigTemplatePath = "C:\Users\ABCD Family Admin\Documents\PS Scripts\ps-unattended-windows-install\sql-server-config-file\Template-SQLServerConfigurationFile.ini"
$setupVHDXPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\SetupFile.vhdx"

New-HyperVWindowsServer -unattendPath $unattendPath `
                        -autoISOPath $autoISOPath `
                        -windowsISOpath $windowsISOPath `
                        -vhdPathArray @(($vhdPath + "\boot.vhdx"),($vhdPath + "\install.vhdx"),($vhdPath + "\data.vhdx"),($vhdPath + "\logs.vhdx"),($vhdPath + "\temp.vhdx"),($vhdPath + "\backup.vhdx")) `
                        -vhdLabelArray @('OS','InstallData','Data','Logs','Temp','Backup') `
                        -unattendTemplatePath $unattendTemplatePath `
                        -VMName "WIN2012PWD" `
                        -ramSize (2GB) `
                        -vhdSizeArray @(50GB,10GB,5GB,5GB,5GB,5GB) `
                        -vhdBlockSizeArray @(32MB) `
                        -vhdSectorSizeArray @(512,512,512,512,512,512) `
                        -vhdAllocationUnitSize @(4KB,64KB,64KB,64KB,64KB,64KB) `
                        -vhdDriveLetter @('C','S','D') `
                        -numDrives 1 `
                        -showProgress `
                        -includeSetupVHD `
                        -setupVHDXPath $setupVHDXPath `
                        -WinAdminPWD "TestPWD123!" `
                        -WinAutoLoginPWD "TestPWD123!" `
                        -AdminUserName "TestAdminUN"
                        



                     

