.PHONY: check test

check:
	bash -n backup.sh sync-github.sh log-monitor.sh
	python3 -m py_compile md2html.py

test: check
	./tests/test.sh
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v tests.test_md2html
