& 'Z:\2017 June - PBI Report Server\PowerBIReportServer.exe' /passive /norestart /log E:\PBIRS.txt /InstallFolder=D:\PBIRS /IAcceptLicenseTerms /Edition=Dev

do {
    write-host "." -NoNewline
    Start-Sleep -Seconds 2
}
until ((Get-Process | Where {$_.ProcessName -like "PowerBIReportServer"}).Count -eq 0)