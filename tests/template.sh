#!/bin/sh

set -eu

SCRIPT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEST_ROOT=$(CDPATH= cd -- "${SCRIPT_ROOT}/.." && pwd -P)
# shellcheck disable=SC1091
. "${SCRIPT_ROOT}/lib/test-helpers.sh"

new_fixture

TEMPLATE_OUTPUT=$("${TEST_ROOT}/templates/wrapper/bin/doctor" 2>&1 || true)
assert_contains "missing ${TEST_ROOT}/templates/wrapper/bin/lib.sh" "$TEMPLATE_OUTPUT"
assert_not_contains "source checkout" "$TEMPLATE_OUTPUT"

printf 'Template runtime test passed.\n'
