[CmdletBinding()]
param(
    [string]$HostIp,
    [string]$TlsCertificatePath = (Join-Path $env:LOCALAPPDATA 'InstantPlex\pki\samurai.local.pem'),
    [string]$TlsKeyPath = (Join-Path $env:LOCALAPPDATA 'InstantPlex\pki\samurai.local-key.pem')
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found. Enable Kubernetes in Docker Desktop first.'
}

if (-not $HostIp) {
    $HostIp = Get-SamuraiLanIpv4
}

if (-not $HostIp) {
    throw 'Could not determine the LAN IPv4 address. Pass -HostIp explicitly.'
}

if (-not (Test-Path -LiteralPath $TlsCertificatePath -PathType Leaf)) {
    throw "TLS certificate not found: $TlsCertificatePath"
}

if (-not (Test-Path -LiteralPath $TlsKeyPath -PathType Leaf)) {
    throw "TLS private key not found: $TlsKeyPath"
}

$template = Join-Path $PSScriptRoot '..\config\homelab-ingress.template.yaml'
$rendered = Join-Path ([IO.Path]::GetTempPath()) 'samurai-homelab-ingress.yaml'

(Get-Content -LiteralPath $template -Raw).Replace('__HOST_IP__', $HostIp) |
    Set-Content -LiteralPath $rendered -Encoding utf8

kubectl create secret tls samurai-local-tls `
    --namespace default `
    --cert $TlsCertificatePath `
    --key $TlsKeyPath `
    --dry-run=client `
    -o yaml |
    kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    throw 'Failed to apply the samurai-local-tls Kubernetes secret.'
}

kubectl apply -f $rendered
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to apply the homelab ingress.'
}

Write-Host "Ingress applied for host IP $HostIp" -ForegroundColor Green
