#!/bin/sh

set -eu

SCRIPT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEST_ROOT=$(CDPATH= cd -- "${SCRIPT_ROOT}/.." && pwd -P)

for test_script in config.sh wrapper.sh creation.sh undo.sh template.sh; do
    "${TEST_ROOT}/tests/${test_script}"
done

printf 'Orbit CLI smoke test passed.\n'
