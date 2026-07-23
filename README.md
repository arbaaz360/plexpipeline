# Plex Pipeline

Reproducible configuration for the working Samurai media stack. The reliable
production path is download-first:

```text
Overseerr -> Sonarr/Radarr -> SABnzbd -> X:\Plex -> Plex
```

Plex, Sonarr, Radarr, and SABnzbd run natively on Windows. Overseerr runs in
Docker. Kubernetes ingress exposes friendly `*.samurai.local` names.

NZBDav is retained only as an opt-in legacy experiment. It is disabled in
Sonarr and Radarr and is not started by the default Compose command.

## Recovery

1. Preserve `X:\Backups\PlexPipeline` before formatting Windows.
2. Clone this repository.
3. Run `scripts\install-prerequisites.ps1` in elevated PowerShell.
4. Run `scripts\restore-state.ps1 -Archive <backup.zip> -ConfirmRestore`.
5. Enable Docker Desktop Kubernetes and run `scripts\apply-ingress.ps1`.
6. Run `scripts\test-stack.ps1`.

See [docs/recovery.md](docs/recovery.md) for the complete sequence.

## Back up the current state

Run in elevated PowerShell:

```powershell
.\scripts\backup-state.ps1
```

The default destination is `X:\Backups\PlexPipeline`. The private archive
contains databases, credentials, and the Obsidian service handbook. It must
never be committed.

## Repository safety

- Live credentials are never stored here.
- `.env`, application data, databases, archives, and secret files are ignored.
- Keep credentials in a password manager or the local Obsidian `Secrets` note.
- Treat any credential previously committed publicly as exposed and rotate it.

## Documentation

- [Architecture](docs/architecture.md)
- [Media paths](docs/media-paths.md)
- [Recovery](docs/recovery.md)
- [Service inventory](docs/service-inventory.md)
- [NZBDav legacy notes](legacy/nzbdav/README.md)
