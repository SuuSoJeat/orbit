SHELL := /bin/sh

VERSION ?= $(shell cat VERSION)
DIST_DIR ?= dist
INSTALL_PREFIX ?= $(HOME)/.local
INSTALL_ROOT := $(INSTALL_PREFIX)/share/orbit/$(VERSION)
INSTALL_BIN := $(INSTALL_PREFIX)/bin/orbit
PACKAGE_NAME := orbit-$(VERSION)
PACKAGE_ROOT := $(DIST_DIR)/$(PACKAGE_NAME)
ARCHIVE := $(DIST_DIR)/$(PACKAGE_NAME).tar.gz
CHECK_SCRIPTS := bin/orbit install.sh $(wildcard bin/lib/*) $(wildcard templates/wrapper/bin/*) $(wildcard tests/*.sh) $(wildcard tests/lib/*)
STABLE_ARCHIVE := $(DIST_DIR)/orbit.tar.gz
STABLE_CHECKSUM := $(STABLE_ARCHIVE).sha256
INSTALLER := $(DIST_DIR)/orbit-install.sh
FORMULA := $(DIST_DIR)/orbit.rb

.PHONY: check test signoff build release install uninstall clean

check:
	@for script in $(CHECK_SCRIPTS); do sh -n "$$script" || exit 1; done
	@test -x bin/orbit
	@test "$$(bin/orbit --version)" = "$$(cat VERSION)"
	@printf 'Checks passed.\n'

test: check
	@./tests/smoke.sh

signoff: test
	@command -v gh >/dev/null 2>&1 || { printf 'GitHub CLI is required for signoff.\n' >&2; exit 1; }
	@gh signoff version >/dev/null 2>&1 || { printf 'Install gh-signoff first: gh extension install basecamp/gh-signoff\n' >&2; exit 1; }
	@gh signoff tests

build: check
	@rm -rf "$(PACKAGE_ROOT)"
	@mkdir -p "$(PACKAGE_ROOT)"
	@cp -R bin templates tests README.md VERSION Makefile "$(PACKAGE_ROOT)/"
	@printf 'Built %s\n' "$(PACKAGE_ROOT)"

release: test build
	@mkdir -p "$(DIST_DIR)"
	@tar -czf "$(ARCHIVE)" -C "$(DIST_DIR)" "$(PACKAGE_NAME)"
	@shasum -a 256 "$(ARCHIVE)" > "$(ARCHIVE).sha256"
	@cp "$(ARCHIVE)" "$(STABLE_ARCHIVE)"
	@shasum -a 256 "$(STABLE_ARCHIVE)" > "$(STABLE_CHECKSUM)"
	@cp install.sh "$(INSTALLER)"
	@chmod 755 "$(INSTALLER)"
	@archive_sha256=$$(awk '{ print $$1 }' "$(ARCHIVE).sha256"); \
	{ \
		printf 'class Orbit < Formula\n'; \
		printf '  desc "iCloud-first project workspace CLI"\n'; \
		printf '  homepage "https://github.com/SuuSoJeat/orbit"\n'; \
		printf '  url "https://github.com/SuuSoJeat/orbit/releases/download/v%s/orbit-%s.tar.gz"\n' "$(VERSION)" "$(VERSION)"; \
		printf '  sha256 "%s"\n\n' "$$archive_sha256"; \
		printf '  def install\n'; \
		printf '    libexec.install "bin", "templates", "VERSION", "README.md", "Makefile"\n'; \
		printf '    bin.install_symlink libexec/"bin/orbit"\n'; \
		printf '  end\n\n'; \
		printf '  test do\n'; \
		printf '    assert_equal version.to_s, shell_output("#{bin}/orbit --version").chomp\n'; \
		printf '  end\n'; \
		printf 'end\n'; \
	} > "$(FORMULA)"
	@printf 'Release artifacts:\n%s\n%s\n%s\n%s\n%s\n' "$(ARCHIVE)" "$(ARCHIVE).sha256" "$(STABLE_ARCHIVE)" "$(STABLE_CHECKSUM)" "$(FORMULA)"

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
