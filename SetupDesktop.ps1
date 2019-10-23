if (!(Test-Path function:Log)) {
    function Log([string]$line, [string]$color = "Gray") {
        ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm", ":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"
        Write-Host -ForegroundColor $color $line 
    }
}

if (!(Test-Path function:Get-WebFile)) {
    function Get-WebFile([string]$sourceUrl, [string]$destinationFile) {
        Log "Downloading $destinationFile"
        Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
        (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
    }
}

if (Test-Path -Path "C:\demo\navcontainerhelper-dev\NavContainerHelper.psm1") {
    Import-module "C:\demo\navcontainerhelper-dev\NavContainerHelper.psm1" -DisableNameChecking
}
else {
    Import-Module -name navcontainerhelper -DisableNameChecking
}

. (Join-Path $PSScriptRoot "settings.ps1")

Log -color Green "Setting up Desktop Experience"

$codeCmd = "C:\Program Files\Microsoft VS Code\bin\Code.cmd"
$codeExe = "C:\Program Files\Microsoft VS Code\Code.exe"
$firsttime = (!(Test-Path $codeExe))
$disableVsCodeUpdate = $false

if ($firsttime) {
    $Folder = "C:\DOWNLOAD\VSCode"
    $Filename = "$Folder\VSCodeSetup-stable.exe"

    New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
    if (!(Test-Path $Filename)) {
        $sourceUrl = "https://go.microsoft.com/fwlink/?Linkid=852157"

        Get-WebFile -SourceUrl $sourceUrl -destinationFile $Filename
    }
    
    Log "Installing Visual Studio Code (this might take a few minutes)"
    $setupParameters = "/VerySilent /CloseApplications /NoCancel /LoadInf=""c:\demo\vscode.inf"" /MERGETASKS=!runcode"
    Start-Process -FilePath $Filename -WorkingDirectory $Folder -ArgumentList $setupParameters -Wait -Passthru | Out-Null
}

if ($disableVsCodeUpdate) {
    $vsCodeSettingsFile = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "Code\User\settings.json"
    '{
        "update.channel": "none"
    }' | Set-Content $vsCodeSettingsFile
}

Log "Creating Desktop Shortcuts"
# TODO: temp fix
$landingPageUrl = "http://${hostname}"
# $landingPageUrl = "http://${publicDnsName}"

New-DesktopShortcut -Name "Landing Page" -TargetPath $landingPageUrl -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "Visual Studio Code" -TargetPath $codeExe
New-DesktopShortcut -Name "PowerShell ISE" -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\powershell_ise.exe" -WorkingDirectory "c:\demo"
New-DesktopShortcut -Name "Command Prompt" -TargetPath "C:\Windows\system32\cmd.exe" -WorkingDirectory "c:\demo"
New-DesktopShortcut -Name "Nav Container Helper" -TargetPath "c:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Arguments "-noexit ""& { Write-NavContainerHelperWelcomeText }""" -WorkingDirectory "C:\ProgramData\navcontainerhelper"
New-DesktopShortcut -Name "Workshop Files" -TargetPath "C:\WorkshopFiles\"
Log -color Green "Desktop setup complete!"
