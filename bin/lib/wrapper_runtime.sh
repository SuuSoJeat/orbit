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

config_repository_entries() {
    config_file=$1
    awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        function emit_section() {
            if (section_name != "" && section_path != "") {
                print section_name "\t" section_path
            }
        }
        function emit_legacy(value, name) {
            value = trim(value)
            if (value == "") return
            name = value
            sub(/^.*\//, "", name)
            print name "\t" value
        }
        {
            line = $0
            sub(/^[[:space:]]*/, "", line)
            if (line == "" || substr(line, 1, 1) == "#") next
            if (line ~ /^\[repository[[:space:]]+"[^"]+"[[:space:]]*\]$/) {
                emit_section()
                section_name = line
                sub(/^\[repository[[:space:]]+"/, "", section_name)
                sub(/"[[:space:]]*\]$/, "", section_name)
                section_path = ""
                next
            }
            if (substr(line, 1, 1) == "[") {
                emit_section()
                section_name = ""
                section_path = ""
                next
            }
            separator = index(line, "=")
            if (separator == 0) next
            key = trim(substr(line, 1, separator - 1))
            value = trim(substr(line, separator + 1))
            if (section_name != "") {
                if (key == "path") section_path = value
            } else if (key == "repository_path") {
                emit_legacy(value)
            }
        }
        END { emit_section() }
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
    REPOSITORY_ENTRIES=$(config_repository_entries "$CONFIG_FILE")
    REPOSITORY_PATHS=$(printf '%s\n' "$REPOSITORY_ENTRIES" \
        | awk -F '\t' 'NF >= 2 { print $2 }')
    REPOSITORY_PATH=$(printf '%s\n' "$REPOSITORY_PATHS" | sed -n '1p')
    ICLOUD_PROJECT_LINK="${PROJECT_ROOT}/remote/iCloud"
    REPO_LINK="${PROJECT_ROOT}/local/repo"

    export PROJECT_NAME REPOSITORY_PATH REPOSITORY_PATHS REPOSITORY_ENTRIES
    export ICLOUD_PROJECT_PATH
    export ICLOUD_PROJECT_LINK REPO_LINK
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

repository_link_name() {
    repository_link_name_path=$1
    basename -- "$repository_link_name_path"
}

repository_name_is_valid() {
    case "$1" in
        ''|.|..|*/*|*\"*|*\\*) return 1 ;;
        *) return 0 ;;
    esac
}

repository_name_for_path() {
    repository_name_path=$1
    while IFS="$(printf '\t')" read -r repository_entry_name repository_entry_path; do
        [ "$repository_entry_path" = "$repository_name_path" ] || continue
        printf '%s\n' "$repository_entry_name"
        return 0
    done <<EOF
$REPOSITORY_ENTRIES
EOF
    repository_link_name "$repository_name_path"
}

repository_path_for_name() {
    repository_path_name=$1
    while IFS="$(printf '\t')" read -r repository_entry_name repository_entry_path; do
        [ "$repository_entry_name" = "$repository_path_name" ] || continue
        printf '%s\n' "$repository_entry_path"
        return 0
    done <<EOF
$REPOSITORY_ENTRIES
EOF
    return 1
}

repository_path_is_configured() {
    repository_path_to_check=$1
    while IFS="$(printf '\t')" read -r repository_entry_name repository_entry_path; do
        [ "$repository_entry_path" = "$repository_path_to_check" ] || continue
        return 0
    done <<EOF
$REPOSITORY_ENTRIES
EOF
    return 1
}

repository_link_path() {
    printf '%s/%s\n' "$REPO_LINK" "$(repository_name_for_path "$1")"
}

check_result() {
    if "$@"; then
        printf 'OK   %s\n' "${CHECK_LABEL}"
        return 0
    fi

    printf 'FAIL %s\n' "${CHECK_LABEL}"
    return 1
}
