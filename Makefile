SHELL_FILES := $(wildcard cmd/*)

.PHONY: lint check_lint test

lint:
	@diff=$$(shellcheck --shell=bash -f diff $(SHELL_FILES)) && true; \
	if [ -n "$$diff" ]; then echo "$$diff" | git apply; fi

check_lint:
	shellcheck --shell=bash $(SHELL_FILES)

test:
	@bash test/test-svc.sh
