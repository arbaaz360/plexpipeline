[CmdletBinding()]
param(
    [string]$BackupRoot = 'X:\Backups\PlexPipeline',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

if (-not (Test-SamuraiAdministrator) -and -not $ValidateOnly) {
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $PSCommandPath + '"'),
        '-BackupRoot', ('"' + $BackupRoot + '"')
    )
    if ($ValidateOnly) {
        $arguments += '-ValidateOnly'
    }

    $process = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList ($arguments -join ' ') `
        -Verb RunAs `
        -Wait `
        -PassThru
    exit $process.ExitCode
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$requiredFiles = @(
    (Join-Path $PSScriptRoot 'install-prerequisites.ps1'),
    (Join-Path $PSScriptRoot 'restore-state.ps1'),
    (Join-Path $PSScriptRoot 'setup-local-https.ps1'),
    (Join-Path $PSScriptRoot 'setup-mdns.ps1'),
    (Join-Path $PSScriptRoot 'install-ingress-controller.ps1'),
    (Join-Path $PSScriptRoot 'apply-ingress.ps1'),
    (Join-Path $PSScriptRoot 'test-stack.ps1'),
    (Join-Path $repoRoot 'network\mdns-broadcaster.js'),
    (Join-Path $repoRoot 'config\homelab-ingress.template.yaml')
)
$missingFiles = @($requiredFiles | Where-Object {
    -not (Test-Path -LiteralPath $_ -PathType Leaf)
})
if ($missingFiles.Count -gt 0) {
    throw "Recovery kit is incomplete: $($missingFiles -join ', ')"
}

$latestArchive = Get-ChildItem `
    -LiteralPath $BackupRoot `
    -Filter 'samurai-state-*.zip' `
    -File `
    -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$immichManifest = 'X:\Backups\Immich\Recovery\manifest.json'

if ($ValidateOnly) {
    Write-Host 'Recovery kit validation:' -ForegroundColor Cyan
    Write-Host "  Repository: $repoRoot"
    Write-Host "  Latest core backup: $(
        if ($latestArchive) { $latestArchive.FullName } else { 'MISSING' }
    )"
    Write-Host "  Immich recovery set: $(
        if (Test-Path -LiteralPath $immichManifest) { 'present' } else { 'MISSING' }
    )"
    Write-Host "  LAN IPv4: $(Get-SamuraiLanIpv4)"
    Write-Host 'Validation completed without changing the system.' -ForegroundColor Green
    return
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$transcript = Join-Path $BackupRoot (
    'setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log'
)
Start-Transcript -LiteralPath $transcript -Force | Out-Null

try {
    Write-Host 'Phase 1/7: installing prerequisites...' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'install-prerequisites.ps1')

    $dockerPath = Find-SamuraiCommand -Name 'docker.exe' -FallbackPaths @(
        'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
    )
    $kubectlPath = Find-SamuraiCommand -Name 'kubectl.exe' -FallbackPaths @(
        'C:\Program Files\Docker\Docker\resources\bin\kubectl.exe'
    )
    if (-not $dockerPath -or -not $kubectlPath) {
        throw (
            'Docker Desktop was installed but its CLI is not ready. Restart ' +
            'Windows, then double-click Setup-Samurai.cmd again.'
        )
    }

    $dockerBin = Split-Path $dockerPath
    if ($env:PATH -notlike "*$dockerBin*") {
        $env:PATH = "$dockerBin;$env:PATH"
    }

    Write-Host 'Phase 2/7: starting Docker Desktop...' -ForegroundColor Cyan
    & $dockerPath desktop start
    Wait-SamuraiCondition `
        -Description 'Docker Desktop' `
        -TimeoutSeconds 300 `
        -PollSeconds 5 `
        -Condition {
            & $dockerPath info *> $null
            return $LASTEXITCODE -eq 0
        }

    & $kubectlPath get nodes *> $null
    if ($LASTEXITCODE -ne 0) {
        $settingsPath = Join-Path $env:APPDATA 'Docker\settings-store.json'
        if (-not (Test-Path -LiteralPath $settingsPath)) {
            throw (
                'Docker Desktop has not completed its first launch. Complete ' +
                'the Docker Desktop welcome screen, then run Setup-Samurai.cmd again.'
            )
        }

        Write-Host 'Enabling Docker Desktop Kubernetes...'
        & $dockerPath desktop stop
        Copy-Item `
            -LiteralPath $settingsPath `
            -Destination (Join-Path $BackupRoot 'docker-settings-before-kubernetes.json') `
            -Force
        $dockerSettings = Get-Content -LiteralPath $settingsPath -Raw |
            ConvertFrom-Json
        $dockerSettings |
            Add-Member -NotePropertyName KubernetesEnabled -NotePropertyValue $true -Force
        $dockerSettings |
            Add-Member -NotePropertyName AutoStart -NotePropertyValue $true -Force
        $dockerSettings |
            ConvertTo-Json -Depth 100 |
            Set-Content -LiteralPath $settingsPath -Encoding utf8
        & $dockerPath desktop start

        Wait-SamuraiCondition `
            -Description 'the Docker Desktop Kubernetes node' `
            -TimeoutSeconds 900 `
            -PollSeconds 10 `
            -Condition {
                & $kubectlPath get nodes *> $null
                return $LASTEXITCODE -eq 0
            }
    }

    Write-Host 'Phase 3/7: restoring private application state...' -ForegroundColor Cyan
    $coreStatePaths = @(
        'C:\ProgramData\Sonarr\sonarr.db',
        'C:\ProgramData\Radarr\radarr.db',
        (Join-Path $env:LOCALAPPDATA 'sabnzbd\sabnzbd.ini'),
        (Join-Path $env:LOCALAPPDATA 'Plex Media Server\Plug-in Support\Databases')
    )
    $missingCoreState = @($coreStatePaths | Where-Object {
        -not (Test-Path -LiteralPath $_)
    })

    if ($missingCoreState.Count -ge 3) {
        if (-not $latestArchive) {
            throw (
                "This looks like a fresh C: drive, but no samurai-state backup " +
                "exists under $BackupRoot."
            )
        }

        & (Join-Path $PSScriptRoot 'restore-state.ps1') `
            -Archive $latestArchive.FullName `
            -ConfirmRestore `
            -Confirm:$false
    }
    else {
        Write-Host 'Existing core application state detected; destructive restore skipped.'
    }

    Write-Host 'Phase 4/7: restoring local HTTPS and mDNS...' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'setup-local-https.ps1') `
        -BackupRoot $BackupRoot
    & (Join-Path $PSScriptRoot 'setup-mdns.ps1')

    Write-Host 'Phase 5/7: installing the HTTPS ingress...' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'install-ingress-controller.ps1')
    & (Join-Path $PSScriptRoot 'apply-ingress.ps1')

    Write-Host 'Phase 6/7: restoring related Immich state...' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $immichManifest -PathType Leaf) {
        $repositoryParent = Split-Path $repoRoot -Parent
        $immichRepo = Get-SamuraiRelatedRepository `
            -Name 'immich' `
            -RemoteUrl 'https://github.com/arbaaz360/immich.git' `
            -RequiredRelativePath 'recovery\Restore-LocalImmichState.ps1' `
            -CandidatePaths @(
                (Join-Path $repositoryParent 'immich'),
                (Join-Path $repositoryParent 'immich-repo')
            )
        & (Join-Path $immichRepo 'recovery\Restore-LocalImmichState.ps1')
        if (-not $?) {
            throw 'The related Immich recovery failed.'
        }
    }
    else {
        Write-Warning (
            'No Immich recovery set was found. Immich restoration was skipped.'
        )
    }

    Write-Host 'Phase 7/7: validating the restored stack...' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'test-stack.ps1')

    Write-Host ''
    Write-Host 'Samurai recovery completed.' -ForegroundColor Green
    Write-Host "Setup log: $transcript"
    Write-Host 'Manual actions that cannot be safely automated:'
    Write-Host '  - Sign in to Tailscale if it is not already connected.'
    Write-Host '  - Sign in to Plex, Overseerr, or Immich if sessions expired.'
    Write-Host '  - If a new CA was generated, install the public .cer on Apple devices.'
}
finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
}
