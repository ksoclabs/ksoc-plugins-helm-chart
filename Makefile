CURRENT_WORKING_DIR=$(shell pwd)

initialise:
	pre-commit --version || brew install pre-commit
	shellcheck --version || brew install shellcheck
	pre-commit install
	pre-commit run --all-files

template-stable-%s:
	helm template stable/$* --debug

deprecation-checks:
	./bin/deprecation-checks

kubeval-checks:
	./bin/kubeval-each-chart

sync-repo-cloudflare:
	./bin/sync-repo-cloudflare.sh
