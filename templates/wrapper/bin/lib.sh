#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
export PROJECT_ROOT

CONFIG_FILE="${PROJECT_ROOT}/config/orbit.conf"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        die "missing ${CONFIG_FILE}; create the wrapper with orbit new"
    fi

    config_value() {
        config_key=$1
        awk -v wanted="$config_key" '
            function trim(value) {
                sub(/^[[:space:]]+/, "", value)
                sub(/[[:space:]]+$/, "", value)
                return value
            }
            {
                line = $0
                sub(/^[[:space:]]*/, "", line)
                if (line == "" || substr(line, 1, 1) == "#") next
                separator = index(line, "=")
                if (separator == 0) next
                key = trim(substr(line, 1, separator - 1))
                if (key == wanted) {
                    print trim(substr(line, separator + 1))
                    found = 1
                    exit
                }
            }
            END { if (!found) exit 1 }
        ' "$CONFIG_FILE"
    }

    PROJECT_NAME=$(config_value project_name) \
        || die "project_name is required in ${CONFIG_FILE}"
    ICLOUD_PROJECT_PATH=$(config_value icloud_project_path) \
        || die "icloud_project_path is required in ${CONFIG_FILE}"
    REPOSITORY_PATH=''
    if REPOSITORY_PATH=$(config_value repository_path); then
        :
    fi
    ICLOUD_PROJECT_LINK="${PROJECT_ROOT}/remote/iCloud"
    REPO_LINK="${PROJECT_ROOT}/local/repo"

    export PROJECT_NAME REPOSITORY_PATH ICLOUD_PROJECT_PATH ICLOUD_PROJECT_LINK REPO_LINK
}

relative_to_root() {
    case "$1" in
        "${PROJECT_ROOT}"/*) printf '%s\n' "${1#${PROJECT_ROOT}/}" ;;
        *) return 1 ;;
    esac
}

physical_dir() {
    CDPATH= cd -P -- "$1" && pwd -P
}

check_result() {
    if "$@"; then
        printf 'OK   %s\n' "${CHECK_LABEL}"
        return 0
    fi

    printf 'FAIL %s\n' "${CHECK_LABEL}"
    return 1
}
