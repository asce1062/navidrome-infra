# Music Upload Guide

Navidrome reads music from `/opt/navidrome/music` on the server. The container
mounts that directory read-only at `/music`, so uploads happen on the host
before Navidrome scans the library.

## Secure Upload Flow

Use a dedicated upload account instead of uploading as root:

```text
local machine -> rsync/SFTP -> musicadmin user -> /opt/navidrome/music -> Navidrome scan
```

The `musicadmin` user owns the music directory with a matching upload group.
The directory mode is `2775`, which keeps new files group-owned by the upload
group and avoids world-writable permissions.

## Create the Upload User

On the server, run:

```bash
sudo ./scripts/create-musicadmin.sh
```

This creates:

- upload user: `musicadmin`
- upload group: `musicadmin`
- music directory: `/opt/navidrome/music`

It does not grant sudo permissions.

## Install an SSH Public Key

To install a public key from a file:

```bash
NAVIDROME_AUTHORIZED_KEY_FILE=/path/to/key.pub sudo -E ./scripts/create-musicadmin.sh
```

To install a public key directly from an environment variable:

```bash
NAVIDROME_AUTHORIZED_KEY='<public-key-string>' sudo -E ./scripts/create-musicadmin.sh
```

Existing `authorized_keys` content is preserved. The script appends the key only
if it is not already present and sets secure SSH permissions.

## Customize the Account

All values are optional:

```bash
NAVIDROME_UPLOAD_USER=musicupload \
  NAVIDROME_UPLOAD_GROUP=musicupload \
  NAVIDROME_ROOT=/opt/navidrome \
  NAVIDROME_MUSIC_DIR=/opt/navidrome/music \
  NAVIDROME_UPLOAD_SHELL=/bin/bash \
  sudo -E ./scripts/create-musicadmin.sh
```

## Upload from a Local Machine

The upload helper wraps `rsync` over SSH. It does not know any real server
details, so pass the full target explicitly.

Dry run:

```bash
./scripts/upload-music.sh \
  --source ./Music/ \
  --target musicadmin@example.com:/opt/navidrome/music/ \
  --dry-run
```

Normal upload:

```bash
./scripts/upload-music.sh \
  --source ./Music/ \
  --target musicadmin@example.com:/opt/navidrome/music/
```

Mirror sync with remote deletion:

```bash
./scripts/upload-music.sh \
  --source ./Music/ \
  --target musicadmin@example.com:/opt/navidrome/music/ \
  --delete
```

Use `--delete` carefully. It removes remote files from the target when they are
not present in the source.

## Excludes and Checksums

Exclude temporary files:

```bash
./scripts/upload-music.sh \
  --source ./Music/ \
  --target musicadmin@example.com:/opt/navidrome/music/ \
  --exclude '.DS_Store' \
  --exclude '*.tmp'
```

Use checksum comparison when timestamps are unreliable:

```bash
./scripts/upload-music.sh \
  --source ./Music/ \
  --target musicadmin@example.com:/opt/navidrome/music/ \
  --checksum
```

## Trailing Slashes

Rsync treats trailing slashes as meaningful:

- `--source ./Music/` copies the contents of `Music` into the target.
- `--source ./Music` copies the `Music` directory itself into the target.

For a Navidrome library, `./Music/` is usually the intended form.

## Navidrome Scans

Navidrome scans hourly by default through `ND_SCANSCHEDULE=1h`. You can also
trigger a manual scan from the Navidrome web UI after uploading new files.
