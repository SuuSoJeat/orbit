#!/bin/sh

set -eu

SCRIPT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEST_ROOT=$(CDPATH= cd -- "${SCRIPT_ROOT}/.." && pwd -P)
CLI_ROOT=$TEST_ROOT
# shellcheck disable=SC1091
. "${SCRIPT_ROOT}/lib/test-helpers.sh"

new_fixture

ICLOUD_ROOT="${FIXTURE}/failed-icloud"
WRAPPER_ROOT="${FIXTURE}/failed-wrapper"
FAIL_BIN="${FIXTURE}/fail-bin"
mkdir -p "$FAIL_BIN"
cat > "$FAIL_BIN/git" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$FAIL_BIN/git"

if CREATION_OUTPUT=$(PATH="$FAIL_BIN:$PATH" "$CLI_ROOT/bin/orbit" new \
    "Failed New" \
    --icloud-root "$ICLOUD_ROOT" \
    --with-wrapper \
    --wrapper-root "$WRAPPER_ROOT" 2>&1); then
    fail "failed project creation unexpectedly succeeded"
fi

assert_contains 'Creation failed; rolled back recorded paths.' "$CREATION_OUTPUT"
[ ! -e "$ICLOUD_ROOT" ] || fail 'automatic rollback left the iCloud project behind'
[ ! -e "$WRAPPER_ROOT" ] || fail 'automatic rollback left the wrapper behind'

CREATION_ROOT="${HOME}/.local/state/orbit/creations"
if find "$CREATION_ROOT" -type f -name '*failed-new.log' -print | grep . >/dev/null; then
    fail 'automatic rollback left an incomplete creation journal'
fi

printf 'Creation transaction tests passed.\n'
