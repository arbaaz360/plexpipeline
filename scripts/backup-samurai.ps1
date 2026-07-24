[CmdletBinding()]
param(
    [string]$DestinationRoot = 'X:\Backups\PlexPipeline'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

if (-not (Test-SamuraiAdministrator)) {
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $PSCommandPath + '"'),
        '-DestinationRoot', ('"' + $DestinationRoot + '"')
    ) -join ' '
    $process = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $arguments `
        -Verb RunAs `
        -Wait `
        -PassThru
    exit $process.ExitCode
}

& (Join-Path $PSScriptRoot 'backup-state.ps1') `
    -DestinationRoot $DestinationRoot
if (-not $?) {
    throw 'The core state backup failed.'
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$repositoryParent = Split-Path $repoRoot -Parent
$immichRepo = Get-SamuraiRelatedRepository `
    -Name 'immich' `
    -RemoteUrl 'https://github.com/arbaaz360/immich.git' `
    -RequiredRelativePath 'recovery\Backup-LocalImmichState.ps1' `
    -CandidatePaths @(
        (Join-Path $repositoryParent 'immich'),
        (Join-Path $repositoryParent 'immich-repo')
    )

& (Join-Path $immichRepo 'recovery\Backup-LocalImmichState.ps1')
if (-not $?) {
    throw 'The related Immich recovery backup failed.'
}

Write-Host 'All private Samurai recovery data is ready.' -ForegroundColor Green
Write-Host "  Plex Pipeline: $DestinationRoot"
Write-Host '  Immich: X:\Backups\Immich\Recovery'
