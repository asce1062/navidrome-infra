#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Error: this script must be run with Bash." >&2
  echo "Run it as: ./scripts/upload-music.sh" >&2
  exit 1
fi

if [[ -o posix ]]; then
  echo "Error: this script is running in POSIX sh mode, but it requires Bash." >&2
  echo "Run it as: ./scripts/upload-music.sh" >&2
  exit 1
fi

set -euo pipefail

SOURCE=""
TARGET=""
DRY_RUN=0
DELETE=0
CHECKSUM=0
EXCLUDES=()

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/upload-music.sh --source <local-path> --target <user@host:/remote/path/> [options]

Options:
  --source <local-path>   Local file or directory to upload.
  --target <target>       rsync SSH target, for example:
                          musicadmin@example.com:/opt/navidrome/music/
  --dry-run               Show what would change without copying files.
  --delete                Delete remote files that are absent locally.
  --checksum              Compare files by checksum instead of size/time.
  --exclude <pattern>     Exclude a file pattern. Can be repeated.
  --help                  Show this help message.

Trailing slash behavior:
  --source ./Music/ copies the contents of Music into the target directory.
  --source ./Music copies the Music directory itself into the target directory.

The script only uses --delete when you explicitly pass --delete.
USAGE
}

fail() {
  echo "Error: $*" >&2
  echo >&2
  usage >&2
  exit 1
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --source)
        [[ "$#" -ge 2 ]] || fail "--source requires a value"
        SOURCE="$2"
        shift 2
        ;;
      --target)
        [[ "$#" -ge 2 ]] || fail "--target requires a value"
        TARGET="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --delete)
        DELETE=1
        shift
        ;;
      --checksum)
        CHECKSUM=1
        shift
        ;;
      --exclude)
        [[ "$#" -ge 2 ]] || fail "--exclude requires a value"
        EXCLUDES+=("$2")
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
  done
}

validate_args() {
  [[ -n "${SOURCE}" ]] || fail "--source is required"
  [[ -n "${TARGET}" ]] || fail "--target is required"
  [[ -e "${SOURCE}" ]] || fail "source path does not exist: ${SOURCE}"

  if [[ "${TARGET}" != *@*:* ]]; then
    fail "--target must look like user@host:/remote/path/"
  fi
}

print_command() {
  local item

  printf 'Running:'
  for item in "$@"; do
    printf ' %q' "${item}"
  done
  printf '\n'
}

print_summary() {
  local tmp_output="$1"
  local files_total files_transferred

  files_total=$(grep -E "^Number of files:" "${tmp_output}" | grep -oE "[0-9]+" | head -1 || true)
  files_transferred=$(grep -E "^Number of (regular )?files transferred:" "${tmp_output}" | grep -oE "[0-9]+" | head -1 || true)
  files_total="${files_total:-0}"
  files_transferred="${files_transferred:-0}"

  echo ""
  echo "─────────────────────────────────────"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "  Mode             : dry run (no files changed)"
    echo "  Files considered : ${files_total}"
    echo "  Would transfer   : ${files_transferred}"
  else
    echo "  Files considered : ${files_total}"
    echo "  Files uploaded   : ${files_transferred}"
  fi
  echo "─────────────────────────────────────"
}

main() {
  local rsync_cmd
  local exclude_pattern
  local tmp_output

  parse_args "$@"
  require_command rsync
  validate_args

  rsync_cmd=(rsync -avz --progress --stats)

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    rsync_cmd+=(--dry-run)
  fi

  if [[ "${DELETE}" -eq 1 ]]; then
    rsync_cmd+=(--delete)
  fi

  if [[ "${CHECKSUM}" -eq 1 ]]; then
    rsync_cmd+=(--checksum)
  fi

  if [[ "${#EXCLUDES[@]}" -gt 0 ]]; then
    for exclude_pattern in "${EXCLUDES[@]}"; do
      rsync_cmd+=(--exclude "${exclude_pattern}")
    done
  fi

  rsync_cmd+=("${SOURCE}" "${TARGET}")

  tmp_output=$(mktemp)
  trap "rm -f '${tmp_output}'" EXIT

  print_command "${rsync_cmd[@]}"
  "${rsync_cmd[@]}" | tee "${tmp_output}"

  print_summary "${tmp_output}"
}

main "$@"
