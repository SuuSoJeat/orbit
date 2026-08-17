#!/bin/sh

info() {
    printf '%s\n' "$*"
}

slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//'
}

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

atomic_write() {
    atomic_target=$1
    shift
    [ "$#" -gt 0 ] || return 2
    atomic_directory=${atomic_target%/*}
    [ "$atomic_directory" = "$atomic_target" ] && atomic_directory=.
    atomic_basename=${atomic_target##*/}
    atomic_temp=$(mktemp "${atomic_directory}/.${atomic_basename}.tmp.XXXXXX") \
        || return 1

    if ! "$@" > "$atomic_temp"; then
        /bin/rm -f "$atomic_temp"
        return 1
    fi

    if ! mv "$atomic_temp" "$atomic_target"; then
        /bin/rm -f "$atomic_temp"
        return 1
    fi
}

atomic_write_stdin() {
    atomic_write "$1" cat
}

atomic_copy() {
    atomic_source=$1
    atomic_target=$2
    atomic_directory=${atomic_target%/*}
    [ "$atomic_directory" = "$atomic_target" ] && atomic_directory=.
    atomic_basename=${atomic_target##*/}
    atomic_temp=$(mktemp "${atomic_directory}/.${atomic_basename}.tmp.XXXXXX") \
        || return 1
    if ! cp "$atomic_source" "$atomic_temp"; then
        /bin/rm -f "$atomic_temp"
        return 1
    fi
    if ! mv "$atomic_temp" "$atomic_target"; then
        /bin/rm -f "$atomic_temp"
        return 1
    fi
}
