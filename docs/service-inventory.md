# Service Inventory

## Media services

| Service | Runtime | Port | Configuration/data |
|---|---|---:|---|
| Plex | Windows | 32400 | `%LOCALAPPDATA%\Plex Media Server` and HKCU registry |
| Sonarr | Windows startup | 8989 | `C:\ProgramData\Sonarr` |
| Radarr | Windows service | 7878 | `C:\ProgramData\Radarr` |
| SABnzbd | Windows | 8080 | `%LOCALAPPDATA%\sabnzbd` |
| Overseerr | Docker | 5055 | `data\overseerr` in this project |
| NZBDav | Docker legacy profile | 3000 localhost | Docker volume and cache |

## Other active Docker projects

| Project | Compose file | Exposed ports |
|---|---|---|
| Immich | `X:\Immich\docker-compose.yml` | 2283, 2298, 2299, 3111 |
| Movie Summarizer | `C:\Users\ASUS\Downloads\AI\MovieSummarizer\docker-compose.yml` | 8001, 8002, 8010 |
| Imginn Downloader | `C:\Users\ASUS\Downloads\AiProjects\imginn downloader\compose.yml` | 3031 |
| URLBird audio identifier | `C:\Users\ASUS\Downloads\URLBIRD\microservices\audio-identifier\docker-compose.yml` | 8000 |
| FaceSearch | `C:\Users\ASUS\Downloads\Facial_Recognition\FaceSearch\docker-compose.yml` | 6333 |
| English MongoDB | standalone Docker container | 27018 |

Docker Desktop also runs Kubernetes control-plane containers. Manage those
through Kubernetes rather than directly.

## Startup

- Radarr: automatic Windows service.
- Sonarr: per-user Startup shortcut.
- Plex and SABnzbd: per-user applications.
- Docker services: Compose restart policy `unless-stopped` where configured.
- Legacy `NzbDAV-Rclone` service: present but stopped.
