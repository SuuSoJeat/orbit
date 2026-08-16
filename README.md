# Studio CLI

`studio` is the outer command for the iCloud-first studio model. It can create
the studio before any Git repository exists, and can later create an optional
private context and attach a canonical local repository.

## Commands

```text
studio new NAME [--category companies|ventures] [--cloud-root PATH]
            [--with-wrapper] [--wrapper-root PATH]
studio attach WRAPPER_ROOT REPOSITORY_PATH
studio doctor WRAPPER_ROOT
studio open WRAPPER_ROOT [--dry-run|--launch]
```

`studio new` always creates the iCloud-side studio folders. Add
`--with-wrapper` when you also want a private wrapper context. The default
wrapper location is:

```text
~/Repositories/personal/<project-slug>-context
```

The wrapper is copied from `templates/wrapper`. Its `bootstrap` command then
creates the local-only `local/repo` and `remote/iCloud` boundary links.

## Example lifecycle

Create an iCloud-first project:

```bash
./bin/studio new "Acme Product" --category companies
```

Add a private wrapper later:

```bash
./bin/studio new "Acme Product" \
  --category companies \
  --cloud-root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/SuuSoJeat/Career/Companies/Acme Product" \
  --with-wrapper
```

Attach the canonical company repository:

```bash
./bin/studio attach \
  "$HOME/Repositories/personal/acme-product-context" \
  "$HOME/Repositories/Acme/product"
```

The CLI does not move or copy company source code into the context. It only
creates a local symlink view.

## Development and release

```bash
make check       # shell syntax and executable checks
make test        # isolated lifecycle smoke test
make release     # test, build tarball, and write SHA-256 checksum
```

Releases are intended to be tagged as `v<version>`. The GitHub Actions release
workflow packages the tag and publishes the archive to a GitHub release.
