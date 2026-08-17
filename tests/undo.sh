#!/bin/sh

set -eu

SCRIPT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEST_ROOT=$(CDPATH= cd -- "${SCRIPT_ROOT}/.." && pwd -P)
CLI_ROOT=$TEST_ROOT
# shellcheck disable=SC1091
. "${SCRIPT_ROOT}/lib/test-helpers.sh"

new_fixture

FIRST_ICLOUD="${FIXTURE}/first-icloud"
FIRST_WRAPPER="${FIXTURE}/first-wrapper"
SECOND_ICLOUD="${FIXTURE}/second-icloud"
"$CLI_ROOT/bin/orbit" new "Undo First" \
    --icloud-root "$FIRST_ICLOUD" \
    --with-wrapper \
    --wrapper-root "$FIRST_WRAPPER"
"$CLI_ROOT/bin/orbit" new "Undo Second" --icloud-root "$SECOND_ICLOUD"

CREATION_ROOT="${HOME}/.local/state/orbit/creations"
SECOND_LOG=$(find "$CREATION_ROOT" -type f -name '*undo-second.log' -print | sort | tail -n 1)
[ -n "$SECOND_LOG" ] || fail 'could not find second creation record'
SECOND_SELECTION=$(find "$CREATION_ROOT" -type f -name '*.log' -print | sort \
    | awk -v target="$SECOND_LOG" '$0 == target { print NR; exit }')
printf '%s\ny\n' "$SECOND_SELECTION" | "$CLI_ROOT/bin/orbit" undo
[ ! -e "$SECOND_ICLOUD" ]
[ -d "$FIRST_WRAPPER" ]

REPOSITORY_ROOT="${FIXTURE}/repository"
mkdir -p "$REPOSITORY_ROOT"
git -C "$REPOSITORY_ROOT" init >/dev/null
"$CLI_ROOT/bin/orbit" attach "$FIRST_WRAPPER" "$REPOSITORY_ROOT"

FIRST_LOG=$(find "$CREATION_ROOT" -type f -name '*undo-first.log' -print | sort | tail -n 1)
[ -n "$FIRST_LOG" ] || fail 'could not find first creation record'
FIRST_SELECTION=$(find "$CREATION_ROOT" -type f -name '*.log' -print | sort \
    | awk -v target="$FIRST_LOG" '$0 == target { print NR; exit }')
printf '%s\ny\n' "$FIRST_SELECTION" | "$CLI_ROOT/bin/orbit" undo
[ ! -e "$FIRST_ICLOUD" ]
[ ! -e "$FIRST_WRAPPER" ]

printf 'Undo tests passed.\n'
