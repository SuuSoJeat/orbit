#!/bin/sh

set -eu

SCRIPT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEST_ROOT=$(CDPATH= cd -- "${SCRIPT_ROOT}/.." && pwd -P)
CLI_ROOT=$TEST_ROOT
# shellcheck disable=SC1091
. "${SCRIPT_ROOT}/lib/test-helpers.sh"

new_fixture

CONFIG_FILE="${FIXTURE}/consumer.conf"
COMPANIES_ROOT="${FIXTURE}/icloud/Alice/Career/Companies"
VENTURES_ROOT="${FIXTURE}/icloud/Alice/Ventures/Software"
REPOSITORIES_ROOT="${FIXTURE_HOME}/repositories"
export ORBIT_CONFIG="$CONFIG_FILE"
"$CLI_ROOT/bin/orbit" config init \
    --companies-root "$COMPANIES_ROOT" \
    --ventures-root "$VENTURES_ROOT" \
    --repository-root "~/repositories"

printf '1\nExample Company\n1\nExample Client\n1\n' \
    | "$CLI_ROOT/bin/orbit" new "Example Project Platform"
WRAPPER_ROOT="${REPOSITORIES_ROOT}/example-project-platform-orbit"
ICLOUD_PROJECT_PATH="${COMPANIES_ROOT}/Example Company/Clients/Example Client/Example Project Platform"

[ -d "$ICLOUD_PROJECT_PATH/Notes" ]
[ -f "$WRAPPER_ROOT/config/orbit.conf" ]
[ -f "$WRAPPER_ROOT/bin/lib.sh" ]
cmp "$CLI_ROOT/bin/lib/wrapper_runtime.sh" "$WRAPPER_ROOT/bin/lib.sh"
[ -f "$WRAPPER_ROOT/bin/contract.sh" ]
cmp "$CLI_ROOT/bin/lib/wrapper_contract.sh" "$WRAPPER_ROOT/bin/contract.sh"
[ ! -e "$WRAPPER_ROOT/config/project.env" ]
[ -L "$WRAPPER_ROOT/remote/iCloud" ]
grep -F "project_name = Example Project Platform" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
grep -F "icloud_project_path = ${ICLOUD_PROJECT_PATH}" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
"$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT"

/bin/rm "$WRAPPER_ROOT/bin/contract.sh"
if DOCTOR_OUTPUT=$("$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT" 2>&1); then
    fail "doctor unexpectedly used the source checkout runtime"
fi
WRAPPER_PHYSICAL=$(CDPATH= cd -P -- "$WRAPPER_ROOT" && pwd -P)
assert_contains "missing ${WRAPPER_PHYSICAL}/bin/contract.sh" "$DOCTOR_OUTPUT"
cp "$CLI_ROOT/bin/lib/wrapper_contract.sh" "$WRAPPER_ROOT/bin/contract.sh"

