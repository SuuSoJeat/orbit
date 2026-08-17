fail() {
    printf 'TEST FAILURE: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    expected=$1
    actual=$2
    printf '%s\n' "$actual" | grep -F "$expected" >/dev/null \
        || fail "expected output to contain: ${expected}"
}

assert_not_contains() {
    unexpected=$1
    actual=$2
    if printf '%s\n' "$actual" | grep -F "$unexpected" >/dev/null; then
        fail "expected output not to contain: ${unexpected}"
    fi
}

new_fixture() {
    FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/orbit-test.XXXXXX")
    FIXTURE_HOME="${FIXTURE}/home"
    export HOME="$FIXTURE_HOME"
    unset ORBIT_CONFIG XDG_CONFIG_HOME
    trap '/bin/rm -rf "$FIXTURE"' EXIT HUP INT TERM
}
