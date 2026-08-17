# Orbit wrapper conventions

- Keep canonical Git repositories outside this wrapper, normally below the
  consumer's configured `repository_root`.
- Use `local/repo/<repository-name>` only as ignored convenience symlinks to
  canonical repositories.
- Use `remote/iCloud` only as an ignored convenience symlink to the iCloud project.
- Do not add nested repository files to the wrapper repository.
- Keep the iCloud project document-only: no `.git`, dependencies, or build output.
- Keep machine-specific paths in `config/orbit.conf`, never in tracked files.
- Store each attachment as `[repository "NAME"]` with a `path` value; use the
  section name for the local repository symlink.
- Treat `bin/doctor` as the ownership and hygiene contract.
