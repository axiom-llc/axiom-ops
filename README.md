# AXIOM Ops

Minimal deterministic operations tooling for Linux systems.

`axiom-ops` provides three auditable utilities:

- encrypted directory backups with bounded retention;
- local-source-of-truth Git synchronization;
- incremental pattern-based log monitoring.

The tools use explicit TOML configuration and avoid a resident service or framework.

## Requirements

- Bash
- Python 3.11+ (`tomllib`)
- GNU coreutils
- `tar`
- GnuPG
- Git

## Configure

Copy `config.example.toml` to `config.toml`, then review every value before execution.

## Git synchronization

Run `./sync-github.sh config.toml`.

The script fetches `origin`, commits current working-tree changes, and pushes the current `HEAD`.

When `force_with_lease = true`, it uses `git push --force-with-lease origin HEAD`. Enable that only when the local repository is intentionally authoritative.

## Encrypted backup

Run `./backup.sh config.toml`.

The backup is streamed through GnuPG and written atomically as `backup_*.tar.gz.gpg`. Retention deletion is restricted to matching backup files.

`gpg_recipient` must identify a usable local GnuPG encryption recipient.

## Log monitoring

Run `./log-monitor.sh config.toml`.

The monitor reads bytes appended since the previous invocation and stores per-file offsets under `~/.cache/axiom-ops/log-monitor/`. Configured alert patterns are matched literally. File truncation resets monitoring to byte zero.

## Validation

Run `make test`.

The test harness uses isolated temporary directories and fake external commands for Git and encryption. It performs no network operations.

## License

MIT
