# Recovery After Formatting C:

## The two-button model

The repository contains two double-click launchers:

| Launcher | When to use it |
|---|---|
| `Backup-Samurai.cmd` | Before formatting C:, and after important configuration changes |
| `Setup-Samurai.cmd` | After reinstalling Windows, from a downloaded or cloned repository |

Both launchers request administrator access when needed.

## Before formatting

1. Confirm that `X:\Plex` and `X:\Backups\PlexPipeline` are on a disk that
   will not be formatted.
2. Double-click `Backup-Samurai.cmd`.
3. Confirm that the final output reports success.
4. Under `X:\Backups\PlexPipeline`, confirm:

   - A recent `samurai-state-YYYYMMDD-HHMMSS.zip`

The core ZIP is private. It contains application credentials, databases,
Obsidian notes, and the private local CA key. Never upload it to GitHub.

Immich backup and C-drive recovery are maintained separately at
<https://github.com/arbaaz360/immich>. `Backup-Samurai.cmd` locates or
downloads that repository and delegates to its backup script. You can also run
its `Backup-Immich.cmd` directly.

## Rebuild Windows

1. Reinstall Windows without formatting the X: drive.
2. Download this repository from
   <https://github.com/arbaaz360/plexpipeline> and extract it, or clone it.
3. Double-click `Setup-Samurai.cmd`.
4. Approve the administrator prompt.

The setup performs these phases:

1. Installs Git, Plex, SABnzbd, Sonarr, Radarr, Docker Desktop, Tailscale,
   Obsidian, Node.js, and mkcert.
2. Starts Docker Desktop and enables its Kubernetes cluster.
3. Detects a fresh C: drive and restores the newest core state archive.
4. Restores the original private CA or creates one only if no backup exists.
5. Reinstalls the `*.samurai.local` certificate and mDNS scheduled task.
6. Installs the pinned ingress-nginx controller and HTTPS routes.
7. Delegates Immich restoration to the separate Immich repository.
8. Starts the applications and runs direct-port and HTTPS tests.

The script is idempotent. If Docker Desktop or WSL requires a Windows restart,
restart and double-click the same launcher again. Existing application state
causes the destructive restore phase to be skipped.

## Manual actions that cannot be safely automated

- Complete Docker Desktop's first-run screen if it appears.
- Sign in to Tailscale again.
- Sign in to Plex or Overseerr if restored sessions have expired.
- If the original private CA was not present in the backup, install the newly
  exported public CA certificate on the Mac and iPhone.

If the original CA was restored, Apple devices continue trusting renewed
server certificates without another certificate installation.

## Important checks

- In Sonarr and Radarr, SABnzbd must be enabled and NZBDav disabled.
- NewsHosting must use the hostname `news.newshosting.com`, not a pinned IP.
- Verify all four `X:\Plex` root folders.
- SABnzbd category `movies` points to `X:\Plex\MOVIES`.
- SABnzbd category `tv` uses `X:\Plex\TV SERIES`.
- Documentary titles need their documentary root selected manually.

## Validate without making changes

From PowerShell in the repository:

```powershell
.\scripts\setup-samurai.ps1 -ValidateOnly
```

This checks the recovery-kit files, newest core archive, and LAN address
without restoring anything.

## Data not stored in Git

- Application databases and configuration containing credentials
- The private local CA and server private keys
- The local Obsidian service handbook and credential note
- Media files and Docker volumes
- API keys, passwords, tokens, `.env` files, and backup archives

## Related Immich recovery

Immich source, Compose recovery, database/account restoration, and its
generated-data policy live in <https://github.com/arbaaz360/immich>. The
shared `immich.samurai.local` mDNS/HTTPS route remains here because this
repository owns the common friendly-URL gateway for all services. The
top-level launchers invoke Immich's public entry points so backup and rebuild
still require only one double-click.
