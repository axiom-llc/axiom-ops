#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-config.toml}"

mapfile -t CFG < <(
    python - "$CONFIG" <<'PYCFG'
import os
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)["backup"]

for key in ("source_dir", "backup_dir", "log_file"):
    value = cfg[key]
    if not isinstance(value, str):
        raise TypeError(f"backup.{key} must be a string")
    if value.startswith("~/"):
        value = os.path.expanduser(value)
    print(value)

recipient = cfg["gpg_recipient"]
if not isinstance(recipient, str) or not recipient:
    raise TypeError("backup.gpg_recipient must be a non-empty string")
print(recipient)

retention = cfg["retention_days"]
if not isinstance(retention, int) or retention < 0:
    raise TypeError("backup.retention_days must be a non-negative integer")
print(retention)
PYCFG
)

(( ${#CFG[@]} == 5 )) || {
    echo "invalid [backup] configuration" >&2
    exit 2
}

SRC=${CFG[0]}
DST=${CFG[1]}
LOG=${CFG[2]}
RECIPIENT=${CFG[3]}
RETENTION_DAYS=${CFG[4]}

[[ -d "$SRC" ]] || {
    echo "source directory does not exist: $SRC" >&2
    exit 2
}

mkdir -p "$DST" "$(dirname "$LOG")"

FILE="$DST/backup_$(date -u +%Y%m%dT%H%M%SZ).tar.gz.gpg"
[[ ! -e "$FILE" ]] || {
    echo "backup already exists: $FILE" >&2
    exit 2
}

TMPFILE="$FILE.tmp.$$"
trap 'rm -f -- "$TMPFILE"' EXIT

tar -C "$SRC" -czf - . |
    gpg --batch --yes --encrypt --recipient "$RECIPIENT" > "$TMPFILE"

mv -- "$TMPFILE" "$FILE"
trap - EXIT

find "$DST" \
    -type f \
    -name 'backup_*.tar.gz.gpg' \
    -mtime +"$RETENTION_DAYS" \
    -delete

printf '%s Backup created: %s\n' \
    "$(date +'%Y-%m-%d %H:%M:%S')" "$FILE" >> "$LOG"
