# Contributing to Orbit

This guide covers the parts of Orbit that are useful when changing the
project itself: local checks, wrapper-template conventions, CI, packaging, and
releases. For installation and normal CLI usage, see [README.md](README.md).

## Project boundaries

Orbit is a POSIX shell CLI with a macOS-facing iCloud workflow. Keep the three
ownership boundaries intact:

```text
remote/iCloud  → synced documents, notes, assets, and exports
local/repo     → ignored symlink to a canonical Git repository
config/        → ignored machine-specific wrapper settings
```

The wrapper repository owns scripts and configuration templates. The
canonical repository owns source code. The iCloud project must remain free of
Git metadata, dependencies, build output, and credentials.

The generated wrapper comes from [`templates/wrapper`](templates/wrapper):

```text
templates/wrapper/
├── AGENTS.md
├── README.md
├── bin/doctor
├── bin/lib.sh
└── config/orbit.conf.example
```

Update the template documentation when changing the wrapper contract. The
template's `bin/doctor` is the ownership and hygiene contract for generated
wrappers.

## Local development

The repository has no dependency install step. A working POSIX shell, Git,
`make`, and the standard checksum utility (`shasum` or `sha256sum`) are
enough for the local checks.

Run the checks before submitting a change:

```sh
make check       # shell syntax, executable bits, and version check
make test        # isolated end-to-end lifecycle smoke test
```

The smoke test uses a temporary fixture and exercises creation, interactive
selection, wrapper setup, attachment, `doctor`, `open --dry-run`, and undo.

Build a local release package when needed:

```sh
make build       # create dist/orbit-<VERSION>/
make release     # archives, checksums, installer, and Homebrew formula
```

`make install` runs the release build first, then installs Orbit under
`~/.local/share/orbit/<VERSION>` and creates `~/.local/bin/orbit`.

## Pull requests and CI

GitHub Actions runs `make test` for pushes and pull requests. Keep changes
small and explain behavior changes in the pull request description.

Orbit also uses [gh-signoff](https://github.com/basecamp/gh-signoff) as a
maintainer-controlled status check. Install and enable it once:

```sh
gh extension install basecamp/gh-signoff
gh signoff install tests
```

Before opening or updating a pull request, run:

```sh
make signoff
```

This runs the smoke test and publishes the `signoff/tests` status. If `gh` or
the extension is unavailable, `make signoff` stops without changing project
files.

## Release process

`VERSION` is the source of truth for the release number. A release tag must
match it exactly, for example:

```text
VERSION = 0.2.1
tag     = v0.2.1
```

Pushing a `v*` tag starts the release workflows. They:

1. verify the tag matches `VERSION`;
2. run `make release` and publish versioned/stable archives, SHA-256
   checksums, the installer, and a generated Homebrew formula;
3. publish `ghcr.io/suusojeat/orbit:<tag>` and `:latest` to GitHub Container
   Registry.

The Homebrew formula is maintained in the public
[`SuuSoJeat/homebrew-tap`](https://github.com/SuuSoJeat/homebrew-tap)
repository. Keep its formula aligned with the generated `dist/orbit.rb`
artifact.

## Packaging details

The release archive includes `bin`, `templates`, `tests`, `README.md`,
`VERSION`, and `Makefile`. The installer copies the runtime files into the
versioned local installation directory and creates a small executable
launcher in `~/.local/bin`.

The container image is built from [`Dockerfile`](Dockerfile) and runs
`/opt/orbit/bin/orbit`. Keep the image contents aligned with the files copied
by `make build`.

## Documentation policy

- Keep `README.md` consumer-facing: installation, CLI usage, workflows, and
  user-visible storage rules.
- Put contributor, test, CI, packaging, release, and implementation details in
  this file or focused documentation under `docs/`.
- If a CLI behavior changes, update the README examples and the smoke test.
- If the wrapper contract changes, update `templates/wrapper/README.md`,
  `templates/wrapper/AGENTS.md`, and the generated-wrapper checks.
