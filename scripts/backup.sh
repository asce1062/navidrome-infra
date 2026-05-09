#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="${NAVIDROME_DATA_VOLUME:-navidrome_data}"
BACKUP_DIR="${NAVIDROME_BACKUP_DIR:-/opt/navidrome/backups}"
MUSIC_DIR="${NAVIDROME_MUSIC_DIR:-/opt/navidrome/music}"
INCLUDE_MUSIC="${INCLUDE_MUSIC:-0}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
DATA_ARCHIVE="${BACKUP_DIR}/navidrome-data-${TIMESTAMP}.tar.gz"
MUSIC_ARCHIVE="${BACKUP_DIR}/navidrome-music-${TIMESTAMP}.tar.gz"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

ensure_volume_exists() {
  if ! docker volume inspect "${VOLUME_NAME}" >/dev/null 2>&1; then
    echo "Docker volume does not exist: ${VOLUME_NAME}" >&2
    echo "Deploy Navidrome once before running a data backup." >&2
    exit 1
  fi
}

backup_data_volume() {
  docker run --rm \
    -v "${VOLUME_NAME}:/data:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine:3.20 \
    sh -c "cd /data && tar -czf /backup/$(basename "${DATA_ARCHIVE}") ."
}

backup_music_dir() {
  if [[ ! -d "${MUSIC_DIR}" ]]; then
    echo "Music directory does not exist: ${MUSIC_DIR}" >&2
    exit 1
  fi

  tar -czf "${MUSIC_ARCHIVE}" -C "${MUSIC_DIR}" .
}

main() {
  require_command docker
  require_command tar
  ensure_volume_exists

  umask 077
  install -d -m 0700 "${BACKUP_DIR}"

  backup_data_volume
  echo "Created data backup: ${DATA_ARCHIVE}"

  if [[ "${INCLUDE_MUSIC}" == "1" ]]; then
    backup_music_dir
    echo "Created music backup: ${MUSIC_ARCHIVE}"
  else
    echo "Skipped music backup. Set INCLUDE_MUSIC=1 to archive ${MUSIC_DIR}."
  fi
}

main "$@"
