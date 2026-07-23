# NZBDav Legacy Experiment

NZBDav streaming is not part of the active production pipeline.

Current state:

- NZBDav client disabled in Sonarr and Radarr.
- SABnzbd is the only active download client.
- `NzbDAV-Rclone` Windows service is stopped.
- NZBDav Compose service requires the `legacy-nzbdav` profile.

Known reliability problems included duplicate queue records, failed imports,
missing NZB data, NNTP connection exhaustion, certificate errors, and Plex
scans blocking on virtual files.

To experiment later:

1. Copy `.env.example` to `.env` and set new credentials.
2. Run `docker compose --profile legacy-nzbdav up -d nzbdav`.
3. Test independently before enabling it in Sonarr or Radarr.
4. Keep SABnzbd as priority 1 until read and seek reliability is verified.
