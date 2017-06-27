Param(
    [string]$configFilePath="Z:\sql-server-config-file\ConfigurationFile-from-scratch.ini",
    [switch]$Restart
)


Write-Output "Starting SQL Server 2016 Deployment"

REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Started

Z:\SQL_Server_2016_SP1_x64\Setup.exe /ConfigurationFile="$configFilePath"

do {
    Write-Output "." -NoNewline
    Start-Sleep -Seconds 2
}
until ((Get-Process | Where {$_.ProcessName -like "Setup"}).Count -eq 0)
Write-Output "Install complete:"
if (Test-Path "C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log\Summary.txt") {
    Write-Output (Get-Content "C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log\Summary.txt")[1]
    Write-Output "SQL Server Deployment Complete"
} else {
    Write-Output "Error log not found - check %temp% folder for logs"
    Write-Output "SQL Server Deployment Complete with errors"
}
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Complete

if ($Restart) {
    Write-Output "Restarting server"
    Restart-Computer
} else {
    Write-Output "Restart skipped - please restart computer"
}
