#!/bin/sh

set -eu

CLI_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/orbit-test.XXXXXX")
FIXTURE_HOME="${FIXTURE}/home"
export HOME="$FIXTURE_HOME"
DEFAULT_HOME="${FIXTURE}/default-home"
DEFAULT_WORKSPACE="${DEFAULT_HOME}/Library/Mobile Documents/com~apple~CloudDocs/iCloud/Workspace"
env -u ORBIT_CONFIG HOME="$DEFAULT_HOME" "$CLI_ROOT/bin/orbit" new "Default Venture" --category ventures
[ -d "$DEFAULT_WORKSPACE/Ventures/Default Venture/Notes" ]
ONE_OFF_ROOT="${FIXTURE}/one-off-icloud-project"
env -u ORBIT_CONFIG HOME="$DEFAULT_HOME" "$CLI_ROOT/bin/orbit" new "One-off Project" --icloud-root "$ONE_OFF_ROOT"
[ -d "$ONE_OFF_ROOT/Notes" ]
if env -u ORBIT_CONFIG HOME="$DEFAULT_HOME" "$CLI_ROOT/bin/orbit" new "Legacy Flag" --cloud-root "$FIXTURE" >/dev/null 2>&1; then
    printf 'Removed --cloud-root unexpectedly accepted.\n' >&2
    exit 1
fi

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
ICLOUD_PROJECT_PATH="${COMPANIES_ROOT}/Example Company/Clients/Example Client/Example Project Platform"

[ -d "$ICLOUD_PROJECT_PATH/Notes" ]
[ -f "$WRAPPER_ROOT/config/orbit.conf" ]
[ ! -e "$WRAPPER_ROOT/config/project.env" ]
[ -L "$WRAPPER_ROOT/remote/iCloud" ]
grep -F "project_name = Example Project Platform" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
grep -F "icloud_project_path = ${ICLOUD_PROJECT_PATH}" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
"$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT"
mkdir -p "$WRAPPER_ROOT/PrivateNotes"
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" doctor)
OPEN_OUTPUT=$(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" open --dry-run)
printf '%s\n' "$OPEN_OUTPUT" | grep -F "repository: (not attached yet)" >/dev/null
printf '%s\n' "$OPEN_OUTPUT" | grep -F "iCloud:    ${ICLOUD_PROJECT_PATH}" >/dev/null

printf '1\n1\n2\n' \
    | "$CLI_ROOT/bin/orbit" new "Example Project Platform 2"
EXISTING_ICLOUD_PROJECT_PATH="${COMPANIES_ROOT}/Example Company/Clients/Example Client/Example Project Platform 2"
[ -d "$EXISTING_ICLOUD_PROJECT_PATH/Notes" ]

UNDO_INPUT=$(mktemp "${TMPDIR:-/tmp}/orbit-undo-input.XXXXXX")
UNDO_SELECTION=$(find "${HOME}/.local/state/orbit/creations" -type f -name '*.log' -print | sort \
    | awk '/example-project-platform-2\.log$/ { print NR; exit }')
printf '%s\ny\n' "$UNDO_SELECTION" > "$UNDO_INPUT"
"$CLI_ROOT/bin/orbit" undo < "$UNDO_INPUT"
/bin/rm "$UNDO_INPUT"
[ ! -e "$EXISTING_ICLOUD_PROJECT_PATH" ]
[ -d "$ICLOUD_PROJECT_PATH/Notes" ]
[ -d "$WRAPPER_ROOT" ]

REPOSITORY_ROOT="${REPOSITORIES_ROOT}/Acme/product"
mkdir -p "$REPOSITORY_ROOT"
git -C "$REPOSITORY_ROOT" init >/dev/null
"$CLI_ROOT/bin/orbit" attach "$WRAPPER_ROOT" "$REPOSITORY_ROOT"
[ -L "$WRAPPER_ROOT/local/repo" ]
grep -F "repository_path = ${REPOSITORY_ROOT}" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
"$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT"
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" attach "$REPOSITORY_ROOT")

UNDO_INPUT=$(mktemp "${TMPDIR:-/tmp}/orbit-undo-input.XXXXXX")
printf '1\ny\n' > "$UNDO_INPUT"
"$CLI_ROOT/bin/orbit" undo < "$UNDO_INPUT"
/bin/rm "$UNDO_INPUT"
[ ! -e "$ICLOUD_PROJECT_PATH" ]
[ ! -e "$WRAPPER_ROOT" ]

SECOND_CONFIG="${FIXTURE}/other-consumer.conf"
SECOND_VENTURES_ROOT="${FIXTURE}/other-icloud/Ventures/Software"
"$CLI_ROOT/bin/orbit" --config "$SECOND_CONFIG" config init \
    --ventures-root "$SECOND_VENTURES_ROOT" \
    --repository-root "${FIXTURE}/other-repositories"
"$CLI_ROOT/bin/orbit" --config "$SECOND_CONFIG" new "Other Consumer Venture" --category ventures
[ -d "$SECOND_VENTURES_ROOT/Other Consumer Venture/Notes" ]

PROFILE_CONFIG="${FIXTURE}/profile-consumer.conf"
PROFILE_WORKSPACE="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/iCloud/Alice/Workspace"
"$CLI_ROOT/bin/orbit" --config "$PROFILE_CONFIG" config init \
    --icloud-profile Alice \
    --repository-root "${FIXTURE}/profile-repositories"
"$CLI_ROOT/bin/orbit" --config "$PROFILE_CONFIG" config show \
    | grep -F "companies_root: ${PROFILE_WORKSPACE}/Companies" >/dev/null

printf 'Orbit CLI smoke test passed. Fixture: %s\n' "$FIXTURE"
