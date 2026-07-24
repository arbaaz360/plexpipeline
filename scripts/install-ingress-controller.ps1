[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found. Start Docker Desktop and enable Kubernetes first.'
}

$deployment = kubectl get deployment ingress-nginx-controller `
    -n ingress-nginx `
    -o name 2>$null
if ($LASTEXITCODE -eq 0 -and $deployment) {
    Write-Host 'ingress-nginx is already installed.'
    return
}

$version = 'controller-v1.15.1'
$uri = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/$version/deploy/static/provider/cloud/deploy.yaml"
$expectedSha256 = '502FDDCA66B09C20DD48B6D0A792A9671CD663A3A0D2A8BDA5AE990D13B6C5B2'
$manifest = Join-Path $env:TEMP "ingress-nginx-$version.yaml"

Invoke-WebRequest -Uri $uri -OutFile $manifest -UseBasicParsing
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifest).Hash
if ($actualSha256 -ne $expectedSha256) {
    throw "ingress-nginx manifest checksum mismatch: $actualSha256"
}

kubectl apply -f $manifest
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to install ingress-nginx.'
}

kubectl rollout status deployment/ingress-nginx-controller `
    -n ingress-nginx `
    --timeout=10m
if ($LASTEXITCODE -ne 0) {
    throw 'ingress-nginx did not become ready.'
}

Write-Host "ingress-nginx $version is ready." -ForegroundColor Green
