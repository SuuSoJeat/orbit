#!/bin/sh

set -eu

CLI_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
FIXTURE=$(mktemp -d /private/tmp/studio-test.XXXXXX)
FIXTURE_HOME="${FIXTURE}/home"
export HOME="$FIXTURE_HOME"

for script in "$CLI_ROOT/bin/studio" "$CLI_ROOT/templates/wrapper/bin"/*; do
    sh -n "$script"
done

"$CLI_ROOT/bin/studio" new "Acme Demo" --category companies --with-wrapper
WRAPPER_ROOT="${HOME}/Repositories/personal/acme-demo-context"
CLOUD_ROOT="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/SuuSoJeat/Career/Companies/Acme Demo"

[ -d "$CLOUD_ROOT/Notes" ]
[ -L "$WRAPPER_ROOT/remote/iCloud" ]
"$CLI_ROOT/bin/studio" doctor "$WRAPPER_ROOT"

REPOSITORY_ROOT="${HOME}/Repositories/Acme/product"
mkdir -p "$REPOSITORY_ROOT"
git -C "$REPOSITORY_ROOT" init >/dev/null
"$CLI_ROOT/bin/studio" attach "$WRAPPER_ROOT" "$REPOSITORY_ROOT"
[ -L "$WRAPPER_ROOT/local/repo" ]
"$CLI_ROOT/bin/studio" doctor "$WRAPPER_ROOT"

printf 'Studio CLI smoke test passed. Fixture: %s\n' "$FIXTURE"
