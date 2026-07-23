[CmdletBinding()]
param(
    [string]$HostIp
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found. Enable Kubernetes in Docker Desktop first.'
}

if (-not $HostIp) {
    $HostIp = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notmatch '^(127\.|169\.254\.|172\.|10\.)' -and
            $_.InterfaceAlias -notmatch 'vEthernet|Tailscale|Loopback'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -ExpandProperty IPAddress -First 1
}

if (-not $HostIp) {
    throw 'Could not determine the LAN IPv4 address. Pass -HostIp explicitly.'
}

$template = Join-Path $PSScriptRoot '..\config\homelab-ingress.template.yaml'
$rendered = Join-Path ([IO.Path]::GetTempPath()) 'samurai-homelab-ingress.yaml'

(Get-Content -LiteralPath $template -Raw).Replace('__HOST_IP__', $HostIp) |
    Set-Content -LiteralPath $rendered -Encoding utf8

kubectl apply -f $rendered
Write-Host "Ingress applied for host IP $HostIp" -ForegroundColor Green
