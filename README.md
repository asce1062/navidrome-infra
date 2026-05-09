# navidrome-infra

Git-backed Coolify deployment for Navidrome at `music.alexmbugua.me`.

## Architecture

This repository deploys one Navidrome container from `docker-compose.yml`.
Coolify builds and runs the Compose project from Git, provides the public
HTTP routing, and should attach the domain `music.alexmbugua.me` to the
Navidrome service on internal port `4533`.

Storage is intentionally outside the container:

- `/opt/navidrome/music` on the server is mounted read-only at `/music`.
- `navidrome_data` is a Docker named volume mounted at `/data`.
- Music files, backups, `.env` files, tokens, and passwords are not stored in Git.

DNS is managed in Netlify. This repo assumes `music.alexmbugua.me` already
points to the Hetzner server public IP where Coolify is running.

## Required Server Directories

Run the preparation script on the server before the first deployment:

```bash
sudo ./scripts/prepare-server.sh
```

It creates:

- `/opt/navidrome/music` for the music catalog
- `/opt/navidrome/backups` for local backup archives

The script is idempotent and safe to re-run. It does not download music or
write application data.

## Coolify Deployment

1. Create a new Coolify resource from this Git repository.
2. Choose Docker Compose as the deployment type.
3. Use `docker-compose.yml` from the repository root.
4. Set the public domain to `music.alexmbugua.me`.
5. Route traffic to service `navidrome` on internal port `4533`.
6. Add environment variables only if you need to override `.env.example`.
7. Deploy.
8. Open `https://music.alexmbugua.me` and create the first admin user in the
   Navidrome web UI.

Do not configure passwords or admin credentials in this repo. Navidrome creates
the first admin user through the web UI after first launch.

## Storage Layout

```text
/opt/navidrome/
├── music/      # host music catalog, mounted read-only into the container
└── backups/    # local backup archives created by scripts/backup.sh

Docker volume:
navidrome_data  # Navidrome database, settings, cache, and application data
```

## Adding Music

Copy music files to `/opt/navidrome/music` on the server. Keep a normal artist
and album folder layout where practical.

Example:

```bash
sudo rsync -av ./Music/ /opt/navidrome/music/
```

Navidrome scans the library every hour by default. You can change this with
`ND_SCANSCHEDULE`.

## Backups

Back up the Navidrome data volume with:

```bash
sudo ./scripts/backup.sh
```

This archives the `navidrome_data` Docker volume into
`/opt/navidrome/backups`. Music files are not included by default because they
can be large and should usually have their own backup plan.

To include the music directory in a separate archive:

```bash
sudo INCLUDE_MUSIC=1 ./scripts/backup.sh
```

Restoring application data is destructive. Stop the Coolify deployment first,
then run:

```bash
sudo RESTORE_CONFIRM=yes ./scripts/restore.sh /opt/navidrome/backups/navidrome-data-YYYYmmdd-HHMMSS.tar.gz
```

More detail is in [docs/backups.md](docs/backups.md).

## Security Notes

- Keep Navidrome public access controlled with user accounts.
- If guest access is needed, create a restricted guest user instead of sharing
  an admin account.
- Do not commit `.env`, credentials, API tokens, music files, or backups.
- Keep the server and Coolify updated.

## Documentation

- [Deployment guide](docs/deployment.md)
- [Backup and restore guide](docs/backups.md)
