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

## One-click recovery

Before formatting C:, double-click:

```text
Backup-Samurai.cmd
```

It creates or updates the private recovery data under
`X:\Backups\PlexPipeline`. This includes the core service state, Obsidian
handbook, and private local CA. It does **not** duplicate media.

Immich has its own source and recovery repository:
<https://github.com/arbaaz360/immich>. Its private database backup stays under
`X:\Backups\Immich`, outside both Git repositories. The Samurai launchers
locate or download that repository and invoke its recovery entry points, so
the top-level workflow remains one double-click without mixing the codebases.

After reinstalling Windows:

1. Download or clone this repository.
2. Double-click `Setup-Samurai.cmd`.
3. Approve the Windows administrator prompt.

The setup is idempotent and can be run again after a required Windows/Docker
restart. It installs prerequisites, selects the newest private backup,
restores applications, restores the same HTTPS CA, installs mDNS, enables
Docker Desktop Kubernetes, installs ingress-nginx, and validates the stack.
When an Immich recovery manifest is present, it delegates Immich restoration
to the separate Immich repository before validation.

Some operating-system/account steps can still require interaction: Docker
Desktop's first-run screen, a Windows restart for WSL/Docker, and signing back
in to Tailscale or application accounts.

See [docs/recovery.md](docs/recovery.md) for the complete sequence.

## Back up the current state

Double-click `Backup-Samurai.cmd`.

The default destination is `X:\Backups\PlexPipeline`. The private archive
contains databases, credentials, the private local CA key, and the Obsidian
service handbook. The launcher then delegates Immich's separate private backup
to the Immich repository. Neither private artifact may be committed.

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
