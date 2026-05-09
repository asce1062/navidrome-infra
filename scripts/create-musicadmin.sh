#!/usr/bin/env bash
set -euo pipefail

UPLOAD_USER="${NAVIDROME_UPLOAD_USER:-musicadmin}"
NAVIDROME_ROOT="${NAVIDROME_ROOT:-/opt/navidrome}"
MUSIC_DIR="${NAVIDROME_MUSIC_DIR:-${NAVIDROME_ROOT}/music}"
UPLOAD_SHELL="${NAVIDROME_UPLOAD_SHELL:-/bin/bash}"
UPLOAD_GROUP="${NAVIDROME_UPLOAD_GROUP:-${UPLOAD_USER}}"
AUTHORIZED_KEY="${NAVIDROME_AUTHORIZED_KEY:-}"
AUTHORIZED_KEY_FILE="${NAVIDROME_AUTHORIZED_KEY_FILE:-}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root because it creates users and changes ownership." >&2
    echo "Run with sudo." >&2
    exit 1
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

validate_shell() {
  if [[ ! -x "${UPLOAD_SHELL}" ]]; then
    echo "Upload shell is not executable: ${UPLOAD_SHELL}" >&2
    exit 1
  fi
}

ensure_group() {
  if ! getent group "${UPLOAD_GROUP}" >/dev/null 2>&1; then
    groupadd "${UPLOAD_GROUP}"
  fi
}

ensure_user() {
  if ! getent passwd "${UPLOAD_USER}" >/dev/null 2>&1; then
    # The upload user is intentionally a normal account without sudo access.
    # A real shell keeps rsync and SFTP compatibility straightforward.
    useradd --create-home --shell "${UPLOAD_SHELL}" --gid "${UPLOAD_GROUP}" "${UPLOAD_USER}"
  else
    usermod --shell "${UPLOAD_SHELL}" "${UPLOAD_USER}"
  fi

  usermod --append --groups "${UPLOAD_GROUP}" "${UPLOAD_USER}"
}

home_dir_for_user() {
  local home_dir

  home_dir="$(getent passwd "${UPLOAD_USER}" | cut -d: -f6)"
  if [[ -z "${home_dir}" || ! -d "${home_dir}" ]]; then
    echo "Could not determine home directory for ${UPLOAD_USER}." >&2
    exit 1
  fi

  printf '%s\n' "${home_dir}"
}

ensure_music_directory() {
  install -d -m 2775 "${MUSIC_DIR}"

  # Setgid keeps uploaded files group-owned by the upload group. The directory
  # is writable by owner/group only, never world-writable.
  chown "${UPLOAD_USER}:${UPLOAD_GROUP}" "${MUSIC_DIR}"
  chmod 2775 "${MUSIC_DIR}"
}

append_authorized_key() {
  local key="$1"
  local home_dir="$2"
  local ssh_dir="${home_dir}/.ssh"
  local authorized_keys="${ssh_dir}/authorized_keys"

  if [[ -z "${key}" ]]; then
    return
  fi

  install -d -m 700 -o "${UPLOAD_USER}" -g "${UPLOAD_GROUP}" "${ssh_dir}"
  touch "${authorized_keys}"
  chown "${UPLOAD_USER}:${UPLOAD_GROUP}" "${authorized_keys}"
  chmod 600 "${authorized_keys}"

  if ! grep -Fx -- "${key}" "${authorized_keys}" >/dev/null 2>&1; then
    printf '%s\n' "${key}" >> "${authorized_keys}"
  fi

  chown "${UPLOAD_USER}:${UPLOAD_GROUP}" "${authorized_keys}"
  chmod 600 "${authorized_keys}"
}

install_authorized_keys() {
  local home_dir="$1"
  local key_from_file

  if [[ -n "${AUTHORIZED_KEY_FILE}" ]]; then
    if [[ ! -f "${AUTHORIZED_KEY_FILE}" ]]; then
      echo "Authorized key file not found: ${AUTHORIZED_KEY_FILE}" >&2
      exit 1
    fi

    key_from_file="$(tr -d '\r\n' < "${AUTHORIZED_KEY_FILE}")"
    if [[ -z "${key_from_file}" ]]; then
      echo "Authorized key file is empty: ${AUTHORIZED_KEY_FILE}" >&2
      exit 1
    fi

    append_authorized_key "${key_from_file}" "${home_dir}"
  fi

  if [[ -n "${AUTHORIZED_KEY}" ]]; then
    append_authorized_key "${AUTHORIZED_KEY}" "${home_dir}"
  fi
}

main() {
  local home_dir

  require_root
  require_command getent
  require_command cut
  validate_shell
  ensure_group
  ensure_user
  ensure_music_directory

  home_dir="$(home_dir_for_user)"
  install_authorized_keys "${home_dir}"

  echo "Navidrome upload user is ready:"
  echo "  upload user:     ${UPLOAD_USER}"
  echo "  upload group:    ${UPLOAD_GROUP}"
  echo "  music directory: ${MUSIC_DIR}"
  echo
  echo "Example upload target:"
  echo "  ${UPLOAD_USER}@example.com:${MUSIC_DIR}/"
}

main "$@"
