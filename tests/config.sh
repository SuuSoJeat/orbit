#!/bin/sh

set -eu

SCRIPT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEST_ROOT=$(CDPATH= cd -- "${SCRIPT_ROOT}/.." && pwd -P)
CLI_ROOT=$TEST_ROOT
# shellcheck disable=SC1091
. "${SCRIPT_ROOT}/lib/test-helpers.sh"

new_fixture

DEFAULT_HOME="${FIXTURE}/default-home"
DEFAULT_WORKSPACE="${DEFAULT_HOME}/Library/Mobile Documents/com~apple~CloudDocs/iCloud/Workspace"
env -u ORBIT_CONFIG HOME="$DEFAULT_HOME" "$CLI_ROOT/bin/orbit" new "Default Venture" --category ventures
[ -d "$DEFAULT_WORKSPACE/Ventures/Default Venture/Notes" ]

ONE_OFF_ROOT="${FIXTURE}/one-off-icloud-project"
env -u ORBIT_CONFIG HOME="$DEFAULT_HOME" "$CLI_ROOT/bin/orbit" new "One-off Project" --icloud-root "$ONE_OFF_ROOT"
[ -d "$ONE_OFF_ROOT/Notes" ]

if env -u ORBIT_CONFIG HOME="$DEFAULT_HOME" "$CLI_ROOT/bin/orbit" new "Legacy Flag" --cloud-root "$FIXTURE" >/dev/null 2>&1; then
    fail "removed --cloud-root unexpectedly accepted"
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
CONFIG_OUTPUT=$("$CLI_ROOT/bin/orbit" config show)
assert_contains "repository_root: ${REPOSITORIES_ROOT}" "$CONFIG_OUTPUT"

INVALID_CONFIG_FILE="${FIXTURE}/invalid-consumer.conf"
if ORBIT_CONFIG="$INVALID_CONFIG_FILE" "$CLI_ROOT/bin/orbit" config init \
    --repository-root relative >/dev/null 2>&1; then
    fail "relative configuration path unexpectedly accepted"
fi
[ ! -e "$INVALID_CONFIG_FILE" ]

EMPTY_CONFIG_FILE="${FIXTURE}/empty-consumer.conf"
EMPTY_CONFIG_OUTPUT=$(ORBIT_CONFIG="$EMPTY_CONFIG_FILE" "$CLI_ROOT/bin/orbit" config init \
    --companies-root '' \
    --ventures-root "${FIXTURE}/empty-ventures" \
    --repository-root "${FIXTURE}/empty-repositories" >/dev/null \
    && ORBIT_CONFIG="$EMPTY_CONFIG_FILE" "$CLI_ROOT/bin/orbit" config show)
assert_contains 'companies_root: ' "$EMPTY_CONFIG_OUTPUT"

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
PROFILE_OUTPUT=$("$CLI_ROOT/bin/orbit" --config "$PROFILE_CONFIG" config show)
assert_contains "companies_root: ${PROFILE_WORKSPACE}/Companies" "$PROFILE_OUTPUT"

printf 'Configuration tests passed.\n'
