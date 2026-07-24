[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$checks = @(
    @{ Name = 'Plex'; Hostname = 'plex.samurai.local'; Port = 32400; Path = '/identity' },
    @{ Name = 'Sonarr'; Hostname = 'sonarr.samurai.local'; Port = 8989; Path = '/ping' },
    @{ Name = 'Radarr'; Hostname = 'radarr.samurai.local'; Port = 7878; Path = '/ping' },
    @{ Name = 'SABnzbd'; Hostname = 'sabnzbd.samurai.local'; Port = 8080; Path = '/api?mode=version&output=json' },
    @{ Name = 'Overseerr'; Hostname = 'overseerr.samurai.local'; Port = 5055; Path = '/api/v1/status' },
    @{ Name = 'Immich'; Hostname = 'immich.samurai.local'; Port = 2283; Path = '/api/server/ping' }
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

foreach ($check in $checks) {
    $url = "https://$($check.Hostname)$($check.Path)"
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $url
        $watch.Stop()
        $results += [pscustomobject]@{
            Kind = 'HTTPS'
            Target = $check.Name
            Status = $response.StatusCode
            Milliseconds = $watch.ElapsedMilliseconds
        }
    }
    catch {
        $results += [pscustomobject]@{
            Kind = 'HTTPS'
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

$failed = @($results | Where-Object {
    $_.Status -in @('DOWN', 'MISSING')
})
if ($failed.Count -gt 0) {
    throw "$($failed.Count) stack validation check(s) failed."
}
