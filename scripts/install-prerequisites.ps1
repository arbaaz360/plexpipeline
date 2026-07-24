[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell window.'
}

$packages = @(
    'Git.Git',
    'Plex.PlexMediaServer',
    'SABnzbdTeam.SABnzbd',
    'TeamSonarr.Sonarr',
    'TeamRadarr.Radarr',
    'Docker.DockerDesktop',
    'Tailscale.Tailscale',
    'Obsidian.Obsidian',
    'OpenJS.NodeJS.LTS',
    'FiloSottile.mkcert'
)

foreach ($id in $packages) {
    Write-Host "Installing/checking $id..."
    winget install --id $id --exact --silent `
        --accept-package-agreements --accept-source-agreements
}

$mediaFolders = @(
    'X:\Plex\MOVIES',
    'X:\Plex\Documentary Movies',
    'X:\Plex\TV SERIES',
    'X:\Plex\Documentary Series',
    'X:\Backups\PlexPipeline'
)

foreach ($folder in $mediaFolders) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

Write-Host 'Prerequisites installed.' -ForegroundColor Green
