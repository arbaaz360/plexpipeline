function Test-SamuraiAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Assert-SamuraiAdministrator {
    if (-not (Test-SamuraiAdministrator)) {
        throw 'Run this operation as an administrator.'
    }
}

function Get-SamuraiLanIpv4 {
    $virtualPattern = 'vEthernet|Tailscale|Loopback|Docker|WSL|VPN|ZeroTier'

    $candidate = Get-NetIPConfiguration |
        Where-Object {
            $_.IPv4DefaultGateway -and
            $_.InterfaceAlias -notmatch $virtualPattern
        } |
        ForEach-Object {
            $configuration = $_
            $_.IPv4Address |
                Where-Object {
                    $_.IPAddress -notmatch '^(127\.|169\.254\.)'
                } |
                ForEach-Object {
                    [pscustomobject]@{
                        Address = $_.IPAddress
                        InterfaceAlias = $configuration.InterfaceAlias
                        InterfaceIndex = $configuration.InterfaceIndex
                    }
                }
        } |
        Sort-Object InterfaceIndex |
        Select-Object -First 1

    if (-not $candidate) {
        throw 'Could not find a physical LAN IPv4 address with a default gateway.'
    }

    return $candidate.Address
}

function Wait-SamuraiCondition {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Condition,

        [Parameter(Mandatory)]
        [string]$Description,

        [int]$TimeoutSeconds = 300,
        [int]$PollSeconds = 3
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) {
            return
        }
        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for $Description."
}

function Find-SamuraiCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string[]]$FallbackPaths = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($path in $FallbackPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    return $null
}

function Get-SamuraiRelatedRepository {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$RemoteUrl,

        [Parameter(Mandatory)]
        [string]$RequiredRelativePath,

        [string[]]$CandidatePaths = @()
    )

    foreach ($candidate in $CandidatePaths) {
        if (
            $candidate -and
            (Test-Path `
                -LiteralPath (Join-Path $candidate $RequiredRelativePath) `
                -PathType Leaf)
        ) {
            return $candidate
        }
    }

    $git = Find-SamuraiCommand -Name 'git.exe' -FallbackPaths @(
        'C:\Program Files\Git\cmd\git.exe'
    )
    if (-not $git) {
        throw "Git is required to download the related $Name repository."
    }

    $repositoryParent = Join-Path $env:LOCALAPPDATA 'Samurai\repositories'
    $repositoryPath = Join-Path $repositoryParent $Name
    New-Item -ItemType Directory -Path $repositoryParent -Force | Out-Null

    if (Test-Path -LiteralPath (Join-Path $repositoryPath '.git')) {
        & $git -C $repositoryPath pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Write-Warning (
                "Could not update the cached $Name repository; using its " +
                'existing checkout.'
            )
        }
    }
    else {
        & $git clone $RemoteUrl $repositoryPath
        if ($LASTEXITCODE -ne 0) {
            throw "Could not clone the related $Name repository."
        }
    }

    if (-not (Test-Path `
        -LiteralPath (Join-Path $repositoryPath $RequiredRelativePath) `
        -PathType Leaf)) {
        throw "$Name repository is missing $RequiredRelativePath."
    }

    return $repositoryPath
}
