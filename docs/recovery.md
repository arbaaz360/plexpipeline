# Recovery After Formatting C:

## Before formatting

1. Run elevated:

   ```powershell
   .\scripts\backup-state.ps1
   ```

2. Confirm a recent archive exists under `X:\Backups\PlexPipeline`.
3. Preserve the Git repository URL and local Obsidian vault.
4. Confirm `X:\Plex` and `X:\Immich` are not on the disk being formatted.

## Rebuild Windows

1. Install Git and clone this repository.
2. Open elevated PowerShell in the repository.
3. Run `.\scripts\install-prerequisites.ps1`.
4. Start Docker Desktop and enable Kubernetes if friendly ingress names are
   required.
5. Restore the latest private archive:

   ```powershell
   .\scripts\restore-state.ps1 `
     -Archive 'X:\Backups\PlexPipeline\samurai-state-YYYYMMDD-HHMMSS.zip' `
     -ConfirmRestore
   ```

6. Run `.\scripts\apply-ingress.ps1`.
7. Sign in to Plex, Overseerr, Tailscale, and Immich if needed.
8. Run `.\scripts\test-stack.ps1`.

## Important checks

- In Sonarr and Radarr, SABnzbd must be enabled and NZBDav disabled.
- Verify all four `X:\Plex` root folders.
- SABnzbd category `movies` points to `X:\Plex\MOVIES`.
- SABnzbd category `tv` uses the global completed folder
  `X:\Plex\TV SERIES`.
- Documentary titles need their documentary root selected manually.
- Do not restore secrets from GitHub. They exist only in the private state
  archive and local credential store.

## Data not stored in Git

- Application databases and configuration containing credentials
- The local Obsidian service handbook and credential note
- Immich database and uploads
- Media files and Docker volumes
- API keys, passwords, tokens, `.env` files, and backups
