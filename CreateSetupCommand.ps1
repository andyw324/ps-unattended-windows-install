"Attempting to create SetupConfig.cmd file"
mkdir C:\Windows\Setup\Scripts
Set-Content C:\Windows\Setup\Scripts\SetupComplete.cmd 'REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v OSInstallStatus /t REG_SZ /d Complete' -Encoding Ascii
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v OSInstallStatus /t REG_SZ /d ZDriveScriptRun