$ErrorActionPreference = "Stop"
# TODO: not used?
# $WarningActionPreference = "Continue"

$ComputerInfo = Get-ComputerInfo
$WindowsInstallationType = $ComputerInfo.WindowsInstallationType
# TODO: not used?
# $WindowsProductName = $ComputerInfo.WindowsProductName

try {

    if (Get-ScheduledTask -TaskName SetupVm -ErrorAction Ignore) {
        schtasks /DELETE /TN SetupVm /F | Out-Null
    }

    function Log([string]$line, [string]$color = "Gray") {
        ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm", ":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" 
    }

    Log "SetupVm, User: $env:USERNAME"

    if (Test-Path -Path "C:\demo\navcontainerhelper-dev\NavContainerHelper.psm1") {
        Import-module "C:\demo\navcontainerhelper-dev\NavContainerHelper.psm1" -DisableNameChecking
    }
    else {
        Import-Module -name navcontainerhelper -DisableNameChecking
    }

    . (Join-Path $PSScriptRoot "settings.ps1")

    if ($WindowsInstallationType -eq "Server") {
        Log "Starting docker"
        start-service docker
    }
    else {
        if (!(Test-Path -Path "C:\Program Files\Docker\Docker\Docker for Windows.exe" -PathType Leaf)) {
            Log "Install Docker"
            $dockerexe = "C:\DOWNLOAD\DockerInstall.exe"
            (New-Object System.Net.WebClient).DownloadFile("https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe", $dockerexe)
            Start-Process -FilePath $dockerexe -ArgumentList "install --quiet" -Wait

            Log "Restarting computer and start Docker"
            shutdown -r -t 30

            exit

        }
        else {
            Log "Waiting for docker to start... (this should only take a few minutes)"
            Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker for Windows.exe" -PassThru
            $serverOsStr = "  OS/Arch:      "
            do {
                Start-Sleep -Seconds 10
                $dockerver = docker version
            } while ($LASTEXITCODE -ne 0)
            $serverOs = ($dockerver | where-Object { $_.startsWith($serverOsStr) }).SubString($serverOsStr.Length)
            if (!$serverOs.startsWith("windows")) {
                Log "Switching to Windows Containers"
                & "c:\program files\docker\docker\dockercli" -SwitchDaemon
            }
        }
    }

    Log "Enabling Docker API"
    New-item -Path "C:\ProgramData\docker\config" -ItemType Directory -Force -ErrorAction Ignore | Out-Null
    '{
    "hosts": ["tcp://0.0.0.0:2375", "npipe://"]
}' | Set-Content "C:\ProgramData\docker\config\daemon.json"
    netsh advfirewall firewall add rule name="Docker" dir=in action=allow protocol=TCP localport=2375 | Out-Null

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

    Log "Enabling File Download in IE"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0

    Log "Enabling Font Download in IE"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0

    Log "Show hidden files and file types"
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  -Name "Hidden"      -value 1
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  -Name "HideFileExt" -value 0

    if ($WindowsInstallationType -eq "Server") {
        Log "Disabling Server Manager Open At Logon"
        New-ItemProperty -Path "HKCU:\Software\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -PropertyType "DWORD" -Value "0x1" –Force | Out-Null
    }

    Log "Add Import navcontainerhelper to PowerShell profile"
    $winPsFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell"
    New-Item $winPsFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null

    'if (Test-Path -Path "C:\demo\navcontainerhelper-dev\NavContainerHelper.psm1") {
    Import-module "C:\demo\navcontainerhelper-dev\NavContainerHelper.psm1" -DisableNameChecking
} else {
    Import-Module -name navcontainerhelper -DisableNameChecking
}' | Set-Content (Join-Path $winPsFolder "Profile.ps1")

    Log "Adding Landing Page to Startup Group"
    $landingPageUrl = "http://${publicDnsName}"

    New-DesktopShortcut -Name "Landing Page" -TargetPath "C:\Program Files\Internet Explorer\iexplore.exe" -Shortcuts "CommonStartup" -Arguments $landingPageUrl
    if ($style -eq "devpreview") {
        New-DesktopShortcut -Name "Modern Dev Tools" -TargetPath "C:\Program Files\Internet Explorer\iexplore.exe" -Shortcuts "CommonStartup" -Arguments "http://aka.ms/moderndevtools"
    }

    . "c:\demo\SetupDesktop.ps1"

    $finalSetupScript = (Join-Path $PSScriptRoot "FinalSetupScript.ps1")
    if (Test-Path $finalSetupScript) {
        Log "Running FinalSetupScript"
        . $finalSetupScript
    }

    if (Get-ScheduledTask -TaskName SetupStart -ErrorAction Ignore) {
        schtasks /DELETE /TN SetupStart /F | Out-Null
    }

    if ($RunWindowsUpdate -eq "Yes") {
        Log "Installing Windows Updates"
        install-module PSWindowsUpdate -force
        Get-WUInstall -install -acceptall -autoreboot | ForEach-Object { Log ($_.Status + " " + $_.KB + " " + $_.Title) }
        Log "Windows updates installed"
    }

    shutdown -r -t 30

}
catch {
    Log -Color Red -line $_.Exception.Message
    $_.ScriptStackTrace.Replace("`r`n", "`n").Split("`n") | ForEach-Object { Log -Color Red -line $_ }
    throw
}
