SHELL := /bin/sh

VERSION ?= $(shell cat VERSION)
DIST_DIR ?= dist
INSTALL_PREFIX ?= $(HOME)/.local
INSTALL_ROOT := $(INSTALL_PREFIX)/share/orbit/$(VERSION)
INSTALL_BIN := $(INSTALL_PREFIX)/bin/orbit
PACKAGE_NAME := orbit-$(VERSION)
PACKAGE_ROOT := $(DIST_DIR)/$(PACKAGE_NAME)
ARCHIVE := $(DIST_DIR)/$(PACKAGE_NAME).tar.gz
CHECK_SCRIPTS := bin/orbit tests/smoke.sh $(wildcard templates/wrapper/bin/*)

.PHONY: check test build release install uninstall clean

check:
	@for script in $(CHECK_SCRIPTS); do sh -n "$$script" || exit 1; done
	@test -x bin/orbit
	@test "$$(bin/orbit --version)" = "$$(cat VERSION)"
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

install: release
	@rm -rf "$(INSTALL_ROOT)"
	@mkdir -p "$(INSTALL_ROOT)" "$(INSTALL_PREFIX)/bin"
	@cp -R bin templates VERSION README.md Makefile "$(INSTALL_ROOT)/"
	@chmod 755 "$(INSTALL_ROOT)/bin/orbit"
	@printf '#!/bin/sh\nexec "%s" "$$@"\n' "$(INSTALL_ROOT)/bin/orbit" > "$(INSTALL_BIN)"
	@chmod 755 "$(INSTALL_BIN)"
	@printf 'Installed Orbit %s at %s\n' "$(VERSION)" "$(INSTALL_BIN)"

uninstall:
	@rm -f "$(INSTALL_BIN)"
	@rm -rf "$(INSTALL_PREFIX)/share/orbit"
	@printf 'Uninstalled Orbit.\n'

clean:
	@rm -rf "$(DIST_DIR)"
