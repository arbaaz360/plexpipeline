[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Archive,

    [switch]$ConfirmRestore
)

$ErrorActionPreference = 'Stop'

if (-not $ConfirmRestore) {
    throw 'Pass -ConfirmRestore after checking the archive and destination paths.'
}

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell window.'
}

if (-not (Test-Path -LiteralPath $Archive)) {
    throw "Archive not found: $Archive"
}

$work = Join-Path $env:TEMP ('samurai-restore-' + [guid]::NewGuid())
Expand-Archive -LiteralPath $Archive -DestinationPath $work

if (-not $PSCmdlet.ShouldProcess(
        'Samurai media services',
        'Stop services, restore configuration, and restart'
    )) {
    return
}

try {
    Stop-Service Radarr -Force -ErrorAction SilentlyContinue
    Stop-Process -Name 'Sonarr.Console', 'SABnzbd-console', 'Plex Media Server' `
        -Force -ErrorAction SilentlyContinue
    docker stop overseerr 2>$null | Out-Null

    New-Item -ItemType Directory -Path `
        'C:\ProgramData\Radarr',
        'C:\ProgramData\Sonarr',
        "$env:LOCALAPPDATA\sabnzbd",
        "$env:LOCALAPPDATA\Plex Media Server\Plug-in Support" -Force |
        Out-Null

    Copy-Item "$work\Radarr\*" 'C:\ProgramData\Radarr' -Recurse -Force
    Copy-Item "$work\Sonarr\*" 'C:\ProgramData\Sonarr' -Recurse -Force
    Copy-Item "$work\SABnzbd\*" "$env:LOCALAPPDATA\sabnzbd" -Recurse -Force
    Copy-Item "$work\Plex\Databases" `
        "$env:LOCALAPPDATA\Plex Media Server\Plug-in Support" -Recurse -Force
    reg.exe import "$work\Plex\Plex Media Server.reg" | Out-Null

    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (Test-Path "$work\Overseerr") {
        New-Item -ItemType Directory -Path "$repoRoot\data" -Force | Out-Null
        Copy-Item "$work\Overseerr" "$repoRoot\data" -Recurse -Force
    }

    if (Test-Path "$work\Obsidian\Connections") {
        $vaultRoot = Join-Path $env:USERPROFILE `
            'Documents\MyGeneralVault\Personal'
        New-Item -ItemType Directory -Path $vaultRoot -Force | Out-Null
        Copy-Item "$work\Obsidian\Connections" $vaultRoot -Recurse -Force
    }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Start-Service Radarr
Start-Process 'C:\ProgramData\Sonarr\bin\Sonarr.Console.exe' `
    -ArgumentList '-nobrowser'
Start-Process 'C:\Program Files\SABnzbd\SABnzbd-console.exe' `
    -ArgumentList "-f `"$env:LOCALAPPDATA\sabnzbd\sabnzbd.ini`"" `
    -WindowStyle Hidden
Start-Process 'C:\Program Files\Plex\Plex Media Server\Plex Media Server.exe' `
    -WindowStyle Hidden

$repoRoot = Split-Path $PSScriptRoot -Parent
docker compose --project-directory $repoRoot up -d overseerr

Write-Host 'State restored and core applications started. Run test-stack.ps1.' `
    -ForegroundColor Green
