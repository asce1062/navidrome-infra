# Deployment Guide

This project is designed for a Coolify Docker Compose deployment from Git.

## Prerequisites

- A Hetzner server running Coolify.
- Netlify DNS has an `A` or `CNAME` record for `music.alexmbugua.me` pointing
  to the Coolify server.
- Docker is available on the server.
- `/opt/navidrome/music` exists on the server.

Prepare the server directories:

```bash
sudo ./scripts/prepare-server.sh
```

## Coolify Setup

1. In Coolify, create a new resource from this Git repository.
2. Select Docker Compose.
3. Use `docker-compose.yml` at the repository root.
4. Configure the domain as `music.alexmbugua.me`.
5. Configure the app/service port as `4533`.
6. Deploy.

The Compose file exposes port `4533` internally and does not publish a host
port. Coolify should own the public reverse proxy and TLS configuration.

## Environment Variables

The defaults in `docker-compose.yml` are intentionally safe and boring. Use
Coolify environment variables to override them when needed:

- `NAVIDROME_IMAGE`
- `NAVIDROME_MUSIC_DIR`
- `ND_SCANSCHEDULE`
- `ND_LOGLEVEL`
- `ND_SESSIONTIMEOUT`
- `ND_ENABLETRANSCODINGCONFIG`
- `ND_BASEURL`
- `ND_UIWELCOMEMESSAGE`

Do not commit `.env` files. Use `.env.example` as documentation only.

## First Launch

After the first successful deployment, open:

```text
https://music.alexmbugua.me
```

Navidrome prompts for the first admin user in the web UI. Do not store that
credential in this repository.

## Redeploys

Redeploys are safe for application data because `/data` is backed by the named
Docker volume `navidrome_data`. Music is read from `/opt/navidrome/music` and
is not stored inside the container.
