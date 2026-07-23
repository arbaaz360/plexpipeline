# Architecture

## Active media flow

```text
Overseerr :5055
  |-- movie request --> Radarr :7878
  |-- series request -> Sonarr :8989
                           |
                           v
                     SABnzbd :8080
                           |
              +------------+-------------+
              |                          |
       X:\Plex\MOVIES             X:\Plex\TV SERIES
       X:\Plex\Documentary Movies X:\Plex\Documentary Series
              |                          |
              +------------+-------------+
                           v
                        Plex :32400
```

SABnzbd is the only enabled download client in Sonarr and Radarr. Completed
Sonarr jobs remain visible in SABnzbd history.

## Runtime split

| Runtime | Services |
|---|---|
| Windows | Plex, Sonarr, Radarr, SABnzbd |
| Docker Compose | Overseerr, Immich, supporting application projects |
| Docker Desktop Kubernetes | ingress-nginx and friendly host routing |
| Tailscale | remote access to the Samurai host |

## Friendly URLs

| Service | URL |
|---|---|
| Plex | `http://plex.samurai.local` |
| Overseerr | `http://overseerr.samurai.local` |
| Sonarr | `http://sonarr.samurai.local` |
| Radarr | `http://radarr.samurai.local` |
| SABnzbd | `http://sabnzbd.samurai.local` |
| Immich | `http://immich.samurai.local` |

The ingress template derives the current LAN IPv4 address when applied.
