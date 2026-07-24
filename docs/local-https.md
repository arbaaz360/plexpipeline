# Local HTTPS

The `*.samurai.local` services use a private certificate authority because
public certificate authorities cannot issue certificates for `.local` names.

## Server files

The private CA and server keys are stored outside the repository:

```text
%LOCALAPPDATA%\InstantPlex\pki
```

Do not copy or share `rootCA-key.pem` or `samurai.local-key.pem`.

`Backup-Samurai.cmd` includes this private PKI directory in the private
recovery archive on X:. The archive is not encrypted and must remain private.
Restoring the same CA means Apple
devices do not need to trust a new certificate after Windows is reinstalled.

The public CA certificate that client devices may safely install is:

```text
..\..\InstantPlex-Samurai-Root-CA.cer
```

## Apply the TLS secret and ingress

Run:

```powershell
.\scripts\apply-ingress.ps1
```

The script updates the `samurai-local-tls` Kubernetes secret from the local
server certificate before applying the ingress.

## Trust the CA on Apple devices

On macOS, open the public CA certificate in Keychain Access, add it to the
System keychain, and set the certificate to **Always Trust**.

On iPhone or iPad:

1. Transfer and open the public CA certificate.
2. Install the downloaded profile under **Settings > General > VPN & Device
   Management**.
3. Enable the CA under **Settings > General > About > Certificate Trust
   Settings**.

Only the public CA certificate belongs on client devices.
