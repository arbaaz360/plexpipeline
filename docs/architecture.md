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
| Docker Compose | Overseerr; Immich is a related, separately managed project |
| Docker Desktop Kubernetes | ingress-nginx and friendly host routing |
| Tailscale | remote access to the Samurai host |

## Friendly URLs

| Service | URL |
|---|---|
| Plex | `https://plex.samurai.local` |
| Overseerr | `https://overseerr.samurai.local` |
| Sonarr | `https://sonarr.samurai.local` |
| Radarr | `https://radarr.samurai.local` |
| SABnzbd | `https://sabnzbd.samurai.local` |
| Immich | `https://immich.samurai.local` |

The ingress template derives the current LAN IPv4 address when applied. HTTPS
uses the `samurai-local-tls` Kubernetes secret and redirects HTTP requests to
HTTPS. Client devices must trust the InstantPlex local root CA.

The gateway owns all six friendly routes, including Immich's route. Immich's
Compose configuration and private database recovery are maintained in
<https://github.com/arbaaz360/immich>.
