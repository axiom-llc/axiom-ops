#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-config.toml}"

mapfile -t CFG < <(
    python - "$CONFIG" <<'PYCFG'
import os
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)["git_sync"]

for key in ("log_file", "repo_directory", "git_name", "git_email", "commit_message"):
    value = cfg[key]
    if not isinstance(value, str):
        raise TypeError(f"git_sync.{key} must be a string")
    if key in {"log_file", "repo_directory"} and value.startswith("~/"):
        value = os.path.expanduser(value)
    print(value)

force = cfg["force_with_lease"]
if not isinstance(force, bool):
    raise TypeError("git_sync.force_with_lease must be boolean")
print("1" if force else "0")
PYCFG
)

(( ${#CFG[@]} == 6 )) || {
    echo "invalid [git_sync] configuration" >&2
    exit 2
}

LOG=${CFG[0]}
REPO=${CFG[1]}
GIT_USER=${CFG[2]}
GIT_EMAIL=${CFG[3]}
MSG=${CFG[4]}
FORCE_WITH_LEASE=${CFG[5]}

mkdir -p "$(dirname "$LOG")"
printf '%s Starting sync...\n' "$(date +'%Y-%m-%d %H:%M:%S')" >> "$LOG"

cd "$REPO"
git fetch origin

if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git -c "user.name=$GIT_USER" \
        -c "user.email=$GIT_EMAIL" \
        commit -m "$MSG"
fi

if (( FORCE_WITH_LEASE )); then
    git push --force-with-lease origin HEAD
else
    git push origin HEAD
fi

printf '%s Sync completed\n' "$(date +'%Y-%m-%d %H:%M:%S')" >> "$LOG"
