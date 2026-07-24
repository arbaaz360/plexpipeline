[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')
Assert-SamuraiAdministrator

$repoRoot = Split-Path $PSScriptRoot -Parent
$networkRoot = Join-Path $repoRoot 'network'
$scriptPath = Join-Path $networkRoot 'mdns-broadcaster.js'
$nodePath = Find-SamuraiCommand -Name 'node.exe' -FallbackPaths @(
    'C:\Program Files\nodejs\node.exe'
)
$npmPath = Find-SamuraiCommand -Name 'npm.cmd' -FallbackPaths @(
    'C:\Program Files\nodejs\npm.cmd'
)

if (-not $nodePath -or -not $npmPath) {
    throw 'Node.js and npm are required. Run install-prerequisites.ps1 first.'
}

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "mDNS responder was not found: $scriptPath"
}

Push-Location $networkRoot
try {
    & $npmPath ci --omit=dev
    if ($LASTEXITCODE -ne 0) {
        throw "npm ci failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$taskName = 'InstantPlex mDNS Broadcaster'
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq 'node.exe' -and
        $_.CommandLine -match 'mdns-broadcaster\.js'
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction `
    -Execute $nodePath `
    -Argument ('"' + $scriptPath + '"') `
    -WorkingDirectory $networkRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 10 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Advertises InstantPlex service hostnames over LAN mDNS.' `
    -Force | Out-Null

$firewallName = 'InstantPlex mDNS'
Get-NetFirewallRule -DisplayName $firewallName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule
New-NetFirewallRule `
    -DisplayName $firewallName `
    -Direction Inbound `
    -Action Allow `
    -Protocol UDP `
    -LocalPort 5353 `
    -Program $nodePath `
    -Profile Private | Out-Null

$hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
$serviceNames = @(
    'sonarr.samurai.local',
    'radarr.samurai.local',
    'overseerr.samurai.local',
    'plex.samurai.local',
    'immich.samurai.local',
    'sabnzbd.samurai.local'
)
$beginMarker = '# BEGIN InstantPlex local services'
$endMarker = '# END InstantPlex local services'
$hostsLines = @(Get-Content -LiteralPath $hostsPath)
$filteredLines = New-Object System.Collections.Generic.List[string]
$insideManagedBlock = $false

foreach ($line in $hostsLines) {
    if ($line -eq $beginMarker) {
        $insideManagedBlock = $true
        continue
    }
    if ($line -eq $endMarker) {
        $insideManagedBlock = $false
        continue
    }
    if ($insideManagedBlock) {
        continue
    }

    $isOldInstantPlexLine = (
        $line -match '^\s*127\.0\.0\.1\s+' -and
        $serviceNames.Where({ $line -match [regex]::Escape($_) }).Count -gt 0
    )
    if (-not $isOldInstantPlexLine) {
        $filteredLines.Add($line)
    }
}

$filteredLines.Add('')
$filteredLines.Add($beginMarker)
$filteredLines.Add('127.0.0.1 ' + ($serviceNames -join ' '))
$filteredLines.Add($endMarker)
$filteredLines | Set-Content -LiteralPath $hostsPath -Encoding ascii

Start-ScheduledTask -TaskName $taskName
Wait-SamuraiCondition `
    -Description 'the mDNS responder to bind UDP port 5353' `
    -TimeoutSeconds 30 `
    -PollSeconds 1 `
    -Condition {
        [bool](Get-NetUDPEndpoint -LocalPort 5353 -ErrorAction SilentlyContinue |
            Where-Object {
                (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name -eq 'node'
            })
    }

$lanIp = Get-SamuraiLanIpv4
Write-Host "mDNS is advertising *.samurai.local on $lanIp." -ForegroundColor Green
