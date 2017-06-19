Param(
    [string]$configFilePath="Z:\sql-server-config-file\ConfigurationFile-from-scratch.ini"
)

"Starting SQL Server 2016 Deployment"
"-----------------------------------"
"To continue press Enter"
Pause
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Started

Z:\SQL_Server_2016_SP1_x64\Setup.exe /ConfigurationFile=configFilePath
""
"SQL Server Deployment complete - Press Enter to continue"
Pause
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Complete