Param(
    [switch]$ForceInstall,
    [switch]$DoRestart
)

$InstallRun = $false
$Restart = $false
if ($ForceInstall) {
    REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Started
    & 'Z:\DotNet\NDP452-KB2901907-x86-x64-AllOS-ENU.exe' /q /norestart
    do {
        write-host "." -NoNewline
        Start-Sleep -Seconds 2
    }
    until ((Get-Process | Where {$_.ProcessName -like "NDP452-KB2901907-x86-x64-AllOS-ENU"}).Count -eq 0)
    $InstallRun = $True    
} else {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client') {
        if ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client').version -like "4.5*") {
            Write-Output ".Net Framework v4.5# already installed - exiting process"
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d LatestVersionAlreadyInstalled
            Start-Sleep -Seconds 3
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Complete
        } else {
            Write-Output ".Net Framework does not meet minimum requirements. Installing v4.5.2"
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Started
            & 'Z:\DotNet\NDP452-KB2901907-x86-x64-AllOS-ENU.exe' /q /norestart
            do {
                write-host "." -NoNewline
                Start-Sleep -Seconds 2
            }
            until ((Get-Process | Where {$_.ProcessName -like "NDP452-KB2901907-x86-x64-AllOS-ENU"}).Count -eq 0)
            $InstallRun = $True  
        }
    }
}

if ($InstallRun) {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client') {
        if ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client').version -like "4.5*") {
            Write-Output ".Net Framework installed successfully - Restarting Server"
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d InstalledSuccessfully
            Start-Sleep -Seconds 3
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Complete
            $Restart = $DoRestart
        } else {
            Write-Output ".Net Framework installation failed for some reason - check logs"
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d InstallError
            Start-Sleep -Seconds 3
            REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Complete
        }    
    } else {
        Write-Output ".Net Framework installation failed for some reason - check logs"
        REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d InstallError
        Start-Sleep -Seconds 3
        REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v DotNetInstallStatus /t REG_SZ /d Complete
    }
}


if ($Restart) {
    Write-Output "Restarting server"
    Restart-Computer
}