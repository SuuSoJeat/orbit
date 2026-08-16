<div align="center">

# Orbit

### An iCloud-first project context for local Git repositories.

Create the human-facing project home first. Add a private local wrapper and
attach the canonical repository only when you need them.

[![CI](https://github.com/SuuSoJeat/orbit/actions/workflows/ci.yml/badge.svg)](https://github.com/SuuSoJeat/orbit/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/SuuSoJeat/orbit?label=latest)](https://github.com/SuuSoJeat/orbit/releases)

</div>

<br>

## The idea

Orbit keeps three surfaces deliberately separate:

```text
                         orbit
                           │
          ┌────────────────┼────────────────┐
          │                │                │
     remote/iCloud     local/repo       config/
   documents, assets   canonical Git    machine settings
    and references      repository        (ignored)
          │                │                │
       iCloud          ~/Repositories     wrapper only
```

The iCloud orbit is the human-facing home. The wrapper is an optional local
control plane, and the source repository stays in local Git storage. Orbit
creates links between these surfaces; it does not move or copy company source
code into the context.

## Quick start

### Install

With Homebrew:

```sh
brew install SuuSoJeat/tap/orbit
```

Without Homebrew:

```sh
curl -fsSL https://github.com/SuuSoJeat/orbit/releases/latest/download/orbit-install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
```

The portable installer uses `~/.local`. The repository and its releases must
be public for this command to work for everyone; until then, it is available
to repository collaborators only.

### Create an orbit

```sh
orbit new "Acme Product" --category companies
```

That creates the iCloud-side orbit. Add a private wrapper when you want a
local control plane too:

```sh
orbit new "Acme Product" \
  --category companies \
  --with-wrapper
```

For a fully scripted company/client flow:

```sh
orbit new "Example Project Platform" \
  --company "Example Company" \
  --client "Example Client" \
  --with-wrapper
```

## Choose your flow

| Need | Command | Result |
| --- | --- | --- |
| Start with synced documents | `orbit new "Project"` | Creates an iCloud-first orbit |
| Add a private local context | `orbit new "Project" --with-wrapper` | Adds a wrapper under `~/Repositories/<project>-orbit` |
| Connect existing source code | `orbit attach WRAPPER REPOSITORY` | Creates the local repository view |
| Check the storage boundaries | `orbit doctor [WRAPPER]` | Validates the wrapper and its links |
| See or open project surfaces | `orbit open [WRAPPER] --dry-run` | Prints destinations without launching apps |
| Reverse a recorded creation | `orbit undo` | Removes only paths recorded for a selected creation |

## Command reference

```text
orbit new [NAME] [--category companies|ventures]
            [--company NAME] [--client NAME|--no-client]
            [--cloud-root PATH] [--with-wrapper] [--wrapper-root PATH]
orbit undo
orbit attach [WRAPPER_ROOT] REPOSITORY_PATH
orbit doctor [WRAPPER_ROOT]
orbit open [WRAPPER_ROOT] [--dry-run|--launch]
```

`orbit new` can be interactive or scripted. For company orbits, the
interactive flow offers numbered pickers for the company and client, including
`Create new` and `No client (company-level orbit)`. It also asks whether to
create the optional private wrapper. Existing folders are reused instead of
duplicated.

When run inside a wrapper, `doctor`, `open`, and `attach` discover it by
walking upward from the current directory. Pass the wrapper path explicitly
when running elsewhere.

## A typical lifecycle

```text
1. Create the iCloud orbit       orbit new "Acme Product"
2. Add a private wrapper         orbit new "Acme Product" --with-wrapper
3. Attach canonical Git          orbit attach WRAPPER REPOSITORY
4. Validate the boundary         orbit doctor
5. Open the project surfaces     orbit open --launch
```

### Attach an existing repository

```sh
orbit attach \
  "$HOME/Repositories/acme-product-orbit" \
  "$HOME/Repositories/Acme/product"
```

From inside the wrapper, the wrapper path can be omitted:

```sh
cd "$HOME/Repositories/acme-product-orbit"
orbit doctor
orbit open --dry-run
orbit attach "$HOME/Repositories/Acme/product"
```

### Undo a creation

Orbit records each creation under `~/.local/state/orbit/creations/`, including
the timestamp, orbit name, commands, and exact paths created. `orbit undo`
lets you choose an active record, prints every deletion, and removes the
journal after the operation.

## What a wrapper owns

```text
<project>-orbit/
├── bin/                 local control scripts
├── config/orbit.conf    ignored, machine-specific settings
├── local/repo           → canonical repository under ~/Repositories
├── remote/iCloud        → synced iCloud project
└── README.md
```

The wrapper owns its scripts and configuration templates. The canonical
repository owns source code. iCloud owns notes, references, assets, exports,
and other sync-worthy documents. Keep secrets, credentials, `.git`
directories, dependencies, and build output out of the iCloud project.

When created with `--with-wrapper`, the wrapper is copied from
`templates/wrapper` and initialized with its local-only `local/repo` and
`remote/iCloud` boundary links.

`config/orbit.conf` is a plain-text key-value file containing `name`,
`company_repo`, and `cloud_root`. Orbit derives the two boundary-link paths
from the wrapper root, so they do not become stale configuration values.

## Development, CI, and release

```sh
make check       # shell syntax and executable checks
make test        # isolated lifecycle smoke test
make signoff     # test, then publish a gh-signoff/tests status
make release     # test, build archives, checksums, and installer asset
make install     # install Orbit under ~/.local and create ~/.local/bin/orbit
```

Orbit uses [gh-signoff](https://github.com/basecamp/gh-signoff) as its local
CI gate. Install it once, then enable the required status check on the default
branch as a maintainer:

```sh
gh extension install basecamp/gh-signoff
gh signoff install tests
```

Before opening or updating a pull request, run `make signoff`. The repository
also keeps a GitHub Actions smoke-test workflow for release regression
coverage.

Releases are created by pushing a tag that exactly matches `VERSION`, for
example `v0.2.1`. GitHub Actions publishes versioned and stable archives,
SHA-256 checksums, a Homebrew formula, and the installer script to the GitHub
Release.

GitHub Packages publishes `ghcr.io/suusojeat/orbit:<tag>` and `:latest` for
reproducible automation. The release installer is the intended local CLI
installation path. Public anonymous pulls require the package and repository
to be public.

The formula is maintained in the public
[`SuuSoJeat/homebrew-tap`](https://github.com/SuuSoJeat/homebrew-tap)
repository. Homebrew is the native distribution channel; the release
installer remains available for machines without Homebrew.

If `~/.local/bin` is not already on your PATH, add it once in `~/.zprofile`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```
