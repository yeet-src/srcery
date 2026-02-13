SHELL_FILES := $(wildcard cmd/*) $(wildcard lib/*) $(wildcard hooks/by-repo/*/*) $(wildcard completions/completers/*) completions/generate

.PHONY: lint check_lint test completions

lint:
	@diff=$$(shellcheck --shell=bash -f diff $(SHELL_FILES)) && true; \
	if [ -n "$$diff" ]; then echo "$$diff" | git apply; fi

check_lint:
	shellcheck --shell=bash $(SHELL_FILES)

completions:
	completions/generate

test:
	@for f in test/test-*.sh; do echo "=== $$f ===" && bash "$$f" || exit 1; done
