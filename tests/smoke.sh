#!/bin/sh

set -eu

CLI_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/orbit-test.XXXXXX")
FIXTURE_HOME="${FIXTURE}/home"
export HOME="$FIXTURE_HOME"
CONFIG_FILE="${FIXTURE}/consumer.conf"
COMPANIES_ROOT="${FIXTURE}/icloud/Alice/Career/Companies"
VENTURES_ROOT="${FIXTURE}/icloud/Alice/Ventures/Software"
REPOSITORIES_ROOT="${FIXTURE_HOME}/repositories"
export ORBIT_CONFIG="$CONFIG_FILE"

"$CLI_ROOT/bin/orbit" config init \
    --companies-root "$COMPANIES_ROOT" \
    --ventures-root "$VENTURES_ROOT" \
    --repository-root "~/repositories"
"$CLI_ROOT/bin/orbit" config check
"$CLI_ROOT/bin/orbit" config show | grep -F "repository_root: ${REPOSITORIES_ROOT}" >/dev/null

for script in "$CLI_ROOT/bin/orbit" "$CLI_ROOT/templates/wrapper/bin"/*; do
    sh -n "$script"
done

printf '1\nExample Company\n1\nExample Client\n1\n' \
    | "$CLI_ROOT/bin/orbit" new "Example Project Platform"
WRAPPER_ROOT="${REPOSITORIES_ROOT}/example-project-platform-orbit"
CLOUD_ROOT="${COMPANIES_ROOT}/Example Company/Clients/Example Client/Example Project Platform"

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
EXISTING_CLOUD_ROOT="${COMPANIES_ROOT}/Example Company/Clients/Example Client/Example Project Platform 2"
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

REPOSITORY_ROOT="${REPOSITORIES_ROOT}/Acme/product"
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

SECOND_CONFIG="${FIXTURE}/other-consumer.conf"
SECOND_VENTURES_ROOT="${FIXTURE}/other-icloud/Ventures/Software"
"$CLI_ROOT/bin/orbit" --config "$SECOND_CONFIG" config init \
    --ventures-root "$SECOND_VENTURES_ROOT" \
    --repository-root "${FIXTURE}/other-repositories"
"$CLI_ROOT/bin/orbit" --config "$SECOND_CONFIG" new "Other Consumer Venture" --category ventures
[ -d "$SECOND_VENTURES_ROOT/Other Consumer Venture/Notes" ]

printf 'Orbit CLI smoke test passed. Fixture: %s\n' "$FIXTURE"
