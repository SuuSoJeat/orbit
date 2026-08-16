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

## Development and release

```bash
make check       # shell syntax and executable checks
make test        # isolated lifecycle smoke test
make release     # test, build tarball, and write SHA-256 checksum
make install     # install Orbit under ~/.local and create ~/.local/bin/orbit
```

Releases are intended to be tagged as `v<version>`. The GitHub Actions release
workflow packages the tag and publishes the archive to a GitHub release.

If `~/.local/bin` is not already on your PATH, add it once in `~/.zprofile`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```
