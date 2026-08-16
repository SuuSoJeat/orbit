<div align="center">

# Orbit

### An iCloud-first project context for local Git repositories.

Start with the human-facing project home. Add a private local wrapper and
attach the canonical repository only when you need them.

[![CI](https://github.com/SuuSoJeat/orbit/actions/workflows/ci.yml/badge.svg)](https://github.com/SuuSoJeat/orbit/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/SuuSoJeat/orbit?label=latest)](https://github.com/SuuSoJeat/orbit/releases)

</div>

## Why Orbit

Orbit keeps documents, source code, and local project context in the places
where they belong:

```text
 iCloud project                 optional wrapper              local Git repo
 notes, assets, exports   ←→    local control plane    ←→    canonical source
```

The wrapper is optional. Orbit creates local links between these surfaces; it
does not move or copy company source code into the iCloud project.

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

Create an iCloud-first project:

```sh
orbit new "Acme Product" --category companies
```

Add a private local wrapper during creation:

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
orbit config init \
  --companies-root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/YourName/Career/Companies" \
  --ventures-root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/YourName/Ventures/Software" \
  --repository-root "$HOME/Repositories"
orbit config check
```

The configuration is stored at `~/.config/orbit/config`, or at the path
specified by `ORBIT_CONFIG` or the global `--config PATH` option. It is
consumer-specific and should not be committed. Use `orbit config show` to
inspect the resolved paths.

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
| `orbit new [NAME]` | Create an iCloud-first project and optionally a private wrapper |
| `orbit attach REPOSITORY_PATH` | Attach a canonical local Git repository to the current wrapper |
| `orbit doctor` | Validate the wrapper, iCloud project, and repository boundaries |
| `orbit open --dry-run` | Print the project destinations without opening applications |
| `orbit open --launch` | Open the iCloud project, wrapper, and configured editor on macOS |
| `orbit undo` | Review and remove a previously recorded Orbit creation |

### `orbit new` options

```text
orbit new [NAME] [--category companies|ventures]
            [--company NAME] [--client NAME|--no-client]
            [--cloud-root PATH] [--with-wrapper] [--wrapper-root PATH]
```

Use `--category ventures` for a project directly under the ventures iCloud
root. Company projects can use `--company NAME` and `--client NAME`, or
`--no-client` for a company-level project. Omit `NAME` or the company/client
values to use the interactive pickers.

`--wrapper-root PATH` also enables the private wrapper and lets you choose its
location. Otherwise, Orbit uses the configured `wrapper_root`, which defaults
to `repository_root`:

```text
~/Repositories/<project-slug>-orbit
```

`--cloud-root PATH` remains available for a one-off project and bypasses the
category roots in the consumer configuration.

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
