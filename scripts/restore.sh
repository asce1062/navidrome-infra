#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="${NAVIDROME_DATA_VOLUME:-navidrome_data}"
RESTORE_CONFIRM="${RESTORE_CONFIRM:-}"
ARCHIVE_PATH="${1:-}"

usage() {
  echo "Usage: RESTORE_CONFIRM=yes $0 /path/to/navidrome-data-YYYYmmdd-HHMMSS.tar.gz" >&2
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

validate_input() {
  if [[ -z "${ARCHIVE_PATH}" ]]; then
    usage
    exit 1
  fi

  if [[ ! -f "${ARCHIVE_PATH}" ]]; then
    echo "Backup archive not found: ${ARCHIVE_PATH}" >&2
    exit 1
  fi

  if [[ "${RESTORE_CONFIRM}" != "yes" ]]; then
    echo "Refusing to restore without RESTORE_CONFIRM=yes." >&2
    echo "Stop the Coolify Navidrome deployment before restoring." >&2
    usage
    exit 1
  fi
}

restore_data_volume() {
  local absolute_archive

  absolute_archive="$(cd "$(dirname "${ARCHIVE_PATH}")" && pwd)/$(basename "${ARCHIVE_PATH}")"

  docker volume create "${VOLUME_NAME}" >/dev/null
  docker run --rm \
    -v "${VOLUME_NAME}:/data" \
    -v "${absolute_archive}:/restore/navidrome-data.tar.gz:ro" \
    alpine:3.20 \
    sh -c "rm -rf /data/* /data/.[!.]* /data/..?* && tar -xzf /restore/navidrome-data.tar.gz -C /data"
}

main() {
  require_command docker
  validate_input
  restore_data_volume

  echo "Restored ${ARCHIVE_PATH} into Docker volume ${VOLUME_NAME}."
  echo "Start the Coolify Navidrome deployment after verifying the restore."
}

main "$@"
