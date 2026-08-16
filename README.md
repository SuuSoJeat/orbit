# Orbit CLI

`orbit` is the outer command for the iCloud-first orbit model. It can create
the orbit before any Git repository exists, and can later create an optional
private context and attach a canonical local repository.

## Commands

```text
orbit new [NAME] [--category companies|ventures]
            [--company NAME] [--client NAME|--no-client]
            [--cloud-root PATH] [--with-wrapper] [--wrapper-root PATH]
orbit undo
orbit attach [WRAPPER_ROOT] REPOSITORY_PATH
orbit doctor [WRAPPER_ROOT]
orbit open [WRAPPER_ROOT] [--dry-run|--launch]
```

`orbit new` always creates the iCloud-side orbit folders. Add
`--with-wrapper` when you also want a private wrapper context. The default
wrapper location is:

```text
~/Repositories/<project-slug>-orbit
```

The wrapper is copied from `templates/wrapper`, and Orbit initializes its
local-only `local/repo` and `remote/iCloud` boundary links.

Each wrapper keeps its machine-specific settings in the ignored
`config/orbit.conf`. It is a plain-text key-value file containing `name`,
`company_repo`, and `cloud_root`; Orbit derives the two boundary-link paths
from the wrapper root.

For company orbits, an interactive run presents numbered pickers for the
company and client. Each picker includes a `Create new` option; the client
picker also includes `No client (company-level orbit)`. Existing folders are
reused instead of duplicated. Interactive runs then ask whether to create the
optional private wrapper, with `Create private wrapper` and `No wrapper
(iCloud only)` choices.

The same flow can be scripted with `--company NAME` and `--client NAME`, or
with `--no-client` for an orbit directly under the company. Omit `NAME` to
pick the orbit name interactively as well.

When run from inside a wrapper, `doctor`, `open`, and `attach` infer the
wrapper by walking upward from the current directory. You can still provide
the wrapper path explicitly when running elsewhere.

## Example lifecycle

Create an iCloud-first project:

```bash
./bin/orbit new "Acme Product" --category companies
```

Interactive company/client selection:

```bash
./bin/orbit new "Example Project Platform"
```

Scriptable equivalent:

```bash
./bin/orbit new "Example Project Platform" \
  --company "Example Company" \
  --client "Example Client" \
  --with-wrapper
```

Undo a creation:

```bash
./bin/orbit undo
```

Orbit records each creation under `~/.local/state/orbit/creations/`, including
the timestamp, orbit name, commands, and exact paths created. `orbit undo`
lets you choose an active recorded creation and removes only those recorded
paths. It prints every deletion during the undo operation, then removes the
journal to avoid leaving unused state behind.

Add a private wrapper later:

```bash
./bin/orbit new "Acme Product" \
  --category companies \
  --cloud-root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/SuuSoJeat/Career/Companies/Acme Product" \
  --with-wrapper
```

Attach the canonical company repository:

```bash
./bin/orbit attach \
  "$HOME/Repositories/acme-product-orbit" \
  "$HOME/Repositories/Acme/product"
```

From inside the wrapper, the same commands can omit the wrapper path:

```bash
cd "$HOME/Repositories/acme-product-orbit"
orbit doctor
orbit open --dry-run
orbit attach "$HOME/Repositories/Acme/product"
```

The CLI does not move or copy company source code into the context. It only
creates a local symlink view.

## Install

The recommended one-command install uses Homebrew and a formula generated for
each GitHub Release. Homebrew downloads the versioned archive and verifies its
SHA-256 checksum:

```sh
brew install https://github.com/SuuSoJeat/orbit/releases/latest/download/orbit.rb
```

On machines without Homebrew, use the portable first-party installer:

```sh
curl -fsSL https://github.com/SuuSoJeat/orbit/releases/latest/download/orbit-install.sh | sh
```

The portable installer uses `~/.local`; add `~/.local/bin` to your PATH once
if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

The repository and its releases must be public for this command to work for
everyone. Until then, it is available to repository collaborators only.

## Development, CI, and release

```bash
make check       # shell syntax and executable checks
make test        # isolated lifecycle smoke test
make signoff     # test, then publish a gh-signoff/tests status
make release     # test, build archives, checksums, and installer asset
make install     # install Orbit under ~/.local and create ~/.local/bin/orbit
```

Orbit uses [gh-signoff](https://github.com/basecamp/gh-signoff) as its local
CI gate. Install it once, then enable the required status check on the default
branch as a maintainer:

```bash
gh extension install basecamp/gh-signoff
gh signoff install tests
```

Before opening or updating a pull request, run `make signoff`. It runs the
smoke test and signs the commit with the `signoff/tests` GitHub status. The
repository also keeps a small GitHub Actions smoke-test workflow for release
regression coverage.

Releases are created by pushing a tag that exactly matches `VERSION`, for
example `v0.2.1`. GitHub Actions publishes versioned and stable archive names,
SHA-256 checksums, a Homebrew formula, and the installer script to the GitHub
Release.

GitHub Packages is configured through the GitHub Container Registry. Each
release publishes `ghcr.io/suusojeat/orbit:<tag>` and `:latest`. This is useful
for reproducible automation; the release installer is the intended local CLI
installation path. Public anonymous pulls require the package and repository
to be public.

For a future Homebrew tap, the ideal shorter command would be
`brew install SuuSoJeat/tap/orbit` after publishing a public
`SuuSoJeat/homebrew-tap` formula repository. Homebrew is the best long-term
native distribution channel, but it cannot serve this private repository's
release assets yet.

If `~/.local/bin` is not already on your PATH, add it once in `~/.zprofile`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```
