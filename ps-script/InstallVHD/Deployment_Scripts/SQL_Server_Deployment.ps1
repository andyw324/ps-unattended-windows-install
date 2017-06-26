Param(
    [string]$configFilePath="Z:\sql-server-config-file\ConfigurationFile-from-scratch.ini"
)

Write-Host "Starting SQL Server 2016 Deployment"

REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Started

Z:\SQL_Server_2016_SP1_x64\Setup.exe /ConfigurationFile="$configFilePath"

REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Complete

Write-Host "SQL Server Deployment complete"
Restart-Computer