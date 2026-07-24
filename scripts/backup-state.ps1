[CmdletBinding()]
param(
    [string]$DestinationRoot = 'X:\Backups\PlexPipeline'
)

$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell window.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $env:TEMP "samurai-state-$stamp"
$archive = Join-Path $DestinationRoot "samurai-state-$stamp.zip"
$partialArchive = Join-Path $DestinationRoot "samurai-state-$stamp.partial.zip"
$repoRoot = Split-Path $PSScriptRoot -Parent

New-Item -ItemType Directory -Path $stage, $DestinationRoot -Force | Out-Null
$log = Join-Path $DestinationRoot "last-backup-$stamp.log"
Start-Transcript -LiteralPath $log -Force | Out-Null

$radarrWasRunning = (Get-Service Radarr -ErrorAction SilentlyContinue).Status -eq 'Running'
$sonarrWasRunning = [bool](Get-Process 'Sonarr', 'Sonarr.Console' -ErrorAction SilentlyContinue)
$sabWasRunning = [bool](Get-Process 'SABnzbd-console' -ErrorAction SilentlyContinue)
$plexWasRunning = [bool](Get-Process 'Plex Media Server' -ErrorAction SilentlyContinue)
$overseerrWasRunning = [bool](docker ps --filter 'name=^/overseerr$' -q)

function Copy-StateItem {
    param([string]$Source, [string]$Destination)

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    $sourceItem = Get-Item -LiteralPath $Source -Force
    if ($sourceItem.PSIsContainer) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Get-ChildItem -LiteralPath $Source -Force |
            Copy-Item -Destination $Destination -Recurse -Force
    }
    else {
        New-Item `
            -ItemType Directory `
            -Path (Split-Path $Destination -Parent) `
            -Force |
            Out-Null
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

try {
    if ($radarrWasRunning) { Stop-Service Radarr -Force }
    if ($sonarrWasRunning) {
        Stop-Process -Name 'Sonarr', 'Sonarr.Console' -Force -ErrorAction SilentlyContinue
    }
    if ($sabWasRunning) { Stop-Process -Name 'SABnzbd-console' -Force }
    if ($plexWasRunning) { Stop-Process -Name 'Plex Media Server' -Force }
    if ($overseerrWasRunning) { docker stop overseerr | Out-Null }
    Start-Sleep -Seconds 3

    Copy-StateItem 'C:\ProgramData\Radarr\config.xml' "$stage\Radarr\config.xml"
    New-Item -ItemType Directory -Path "$stage\Radarr" -Force | Out-Null
    Get-ChildItem 'C:\ProgramData\Radarr\radarr.db*' -ErrorAction SilentlyContinue |
        Copy-Item -Destination "$stage\Radarr" -Force

    Copy-StateItem 'C:\ProgramData\Sonarr\config.xml' "$stage\Sonarr\config.xml"
    New-Item -ItemType Directory -Path "$stage\Sonarr" -Force | Out-Null
    Get-ChildItem 'C:\ProgramData\Sonarr\sonarr.db*' -ErrorAction SilentlyContinue |
        Copy-Item -Destination "$stage\Sonarr" -Force

    Copy-StateItem "$env:LOCALAPPDATA\sabnzbd\sabnzbd.ini" `
        "$stage\SABnzbd\sabnzbd.ini"
    Copy-StateItem "$env:LOCALAPPDATA\sabnzbd\admin" "$stage\SABnzbd\admin"

    Copy-StateItem "$env:LOCALAPPDATA\Plex Media Server\Plug-in Support\Databases" `
        "$stage\Plex\Databases"
    New-Item -ItemType Directory -Path "$stage\Plex" -Force | Out-Null
    reg.exe export 'HKCU\Software\Plex, Inc.\Plex Media Server' `
        "$stage\Plex\Plex Media Server.reg" /y | Out-Null

    $overseerrSource = $null
    $overseerrInspect = docker inspect overseerr 2>$null | ConvertFrom-Json
    if ($overseerrInspect) {
        $overseerrSource = $overseerrInspect.Mounts |
            Where-Object Destination -eq '/app/config' |
            Select-Object -ExpandProperty Source -First 1
    }
    if ($overseerrSource) {
        Copy-StateItem (Join-Path $overseerrSource 'db') "$stage\Overseerr\db"
        Copy-StateItem `
            (Join-Path $overseerrSource 'settings.json') `
            "$stage\Overseerr\settings.json"
    }

    $vaultConnections = Join-Path $env:USERPROFILE `
        'Documents\MyGeneralVault\Personal\Connections'
    Copy-StateItem $vaultConnections "$stage\Obsidian\Connections"

    Copy-StateItem "$env:LOCALAPPDATA\InstantPlex\pki" "$stage\LocalPKI"

    Copy-StateItem "$repoRoot\docker-compose.yml" `
        "$stage\Infrastructure\docker-compose.yml"
    Copy-StateItem "$repoRoot\config" "$stage\Infrastructure\config"

    $containerIds = docker ps -aq
    if ($containerIds) {
        docker inspect $containerIds | Set-Content "$stage\docker-inspect.json"
    }
    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        kubectl get service,endpoints,ingress -A -o yaml 2>$null |
            Set-Content "$stage\kubernetes-resources.yaml"
    }
    netsh advfirewall export "$stage\firewall.wfw" | Out-Null

    $requiredStageFiles = @(
        "$stage\Radarr\radarr.db",
        "$stage\Sonarr\sonarr.db",
        "$stage\SABnzbd\sabnzbd.ini",
        "$stage\LocalPKI\rootCA-key.pem",
        "$stage\LocalPKI\rootCA.pem",
        "$stage\Obsidian\Connections\How Samurai Local Services Work.md",
        "$stage\Obsidian\Connections\One-Click C Drive Recovery.md"
    )
    $missingStageFiles = @($requiredStageFiles | Where-Object {
        -not (Test-Path -LiteralPath $_ -PathType Leaf)
    })
    if ($missingStageFiles.Count -gt 0) {
        throw "Critical backup files are missing: $($missingStageFiles -join ', ')"
    }

    & tar.exe -a -c -f $partialArchive -C $stage .
    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe failed with exit code $LASTEXITCODE"
    }
    Move-Item -LiteralPath $partialArchive -Destination $archive
}
finally {
    if ($radarrWasRunning) { Start-Service Radarr }
    if ($sonarrWasRunning) {
        Start-Process 'C:\ProgramData\Sonarr\bin\Sonarr.Console.exe' `
            -ArgumentList '-nobrowser'
    }
    if ($sabWasRunning) {
        Start-Process 'C:\Program Files\SABnzbd\SABnzbd-console.exe' `
            -ArgumentList "-f `"$env:LOCALAPPDATA\sabnzbd\sabnzbd.ini`"" `
            -WindowStyle Hidden
    }
    if ($plexWasRunning) {
        Start-Process 'C:\Program Files\Plex\Plex Media Server\Plex Media Server.exe' `
            -WindowStyle Hidden
    }
    if ($overseerrWasRunning) { docker start overseerr | Out-Null }
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    if (Test-Path -LiteralPath $partialArchive) {
        Remove-Item -LiteralPath $partialArchive -Force
    }
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "Private backup created: $archive" -ForegroundColor Green
Write-Warning (
    'This archive contains credentials and the private local CA key. ' +
    'Never commit or share it.'
)
