.PHONY: check test

check:
	bash -n backup.sh sync-github.sh log-monitor.sh

test: check
	./tests/test.sh
