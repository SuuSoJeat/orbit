orbit_state_root() {
    if [ -n "${XDG_STATE_HOME:-}" ]; then
        printf '%s/orbit\n' "$XDG_STATE_HOME"
    else
        printf '%s/.local/state/orbit\n' "$HOME"
    fi
}

creation_begin() {
    creation_project_name=$1
    creation_root="$(orbit_state_root)/creations"
    mkdir -p "$creation_root"
    creation_stamp=$(date '+%Y%m%d-%H%M%S')
    creation_slug=$(slugify "$creation_project_name")
    creation_path="${creation_root}/${creation_stamp}-${creation_slug}.log"
    creation_number=1
    while [ -e "$creation_path" ]; do
        creation_number=$((creation_number + 1))
        creation_path="${creation_root}/${creation_stamp}-${creation_slug}-${creation_number}.log"
    done
    CREATION_LOG=$creation_path
    {
        printf 'format\t2\n'
        printf 'timestamp\t%s\n' "$creation_stamp"
        printf 'project\t%s\n' "$creation_project_name"
        printf 'status\tin-progress\n'
    } > "$CREATION_LOG"
    CREATION_TRANSACTION_ACTIVE=1
    trap 'creation_abort' 0 1 2 3 15
}

creation_record_command() {
    [ -n "${CREATION_LOG:-}" ] || return 0
    printf 'command\t%s\n' "$*" >> "$CREATION_LOG"
}

creation_record_root() {
    [ -n "${CREATION_LOG:-}" ] || return 0
    printf 'root\t%s\n' "$1" >> "$CREATION_LOG"
}

creation_scope_root() {
    scope_path=$1
    while [ ! -d "$scope_path" ]; do
        [ "$scope_path" = "/" ] && break
        scope_path=${scope_path%/*}
        [ -n "$scope_path" ] || scope_path=/
    done
    printf '%s\n' "$scope_path"
}

creation_record_path() {
    [ -n "${CREATION_LOG:-}" ] || return 0
    path_to_record=$1
    if ! awk -F '\t' -v target="$path_to_record" \
        '$1 == "path" && $2 == target { found = 1 } END { exit found ? 0 : 1 }' \
        "$CREATION_LOG"; then
        printf 'path\t%s\n' "$path_to_record" >> "$CREATION_LOG"
    fi
}

creation_record_tree() {
    tree_root=$1
    find "$tree_root" -mindepth 1 -print 2>/dev/null \
        | while IFS= read -r tree_path; do
            creation_record_path "$tree_path"
        done
}

creation_ensure_directory() {
    directory_path=$1
    [ -d "$directory_path" ] && return 0
    [ ! -e "$directory_path" ] && [ ! -L "$directory_path" ] \
        || die "cannot create directory; path is not a directory: ${directory_path}"

    parent_path=${directory_path%/*}
    if [ -n "$parent_path" ] && [ "$parent_path" != "$directory_path" ] && [ ! -d "$parent_path" ]; then
        ( creation_ensure_directory "$parent_path" )
    fi
    creation_record_command "mkdir $(shell_quote "$directory_path")"
    mkdir "$directory_path"
    creation_record_path "$directory_path"
}

creation_rollback_paths() {
    rollback_log=$1
    rollback_paths_file=$(mktemp "${TMPDIR:-/tmp}/orbit-rollback-paths.XXXXXX") \
        || return 1
    rollback_roots_file=$(mktemp "${TMPDIR:-/tmp}/orbit-rollback-roots.XXXXXX") \
        || {
            /bin/rm -f "$rollback_paths_file"
            return 1
        }
    awk -F '\t' '$1 == "path" { print length($2) "\t" $2 }' "$rollback_log" \
        | sort -rn > "$rollback_paths_file"
    awk -F '\t' '$1 == "root" { print $2 }' "$rollback_log" > "$rollback_roots_file"

    rollback_root_count=$(wc -l < "$rollback_roots_file" | tr -d ' ')
    if [ "$rollback_root_count" -eq 0 ]; then
        /bin/rm -f "$rollback_paths_file" "$rollback_roots_file"
        return 1
    fi

    rollback_failed=0
    printf '\nDeleting recorded paths:\n'
    while IFS="$(printf '\t')" read -r path_length path_to_remove; do
        [ -n "$path_to_remove" ] || continue
        case "$path_to_remove" in
            *'/../'*|*'/..'|../*)
                printf 'ERROR: refusing to remove unresolved recorded path: %s\n' \
                    "$path_to_remove" >&2
                rollback_failed=1
                continue
                ;;
        esac
        authorized=0
        while IFS= read -r allowed_root; do
            [ -n "$allowed_root" ] || continue
            case "$path_to_remove" in
                "$allowed_root"|"$allowed_root"/*)
                    authorized=1
                    break
                    ;;
            esac
        done < "$rollback_roots_file"
        if [ "$authorized" -ne 1 ]; then
            printf 'ERROR: refusing to remove path outside recorded roots: %s\n' \
                "$path_to_remove" >&2
            rollback_failed=1
            continue
        fi
        if [ -L "$path_to_remove" ]; then
            if /bin/rm -f "$path_to_remove"; then
                info "  deleted symlink: ${path_to_remove}"
            else
                printf 'ERROR: could not delete symlink: %s\n' "$path_to_remove" >&2
                rollback_failed=1
            fi
        elif [ -f "$path_to_remove" ]; then
            if /bin/rm -f "$path_to_remove"; then
                info "  deleted file: ${path_to_remove}"
            else
                printf 'ERROR: could not delete file: %s\n' "$path_to_remove" >&2
                rollback_failed=1
            fi
        elif [ -d "$path_to_remove" ]; then
            if /bin/rm -rf "$path_to_remove"; then
                info "  deleted directory recursively: ${path_to_remove}"
            else
                printf 'ERROR: could not delete directory: %s\n' "$path_to_remove" >&2
                rollback_failed=1
            fi
        else
            info "  already absent: ${path_to_remove}"
        fi
    done < "$rollback_paths_file"

    /bin/rm -f "$rollback_paths_file" "$rollback_roots_file"
    [ "$rollback_failed" -eq 0 ]
}

creation_abort() {
    [ "${CREATION_TRANSACTION_ACTIVE:-0}" -eq 1 ] || return 0
    CREATION_TRANSACTION_ACTIVE=0
    if creation_rollback_paths "$CREATION_LOG"; then
        if /bin/rm -f "$CREATION_LOG"; then
            info "Creation failed; rolled back recorded paths."
        else
            printf 'ERROR: rollback completed but creation journal could not be removed: %s\n' \
                "$CREATION_LOG" >&2
        fi
    else
        printf 'ERROR: creation rollback was incomplete; journal preserved: %s\n' \
            "$CREATION_LOG" >&2
    fi
    trap - 0 1 2 3 15
}

creation_commit() {
    printf 'status\tcomplete\n' >> "$CREATION_LOG"
    CREATION_TRANSACTION_ACTIVE=0
    trap - 0 1 2 3 15
}
