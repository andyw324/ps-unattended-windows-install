Import-Module .\DeployWindowsServer-functions.psm1

$path = [Environment]::GetFolderPath('UserProfile') + "\Documents\Hyper-V"

Deploy-WindowsServer -path $path `
                     -autoISO "auto.iso" `
                     -windowsISOpath $path + "\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.iso" `
                     -vhdPathArray "@('$path\boot.vhd','$path\install.vhd','$path\data.vhd')" `
                     -name "Hyper-V Server 2012" `
                     -switch "vSwitch" `
                     -ramSize (2GB) `
                     -vhdSzeArray "@(10GB,10GB,10GB)" `
                     -vhdBlockSizeArray "@(4KB,4KB,64KB)" `
                     -vhdSectorSizeArray "@(512,512,512)" `
                     -numDrives 3