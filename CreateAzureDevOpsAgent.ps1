param (
    [string] $AgentPath = "C:\agents",
    [string] $WorkDirectory = ""
)

if (!($AgentPath)) { 
    New-Item -Path $AgentPath -ItemType Directory -Force
}

$settings = Get-Content (Join-Path $PSScriptRoot 'AgentSettings.json') | ConvertFrom-Json
$url = $settings.Url
$PAT = $settings.PAT
$pool = $settings.Pool
$agentName = $settings.Name
$agentAccount = $settings.Account
if (!($WorkDirectory)) {
    $workDirectory = $settings.WorkDirectory
}
if (!$WorkDirectory) {
    $WorkDirectory = '_work'
}

$APIjson = Invoke-WebRequest https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | ConvertFrom-Json
$downloadJsonUrl = $APIjson.assets.browser_download_url

$downloadJson = Invoke-WebRequest $downloadJsonUrl | ConvertFrom-Json
foreach ($Agent in $downloadJson) {
    if ($Agent.platform -eq 'win-x64') {
        $downloadUrl = $Agent.downloadUrl
        $FileName = $Agent.name
        break
    }
}
$tempFile = "$env:temp\$FileName"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, $tempFile) 
Expand-Archive $tempFile -DestinationPath "$AgentPath/$agentName"
Remove-Item $tempFile -Force
$AgendConfigCmd = "$AgentPath\$agentName\config.cmd"
$Parameters = "--unattended --url $url --auth pat --token $PAT --pool $pool --agent $agentName --work $WorkDirectory --runAsService --windowsLogonAccount ""$agentAccount"""

Start-Process -Wait -FilePath $AgendConfigCmd -ArgumentList $Parameters