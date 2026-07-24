[CmdletBinding()]
param(
    [string]$BackupRoot = 'X:\Backups\PlexPipeline',
    [switch]$Renew
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')
Assert-SamuraiAdministrator

$mkcertPath = Find-SamuraiCommand -Name 'mkcert.exe'
if (-not $mkcertPath) {
    $mkcertPath = Get-ChildItem `
        -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') `
        -Recurse `
        -Filter 'mkcert.exe' `
        -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName -First 1
}
if (-not $mkcertPath) {
    throw 'mkcert was not found. Run install-prerequisites.ps1 first.'
}

$pkiPath = Join-Path $env:LOCALAPPDATA 'InstantPlex\pki'
New-Item -ItemType Directory -Path $pkiPath -Force | Out-Null

$acl = New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$inheritance = [System.Security.AccessControl.InheritanceFlags](
    'ContainerInherit, ObjectInherit'
)
$propagation = [System.Security.AccessControl.PropagationFlags]::None
$allow = [System.Security.AccessControl.AccessControlType]::Allow
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    $currentUser,
    'FullControl',
    $inheritance,
    $propagation,
    $allow
)))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    'NT AUTHORITY\SYSTEM',
    'FullControl',
    $inheritance,
    $propagation,
    $allow
)))
Set-Acl -LiteralPath $pkiPath -AclObject $acl

$env:CAROOT = $pkiPath
& $mkcertPath -install
if ($LASTEXITCODE -ne 0) {
    throw "mkcert -install failed with exit code $LASTEXITCODE."
}

$certificatePath = Join-Path $pkiPath 'samurai.local.pem'
$keyPath = Join-Path $pkiPath 'samurai.local-key.pem'
$needsCertificate = $Renew -or
    -not (Test-Path -LiteralPath $certificatePath) -or
    -not (Test-Path -LiteralPath $keyPath)

if (-not $needsCertificate) {
    $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2(
        $certificatePath
    )
    $needsCertificate = $certificate.NotAfter -lt (Get-Date).AddDays(60)
}

if ($needsCertificate) {
    & $mkcertPath `
        -cert-file $certificatePath `
        -key-file $keyPath `
        '*.samurai.local' `
        'samurai.local'
    if ($LASTEXITCODE -ne 0) {
        throw "mkcert certificate generation failed with exit code $LASTEXITCODE."
    }
}

$rootPem = Join-Path $pkiPath 'rootCA.pem'
if (-not (Test-Path -LiteralPath $rootPem)) {
    throw "Local root CA certificate is missing: $rootPem"
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$publicExports = @(
    (Join-Path $BackupRoot 'InstantPlex-Samurai-Root-CA.cer'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'InstantPlex-Samurai-Root-CA.cer')
)

foreach ($publicExport in $publicExports) {
    certutil.exe -f -decode $rootPem $publicExport | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export the public CA certificate to $publicExport."
    }
}

$serverCertificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2(
    $certificatePath
)
Write-Host (
    "Local HTTPS certificate is ready and expires {0:yyyy-MM-dd}." -f
    $serverCertificate.NotAfter
) -ForegroundColor Green
Write-Host "Public client certificate: $($publicExports[0])"
