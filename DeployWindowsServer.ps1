


Param(
    [string]$path = [Environment]::GetFolderPath('UserProfile') + "\Downloads",
    [string]$autoISO = "auto.iso",
    [string]$windowsISOpath = $path + "\en_microsoft_hyper-v_server_2012_x64_dvd_915600.iso",
    [array]$vhdPathArray = @($path + "\hyper-v.vhd"),
    [string]$name = "Hyper-V Server 2012",
    [string]$switch = "vSwitch",
    [long]$ramSize = 2GB,
    [array]$vhdSzeArray = @(10GB),
    [array]$vhdBlockSizeArray = @(4KB),
    [array]$vhdSectorSizeArray = @(512),
    [int]$numDrives = 1
)


Import-Module .\DeployWindowsServer-functions.psm1

# Begin script by Albal to create New-VM based on autounattend.xml -
# Assumes all required files are in, and will be written to <USER>\Downloads
# Change the below parameters if needed

#Param(
#    [string]$path = [Environment]::GetFolderPath('UserProfile') + "\Downloads",
#    [string]$windowsISOpath = $path + "\en_microsoft_hyper-v_server_2012_x64_dvd_915600.iso",
#    [string]$vhdPath = $path + "\hyper-v.vhd",
#    [string]$name = "Hyper-V Server 2012",
#    [string]$switch = "vSwitch"
#)

# Don't change anything below this line - ignore the errors below, just in case you run the script again without having exited expectedly

if (Test-FAVMExistence -VMName $name) {
    Stop-VM -Name $name -Force -TurnOff
    Remove-VM  -Name $name -Force
}

if (Test-Path $path\$autoISO) { del -Force $path\$autoISO }
if (Test-Path $vhdPath) { del -Force $vhdPath }

dir $path\autounattend.xml | New-IsoFile -Path $path\auto.iso -Media CDR -Title "Unattend"

if (!(Test-FAVMSwitchexistence)) { New-VMSwitch -Name $switch -SwitchType Private -Notes "Internal to VMs only" }

New-Vm -Name $name -SwitchName $switch
Set-VMProcessor -VMName $name -Count 1
Set-VMMemory -VMName $name -StartupBytes 2147483648

for ($i=0;$i -lt $numDrives; $i++) {
    "Drive ID = " + ($i+1) + " of size " + $array[$i] + " added"
    New-VHD -Path $vhdPathArray[$i] -BlockSizeBytes $vhdBlockSizeArray[$i] -LogicalSectorSizeBytes $vhdSectorSizeArray[$i] -SizeBytes $vhdSzeArray[$i]
    Add-VMHardDiskDrive -VMName $name -Path $vhdPathArray[$i] -ControllerType IDE -ControllerNumber 0 -ControllerLocation $i
}
New-VHD -Path $vhdPath -SizeBytes 21474836480 

#Add-VMHardDiskDrive -VMName $name -Path $vhdPath -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0
Set-VMDvdDrive -VMName $name -Path $windowsISOPath -ControllerNumber 1 -ControllerLocation 0
Add-VMDvdDrive -VMName $name -Path $path\auto.iso -ControllerNumber 1 -ControllerLocation 1

Start-VM -Name $name

echo "When you press enter the Virtual Machine will be stopped and deleted"
pause

Stop-VM -Name $name -Force -TurnOff
Remove-VM  -Name $name -Force
del $path\hyper-v.vhd
del $path\auto.iso