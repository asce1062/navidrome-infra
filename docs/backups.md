# Backup and Restore Guide

Navidrome has two important storage locations:

- `navidrome_data`: Docker named volume for the database, settings, cache, and
  application metadata.
- `/opt/navidrome/music`: host directory containing the music catalog.

## Data Backups

Create an application data backup:

```bash
sudo ./scripts/backup.sh
```

By default this writes an archive like:

```text
/opt/navidrome/backups/navidrome-data-YYYYmmdd-HHMMSS.tar.gz
```

The backup script uses a temporary Alpine container to read the Docker volume
without needing to know Docker's internal volume path.

## Music Backups

Music files are not included by default. They are usually large and often have
their own source of truth.

To create a separate music archive:

```bash
sudo INCLUDE_MUSIC=1 ./scripts/backup.sh
```

For large libraries, prefer a dedicated backup tool or remote sync target over
local tar archives.

## Restore

Restoring replaces the contents of `navidrome_data`. Stop the Coolify
deployment before restoring.

```bash
sudo RESTORE_CONFIRM=yes ./scripts/restore.sh /opt/navidrome/backups/navidrome-data-YYYYmmdd-HHMMSS.tar.gz
```

After the restore completes, start the Coolify deployment and check the web UI.

## Backup Handling

- Keep backup archives out of Git.
- Copy important backups off the server.
- Treat backups as sensitive because they can include user and library metadata.
- Test restore steps before relying on backups as your only recovery path.
