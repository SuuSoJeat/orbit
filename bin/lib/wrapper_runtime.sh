#!/bin/sh

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

config_value() {
    config_key=$1
    config_file=$2
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
    ' "$config_file"
}

load_wrapper_config() {
    PROJECT_ROOT=$1
    CONFIG_FILE="${PROJECT_ROOT}/config/orbit.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        die "missing ${CONFIG_FILE}; create the wrapper with orbit new"
    fi

    PROJECT_NAME=$(config_value project_name "$CONFIG_FILE") \
        || die "project_name is required in ${CONFIG_FILE}"
    ICLOUD_PROJECT_PATH=$(config_value icloud_project_path "$CONFIG_FILE") \
        || die "icloud_project_path is required in ${CONFIG_FILE}"
    REPOSITORY_PATH=''
    if REPOSITORY_PATH=$(config_value repository_path "$CONFIG_FILE"); then
        :
    fi
    ICLOUD_PROJECT_LINK="${PROJECT_ROOT}/remote/iCloud"
    REPO_LINK="${PROJECT_ROOT}/local/repo"

    export PROJECT_NAME REPOSITORY_PATH ICLOUD_PROJECT_PATH ICLOUD_PROJECT_LINK REPO_LINK
}

is_git_repository() {
    repository_path=$1
    [ -d "$repository_path" ] || return 1
    repository_top=$(git -C "$repository_path" rev-parse --show-toplevel 2>/dev/null) || return 1
    repository_physical=$(physical_dir "$repository_path") || return 1
    [ "$repository_top" = "$repository_physical" ]
}

physical_dir() {
    CDPATH= cd -P -- "$1" && pwd -P
}

path_is_outside() {
    candidate_path=$1
    root_path=$2
    candidate_physical=$(physical_dir "$candidate_path") || return 1
    root_physical=$(physical_dir "$root_path") || return 1
    case "$candidate_physical/" in
        "$root_physical"/*) return 1 ;;
        *) return 0 ;;
    esac
}

relative_to_root() {
    case "$1" in
        "${PROJECT_ROOT}"/*) printf '%s\n' "${1#${PROJECT_ROOT}/}" ;;
        *) return 1 ;;
    esac
}

check_result() {
    if "$@"; then
        printf 'OK   %s\n' "${CHECK_LABEL}"
        return 0
    fi

    printf 'FAIL %s\n' "${CHECK_LABEL}"
    return 1
}
