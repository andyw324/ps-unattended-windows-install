echo "Begining install of SQL Server 2016"
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d StartInstall
z:\SQL-Server-Setup-Files\setup.exe /ConfigurationFile="Z:\ConfigurationFile.ini"
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v SQLInstallStatus /t REG_SZ /d Complete