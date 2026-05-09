#!/usr/bin/env bash
set -euo pipefail

NAVIDROME_ROOT="${NAVIDROME_ROOT:-/opt/navidrome}"
MUSIC_DIR="${NAVIDROME_MUSIC_DIR:-${NAVIDROME_ROOT}/music}"
BACKUP_DIR="${NAVIDROME_BACKUP_DIR:-${NAVIDROME_ROOT}/backups}"
DIR_MODE="${NAVIDROME_DIR_MODE:-0755}"
OWNER="${NAVIDROME_OWNER:-}"

require_root_for_opt() {
  if [[ "${NAVIDROME_ROOT}" == /opt/* && "${EUID}" -ne 0 ]]; then
    echo "This script needs root privileges to create directories under /opt." >&2
    echo "Run with sudo, or set NAVIDROME_ROOT to a writable path." >&2
    exit 1
  fi
}

create_dir() {
  local path="$1"

  install -d -m "${DIR_MODE}" "${path}"

  if [[ -n "${OWNER}" ]]; then
    chown "${OWNER}" "${path}"
  fi
}

main() {
  require_root_for_opt

  create_dir "${NAVIDROME_ROOT}"
  create_dir "${MUSIC_DIR}"
  create_dir "${BACKUP_DIR}"

  echo "Prepared Navidrome directories:"
  echo "  root:    ${NAVIDROME_ROOT}"
  echo "  music:   ${MUSIC_DIR}"
  echo "  backups: ${BACKUP_DIR}"
}

main "$@"