mkdir -p "$WRAPPER_ROOT/PrivateNotes"
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" doctor)
OPEN_OUTPUT=$(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" open --dry-run)
assert_contains 'repository: (not attached yet)' "$OPEN_OUTPUT"
assert_contains "iCloud:    ${ICLOUD_PROJECT_PATH}" "$OPEN_OUTPUT"

if "$CLI_ROOT/bin/orbit" attach "$WRAPPER_ROOT" "${FIXTURE}/missing-repository" >/dev/null 2>&1; then
    fail "missing repository unexpectedly attached"
fi
assert_not_contains "repository_path = ${FIXTURE}/missing-repository" \
    "$(cat "$WRAPPER_ROOT/config/orbit.conf")"

REPOSITORY_ROOT="${REPOSITORIES_ROOT}/Acme/product"
mkdir -p "$REPOSITORY_ROOT"
git -C "$REPOSITORY_ROOT" init >/dev/null
REPOSITORY_PHYSICAL=$(CDPATH= cd -P -- "$REPOSITORY_ROOT" && pwd -P)
"$CLI_ROOT/bin/orbit" attach "$WRAPPER_ROOT" "$REPOSITORY_ROOT"
[ -L "$WRAPPER_ROOT/local/repo" ]
grep -F "repository_path = ${REPOSITORY_PHYSICAL}" "$WRAPPER_ROOT/config/orbit.conf" >/dev/null
"$CLI_ROOT/bin/orbit" doctor "$WRAPPER_ROOT"
(cd "$WRAPPER_ROOT/PrivateNotes" && "$CLI_ROOT/bin/orbit" attach "$REPOSITORY_ROOT")

CONFLICT_ICLOUD="${FIXTURE}/conflict-icloud"
CONFLICT_WRAPPER="${FIXTURE}/conflict-wrapper"
"$CLI_ROOT/bin/orbit" new "Conflict Project" \
    --icloud-root "$CONFLICT_ICLOUD" \
    --with-wrapper \
    --wrapper-root "$CONFLICT_WRAPPER"
CONFLICT_REPOSITORY="${FIXTURE}/conflict-repository"
mkdir -p "$CONFLICT_REPOSITORY"
git -C "$CONFLICT_REPOSITORY" init >/dev/null
/bin/rm "$CONFLICT_WRAPPER/remote/iCloud"
touch "$CONFLICT_WRAPPER/remote/iCloud"
if "$CLI_ROOT/bin/orbit" attach "$CONFLICT_WRAPPER" "$CONFLICT_REPOSITORY" >/dev/null 2>&1; then
    fail "attachment unexpectedly replaced a conflicting boundary file"
fi
assert_not_contains "repository_path = ${CONFLICT_REPOSITORY}" \
    "$(cat "$CONFLICT_WRAPPER/config/orbit.conf")"

NESTED_ICLOUD="${FIXTURE}/nested-icloud"
NESTED_WRAPPER="${FIXTURE}/nested-wrapper"
"$CLI_ROOT/bin/orbit" new "Nested Repository Project" \
    --icloud-root "$NESTED_ICLOUD" \
    --with-wrapper \
    --wrapper-root "$NESTED_WRAPPER"
NESTED_REPOSITORY="${NESTED_WRAPPER}/nested-repository"
mkdir -p "$NESTED_REPOSITORY"
git -C "$NESTED_REPOSITORY" init >/dev/null
if "$CLI_ROOT/bin/orbit" attach "$NESTED_WRAPPER" "$NESTED_REPOSITORY" >/dev/null 2>&1; then
    fail "repository inside wrapper unexpectedly attached"
fi
assert_not_contains "repository_path = ${NESTED_REPOSITORY}" \
    "$(cat "$NESTED_WRAPPER/config/orbit.conf")"
[ ! -L "$NESTED_WRAPPER/local/repo" ]
"$CLI_ROOT/bin/orbit" doctor "$NESTED_WRAPPER"

INCOMPLETE_ICLOUD="${FIXTURE}/incomplete-icloud"
INCOMPLETE_WRAPPER="${FIXTURE}/incomplete-wrapper"
INCOMPLETE_REPOSITORY="${FIXTURE}/incomplete-repository"
"$CLI_ROOT/bin/orbit" new "Incomplete Wrapper Project" \
    --icloud-root "$INCOMPLETE_ICLOUD" \
    --with-wrapper \
    --wrapper-root "$INCOMPLETE_WRAPPER"
mkdir -p "$INCOMPLETE_REPOSITORY"
git -C "$INCOMPLETE_REPOSITORY" init >/dev/null
/bin/rm -rf "$INCOMPLETE_WRAPPER/local"
if "$CLI_ROOT/bin/orbit" attach "$INCOMPLETE_WRAPPER" "$INCOMPLETE_REPOSITORY" >/dev/null 2>&1; then
    fail "incomplete wrapper unexpectedly attached"
fi
assert_not_contains "repository_path = ${INCOMPLETE_REPOSITORY}" \
    "$(cat "$INCOMPLETE_WRAPPER/config/orbit.conf")"
[ ! -e "$INCOMPLETE_WRAPPER/local" ]

ROLLBACK_ICLOUD="${FIXTURE}/rollback-icloud"
ROLLBACK_WRAPPER="${FIXTURE}/rollback-wrapper"
ROLLBACK_REPOSITORY="${FIXTURE}/rollback-repository"
"$CLI_ROOT/bin/orbit" new "Rollback Project" \
    --icloud-root "$ROLLBACK_ICLOUD" \
    --with-wrapper \
    --wrapper-root "$ROLLBACK_WRAPPER"
mkdir -p "$ROLLBACK_REPOSITORY"
git -C "$ROLLBACK_REPOSITORY" init >/dev/null
FAIL_BIN="${FIXTURE}/fail-bin"
mkdir -p "$FAIL_BIN"
cat > "$FAIL_BIN/ln" <<'EOF'
#!/bin/sh
case "$3" in
    */local/repo) exit 1 ;;
