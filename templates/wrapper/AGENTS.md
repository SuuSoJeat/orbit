# Orbit context conventions

- Keep canonical Git repositories outside this wrapper, normally below the
  consumer's configured `repository_root`.
- Use `local/repo` only as an ignored convenience symlink to a canonical repo.
- Use `remote/iCloud` only as an ignored convenience symlink to the iCloud project.
- Do not add nested repository files to the wrapper repository.
- Keep the iCloud project document-only: no `.git`, dependencies, or build output.
- Keep machine-specific paths in `config/orbit.conf`, never in tracked files.
- Treat `bin/doctor` as the ownership and hygiene contract.
