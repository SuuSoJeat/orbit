#!/bin/sh

set -eu

CLI_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/orbit-test.XXXXXX")
FIXTURE_HOME="${FIXTURE}/home"
export HOME="$FIXTURE_HOME"

for script in "$CLI_ROOT/bin/orbit" "$CLI_ROOT/templates/wrapper/bin"/*; do
    sh -n "$script"
done

printf '1\nExample Company\n1\nExample Client\n1\n' \
    | "$CLI_ROOT/bin/orbit" new "Example Project Platform"
WRAPPER_ROOT="${HOME}/Repositories/example-project-platform-orbit"
CLOUD_ROOT="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/SuuSoJeat/Career/Companies/Example Company/Clients/Example Client/Example Project Platform"

[ -d "$CLOUD_ROOT/Notes" ]
[ -f "$WRAPPER_ROOT/config/orbit.conf" ]
[ ! -e "$WRAPPER_ROOT/config/project.env" ]
[ -L "$WRAPPER_ROOT/remote/iCloud" ]
"$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT"
mkdir -p "$WRAPPER_ROOT/PrivateNotes"
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" doctor)
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" open --dry-run >/dev/null)

printf '1\n1\n2\n' \
    | "$CLI_ROOT/bin/orbit" new "Example Project Platform 2"
EXISTING_CLOUD_ROOT="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/SuuSoJeat/Career/Companies/Example Company/Clients/Example Client/Example Project Platform 2"
[ -d "$EXISTING_CLOUD_ROOT/Notes" ]

UNDO_INPUT=$(mktemp "${TMPDIR:-/tmp}/orbit-undo-input.XXXXXX")
UNDO_SELECTION=$(find "${HOME}/.local/state/orbit/creations" -type f -name '*.log' -print | sort \
    | awk '/example-project-platform-2\.log$/ { print NR; exit }')
printf '%s\ny\n' "$UNDO_SELECTION" > "$UNDO_INPUT"
"$CLI_ROOT/bin/orbit" undo < "$UNDO_INPUT"
/bin/rm "$UNDO_INPUT"
[ ! -e "$EXISTING_CLOUD_ROOT" ]
[ -d "$CLOUD_ROOT/Notes" ]
[ -d "$WRAPPER_ROOT" ]

REPOSITORY_ROOT="${HOME}/Repositories/Acme/product"
mkdir -p "$REPOSITORY_ROOT"
git -C "$REPOSITORY_ROOT" init >/dev/null
"$CLI_ROOT/bin/orbit" attach "$WRAPPER_ROOT" "$REPOSITORY_ROOT"
[ -L "$WRAPPER_ROOT/local/repo" ]
grep -F "company_repo = ${REPOSITORY_ROOT}" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
"$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT"
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" attach "$REPOSITORY_ROOT")

UNDO_INPUT=$(mktemp "${TMPDIR:-/tmp}/orbit-undo-input.XXXXXX")
printf '1\ny\n' > "$UNDO_INPUT"
"$CLI_ROOT/bin/orbit" undo < "$UNDO_INPUT"
/bin/rm "$UNDO_INPUT"
[ ! -e "$CLOUD_ROOT" ]
[ ! -e "$WRAPPER_ROOT" ]

printf 'Orbit CLI smoke test passed. Fixture: %s\n' "$FIXTURE"