esac
exec /bin/ln "$@"
EOF
chmod 755 "$FAIL_BIN/ln"
if PATH="$FAIL_BIN:$PATH" "$CLI_ROOT/bin/orbit" attach \
    "$ROLLBACK_WRAPPER" "$ROLLBACK_REPOSITORY" >/dev/null 2>&1; then
    fail "injected attachment failure unexpectedly succeeded"
fi
assert_not_contains "repository_path = ${ROLLBACK_REPOSITORY}" \
    "$(cat "$ROLLBACK_WRAPPER/config/orbit.conf")"
[ -L "$ROLLBACK_WRAPPER/remote/iCloud" ]
[ ! -L "$ROLLBACK_WRAPPER/local/repo" ]

RECOVERY_ICLOUD="${FIXTURE}/recovery-icloud"
RECOVERY_WRAPPER="${FIXTURE}/recovery-wrapper"
RECOVERY_REPOSITORY="${FIXTURE}/recovery-repository"
"$CLI_ROOT/bin/orbit" new "Recovery Project" \
    --icloud-root "$RECOVERY_ICLOUD" \
    --with-wrapper \
    --wrapper-root "$RECOVERY_WRAPPER"
mkdir -p "$RECOVERY_REPOSITORY"
git -C "$RECOVERY_REPOSITORY" init >/dev/null
RECOVERY_REPOSITORY_PHYSICAL=$(CDPATH= cd -P -- "$RECOVERY_REPOSITORY" && pwd -P)
cp "$RECOVERY_WRAPPER/config/orbit.conf" "$RECOVERY_WRAPPER/config.before"

RECOVERY_BIN="${FIXTURE}/recovery-bin"
RECOVERY_MV_STATE="${FIXTURE}/recovery-mv-state"
mkdir -p "$RECOVERY_BIN"
cat > "$RECOVERY_BIN/ln" <<'EOF'
#!/bin/sh
case "$3" in
    */local/repo) exit 1 ;;
esac
exec /bin/ln "$@"
EOF
cat > "$RECOVERY_BIN/mv" <<EOF
#!/bin/sh
if [ ! -e "$RECOVERY_MV_STATE" ]; then
    : > "$RECOVERY_MV_STATE"
    exec /bin/mv "\$@"
fi
exit 1
EOF
chmod 755 "$RECOVERY_BIN/ln" "$RECOVERY_BIN/mv"
if RECOVERY_OUTPUT=$(PATH="$RECOVERY_BIN:$PATH" "$CLI_ROOT/bin/orbit" attach \
    "$RECOVERY_WRAPPER" "$RECOVERY_REPOSITORY" 2>&1); then
    fail "attachment with failed rollback unexpectedly succeeded"
fi
assert_contains 'recovery backup preserved:' "$RECOVERY_OUTPUT"
assert_contains "repository_path = ${RECOVERY_REPOSITORY_PHYSICAL}" \
    "$(cat "$RECOVERY_WRAPPER/config/orbit.conf")"
[ ! -L "$RECOVERY_WRAPPER/local/repo" ]
RECOVERY_BACKUP=$(find "$RECOVERY_WRAPPER/config" -maxdepth 1 \
    -type f -name 'orbit.conf.attach.*' -print)
[ -n "$RECOVERY_BACKUP" ] || fail 'rollback backup was not preserved'
cmp "$RECOVERY_WRAPPER/config.before" "$RECOVERY_BACKUP"

printf 'Wrapper tests passed.\n'
