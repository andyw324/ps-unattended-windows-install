Param(
    [string]$installDirectory = "C:\Program Files\PBIRS",
    [string]$logLocation = '%TEMP%',
    [string]$productKey = "",
    [switch]$Restart

)

Write-Output "Starting Power BI Report Server Deployment"

REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v PBIRSInstallStatus /t REG_SZ /d Started

if ($productKey -ne "") {
    & 'Z:\2017 June - PBI Report Server\PowerBIReportServer.exe' /passive /norestart /log E:\PBIRS.txt /InstallFolder=D:\PBIRS /IAcceptLicenseTerms /PID=$productionKey
} else {
    & 'Z:\2017 June - PBI Report Server\PowerBIReportServer.exe' /passive /norestart /log E:\PBIRS.txt /InstallFolder=D:\PBIRS /IAcceptLicenseTerms /Edition=Dev
}

do {
    Write-Output "." -NoNewline
    Start-Sleep -Seconds 2
}
until ((Get-Process | Where {$_.ProcessName -like "PowerBIReportServer"}).Count -eq 0)
Write-Output "Install complete - exit status: "
Write-Output (Get-Content $logLocation)[-1]
Write-Output "Installation log files located in $logLocation"

REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v PBIRSInstallStatus /t REG_SZ /d Complete

if ($Restart) {
    Write-Output "Power BI Report Server Installed - Restarting server"
    Restart-Computer
}
