SHELL := /bin/sh

VERSION ?= $(shell cat VERSION)
DIST_DIR ?= dist
PACKAGE_NAME := studio-$(VERSION)
PACKAGE_ROOT := $(DIST_DIR)/$(PACKAGE_NAME)
ARCHIVE := $(DIST_DIR)/$(PACKAGE_NAME).tar.gz
CHECK_SCRIPTS := bin/studio tests/smoke.sh $(wildcard templates/wrapper/bin/*)

.PHONY: check test build release clean

check:
	@for script in $(CHECK_SCRIPTS); do sh -n "$$script" || exit 1; done
	@test -x bin/studio
	@test "$$(bin/studio --version)" = "$$(cat VERSION)"
	@printf 'Checks passed.\n'

test: check
	@./tests/smoke.sh

build: check
	@rm -rf "$(PACKAGE_ROOT)"
	@mkdir -p "$(PACKAGE_ROOT)"
	@cp -R bin templates tests README.md VERSION Makefile "$(PACKAGE_ROOT)/"
	@printf 'Built %s\n' "$(PACKAGE_ROOT)"

release: test build
	@mkdir -p "$(DIST_DIR)"
	@tar -czf "$(ARCHIVE)" -C "$(DIST_DIR)" "$(PACKAGE_NAME)"
	@shasum -a 256 "$(ARCHIVE)" > "$(ARCHIVE).sha256"
	@printf 'Release artifacts:\n%s\n%s\n' "$(ARCHIVE)" "$(ARCHIVE).sha256"

clean:
	@rm -rf "$(DIST_DIR)"
