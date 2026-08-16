#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
export PROJECT_ROOT

CONFIG_FILE="${PROJECT_ROOT}/config/project.env"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        die "missing ${CONFIG_FILE}; run ./bin/bootstrap first"
    fi

    # The config is a local file created from the tracked template. It contains
    # paths only; it is never intended to hold credentials or secrets.
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"

    : "${PROJECT_NAME:?PROJECT_NAME is required in ${CONFIG_FILE}}"
    : "${COMPANY_REPO:=}"
    : "${CLOUD_ROOT:?CLOUD_ROOT is required in ${CONFIG_FILE}}"
    : "${CLOUD_LINK:=${PROJECT_ROOT}/remote/iCloud}"
    : "${REPO_LINK:=${PROJECT_ROOT}/local/repo}"

    export PROJECT_NAME COMPANY_REPO CLOUD_ROOT CLOUD_LINK REPO_LINK
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
