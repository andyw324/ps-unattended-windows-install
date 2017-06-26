
REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Started

& 'Z:\DotNet\NDP452-KB2901907-x86-x64-AllOS-ENU.exe' /quiet /norestart

do {
    write-host "." -NoNewline
    Start-Sleep -Seconds 2
}
until ((Get-Process | Where {$_.ProcessName -like "NDP452-KB2901907-x86-x64-AllOS-ENU"}).Count -eq 0)


REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Complete