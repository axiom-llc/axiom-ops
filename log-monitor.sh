#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-config.toml}"

mapfile -t CFG < <(
    python - "$CONFIG" <<'PYCFG'
import os
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)["monitoring"]

log_dir = cfg["log_dir"]
if not isinstance(log_dir, str):
    raise TypeError("monitoring.log_dir must be a string")
if log_dir.startswith("~/"):
    log_dir = os.path.expanduser(log_dir)
print(log_dir)

patterns = cfg["alert_patterns"]
if (
    not isinstance(patterns, list)
    or not patterns
    or not all(isinstance(p, str) and p for p in patterns)
):
    raise TypeError(
        "monitoring.alert_patterns must be a non-empty array of strings"
    )

for pattern in patterns:
    print(pattern)
PYCFG
)

(( ${#CFG[@]} >= 2 )) || {
    echo "invalid [monitoring] configuration" >&2
    exit 2
}

LOG_DIR=${CFG[0]}
PATTERNS=("${CFG[@]:1}")
STATE_DIR="${HOME}/.cache/axiom-ops/log-monitor"

mkdir -p "$STATE_DIR"

shopt -s nullglob
FILES=("$LOG_DIR"/*.log)

for FILE in "${FILES[@]}"; do
    STATE="$STATE_DIR/$(basename "$FILE").pos"

    POS=0
    if [[ -f "$STATE" ]]; then
        read -r POS < "$STATE" || POS=0
    fi
    [[ "$POS" =~ ^[0-9]+$ ]] || POS=0

    SIZE=$(wc -c < "$FILE")
    (( POS <= SIZE )) || POS=0

    NEW_LINES=$(tail -c +$((POS + 1)) -- "$FILE")

    for P in "${PATTERNS[@]}"; do
        if grep -Fq -- "$P" <<< "$NEW_LINES"; then
            printf '%s [%s] in %s\n' "$(date)" "$P" "$FILE"
        fi
    done

    printf '%s\n' "$SIZE" > "$STATE.tmp"
    mv -- "$STATE.tmp" "$STATE"
done
