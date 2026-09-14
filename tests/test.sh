#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for script in backup.sh sync-github.sh log-monitor.sh; do
    bash -n "$ROOT/$script"
done

# backup.sh
mkdir -p "$TMP/bin" "$TMP/home dir/source data" "$TMP/backups"

cat > "$TMP/bin/tar" <<'SH'
#!/usr/bin/env bash
printf 'archive-data'
SH

cat > "$TMP/bin/gpg" <<'SH'
#!/usr/bin/env bash
cat
SH

chmod +x "$TMP/bin/tar" "$TMP/bin/gpg"

cat > "$TMP/backup.toml" <<'EOF2'
[backup]
source_dir = "~/source data"
backup_dir = "~/backups"
log_file = "~/logs/backup.log"
gpg_recipient = "test@example.com"
retention_days = 7
EOF2

mkdir -p "$TMP/home dir/backups"
touch -d '10 days ago' \
    "$TMP/home dir/backups/backup_old.tar.gz.gpg" \
    "$TMP/home dir/backups/keep.txt"

HOME="$TMP/home dir" PATH="$TMP/bin:$PATH" \
    bash "$ROOT/backup.sh" "$TMP/backup.toml"

test -f "$TMP/home dir/logs/backup.log"
test ! -e "$TMP/home dir/backups/backup_old.tar.gz.gpg"
test -e "$TMP/home dir/backups/keep.txt"
test "$(find "$TMP/home dir/backups" -name 'backup_*.tar.gz.gpg' | wc -l)" -eq 1

# sync-github.sh
mkdir -p "$TMP/home dir/repo with space"

cat > "$TMP/bin/git" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GIT_LOG"
if [[ "${1:-}" == status && "${2:-}" == --porcelain ]]; then
    printf ' M tracked\n'
fi
SH
chmod +x "$TMP/bin/git"

cat > "$TMP/sync.toml" <<'EOF2'
[git_sync]
repo_directory = "~/repo with space"
log_file = "~/logs/git sync.log"
git_email = "automation@example.com"
git_name = "Automation Bot"
commit_message = "Automated sync"
force_with_lease = true
EOF2

GIT_LOG="$TMP/git.calls" \
HOME="$TMP/home dir" \
PATH="$TMP/bin:$PATH" \
    bash "$ROOT/sync-github.sh" "$TMP/sync.toml"

grep -F 'fetch origin' "$TMP/git.calls" >/dev/null
grep -F 'user.name=Automation Bot' "$TMP/git.calls" >/dev/null
grep -F 'commit -m Automated sync' "$TMP/git.calls" >/dev/null
grep -F 'push --force-with-lease origin HEAD' "$TMP/git.calls" >/dev/null
test -f "$TMP/home dir/logs/git sync.log"

# log-monitor.sh
mkdir -p "$TMP/home dir/log dir"

cat > "$TMP/monitor.toml" <<'EOF2'
[monitoring]
log_dir = "~/log dir"
alert_patterns = ["PANIC", "DATABASE DOWN"]
EOF2

printf '%s\n' \
    'INFO startup' \
    'ERROR ignored' \
    'PANIC first event' \
    > "$TMP/home dir/log dir/app one.log"

HOME="$TMP/home dir" \
    bash "$ROOT/log-monitor.sh" "$TMP/monitor.toml" > "$TMP/monitor1.out"

grep -F '[PANIC]' "$TMP/monitor1.out" >/dev/null
! grep -F '[ERROR]' "$TMP/monitor1.out" >/dev/null

printf 'DATABASE DOWN second event\n' >> "$TMP/home dir/log dir/app one.log"

HOME="$TMP/home dir" \
    bash "$ROOT/log-monitor.sh" "$TMP/monitor.toml" > "$TMP/monitor2.out"

grep -F '[DATABASE DOWN]' "$TMP/monitor2.out" >/dev/null
! grep -F '[PANIC]' "$TMP/monitor2.out" >/dev/null

printf 'PANIC after truncation\n' > "$TMP/home dir/log dir/app one.log"

HOME="$TMP/home dir" \
    bash "$ROOT/log-monitor.sh" "$TMP/monitor.toml" > "$TMP/monitor3.out"

grep -F '[PANIC]' "$TMP/monitor3.out" >/dev/null

printf 'ok\n'
