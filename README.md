<div align="center">

# Orbit

### An iCloud-first project workspace for local Git repositories.

Start with the human-facing project home. Add a local wrapper and
attach the canonical repository only when you need them.

[![CI](https://github.com/SuuSoJeat/orbit/actions/workflows/ci.yml/badge.svg)](https://github.com/SuuSoJeat/orbit/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/SuuSoJeat/orbit?label=latest)](https://github.com/SuuSoJeat/orbit/releases)

</div>

## Why Orbit

Orbit keeps documents, source code, and local project material in the places
where they belong:

```text
 iCloud project                 optional wrapper              canonical Git repo
 notes, assets, exports   ←→    local control plane    ←→    canonical source
```

The wrapper is optional. Orbit creates local links between these surfaces; it
does not move or copy source code into the iCloud project.

## Install

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

## Quick start

Create an iCloud project:

```sh
orbit new "Acme Product" --category companies
```

Add a local wrapper during creation:

```sh
orbit new "Acme Product" \
  --category companies \
  --with-wrapper
```

For a company/client project, Orbit can guide you through numbered pickers.
The same flow can be scripted:

```sh
orbit new "Example Project Platform" \
  --company "Example Company" \
  --client "Example Client" \
  --with-wrapper
```

Configure consumer-specific locations before using category-based creation:

```sh
orbit config init
orbit config check
```

With no configuration file, Orbit uses these defaults:

```text
~/Repositories
~/Library/Mobile Documents/com~apple~CloudDocs/Workspace/Companies
~/Library/Mobile Documents/com~apple~CloudDocs/Workspace/Ventures
```

The configuration is stored at `~/.config/orbit/config`, or at the path
specified by `ORBIT_CONFIG` or the global `--config PATH` option. It is
consumer-specific and should not be committed. Use `orbit config show` to
inspect the resolved paths. To add an explicit namespace below the iCloud
Drive root, use `orbit config init --icloud-profile NAME`.

Attach an existing canonical repository:

```sh
orbit attach \
  "$HOME/Repositories/acme-product-orbit" \
  "$HOME/Repositories/Acme/product"
```

Check the boundaries and see the configured destinations:

```sh
orbit doctor "$HOME/Repositories/acme-product-orbit"
orbit open "$HOME/Repositories/acme-product-orbit" --dry-run
```

From inside a wrapper, Orbit discovers its path automatically:

```sh
cd "$HOME/Repositories/acme-product-orbit"
orbit doctor
orbit open --dry-run
orbit attach "$HOME/Repositories/Acme/product"
```

## Commands

| Command | What it does |
| --- | --- |
| orbit config init/show/check | Create or inspect consumer-specific locations |
| `orbit new [PROJECT_NAME]` | Create an iCloud project and optionally a local wrapper |
| `orbit attach REPOSITORY_PATH` | Attach a canonical local Git repository to the current wrapper |
| `orbit doctor` | Validate the wrapper, iCloud project, and repository boundaries |
| `orbit open --dry-run` | Print the project locations without opening applications |
| `orbit open --launch` | Open the iCloud project, wrapper, and configured editor on macOS |
| `orbit undo` | Review and remove a previously recorded project creation |

### `orbit new` options

```text
orbit new [PROJECT_NAME] [--category companies|ventures]
            [--company NAME] [--client NAME|--no-client]
            [--icloud-root PATH] [--with-wrapper] [--wrapper-root PATH]
```

Use `--category ventures` for a project directly under the ventures iCloud
root. Company projects can use `--company NAME` and `--client NAME`, or
`--no-client` for a company-level project. Omit `NAME` or the company/client
values to use the interactive pickers.

`--wrapper-root PATH` also enables the local wrapper and lets you choose its
location. Otherwise, Orbit uses the configured `wrapper_root`, which defaults
to `repository_root`:

```text
~/Repositories/<project-slug>-orbit
```

`--icloud-root PATH` creates a one-off project and bypasses the category roots
in the consumer configuration.

## Storage rules

- Keep notes, references, assets, exports, and other sync-worthy documents in
  the iCloud project.
- Keep the canonical Git repository outside iCloud, normally under
  the configured `repository_root`.
- Keep secrets, credentials, `.git` directories, dependencies, and build
  output out of the iCloud project.
- Use `orbit doctor` before relying on a wrapper or attached repository.

`orbit undo` records creations under `~/.local/state/orbit/creations/` and
only removes paths recorded for the creation you select.

## Contributing

Development, testing, CI, release, packaging, and wrapper-template guidance
lives in [CONTRIBUTING.md](CONTRIBUTING.md).
