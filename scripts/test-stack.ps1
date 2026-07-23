[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$checks = @(
    @{ Name = 'Plex'; Port = 32400; Path = '/identity' },
    @{ Name = 'Sonarr'; Port = 8989; Path = '/ping' },
    @{ Name = 'Radarr'; Port = 7878; Path = '/ping' },
    @{ Name = 'SABnzbd'; Port = 8080; Path = '/api?mode=version&output=json' },
    @{ Name = 'Overseerr'; Port = 5055; Path = '/api/v1/status' },
    @{ Name = 'Immich'; Port = 2283; Path = '/api/server/ping' }
)

$results = foreach ($check in $checks) {
    $url = "http://127.0.0.1:$($check.Port)$($check.Path)"
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $url
        $watch.Stop()
        [pscustomobject]@{
            Kind = 'Service'
            Target = $check.Name
            Status = $response.StatusCode
            Milliseconds = $watch.ElapsedMilliseconds
        }
    }
    catch {
        [pscustomobject]@{
            Kind = 'Service'
            Target = $check.Name
            Status = 'DOWN'
            Milliseconds = '-'
        }
    }
}

$folders = @(
    'X:\Plex\MOVIES',
    'X:\Plex\Documentary Movies',
    'X:\Plex\TV SERIES',
    'X:\Plex\Documentary Series'
)

foreach ($folder in $folders) {
    $results += [pscustomobject]@{
        Kind = 'Folder'
        Target = $folder
        Status = if (Test-Path -LiteralPath $folder) { 'OK' } else { 'MISSING' }
        Milliseconds = '-'
    }
}

$results | Format-Table Kind, Target, Status, Milliseconds -AutoSize
