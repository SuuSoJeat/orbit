attach_transaction_abort() {
    [ "${ATTACH_TRANSACTION_ACTIVE:-0}" -eq 1 ] || return 0
    ATTACH_TRANSACTION_ACTIVE=0
    attach_rollback_failed=0
    if [ -n "${ATTACH_CREATED_LINKS:-}" ]; then
        while IFS= read -r attach_created_link; do
            [ -n "$attach_created_link" ] || continue
            [ -L "$attach_created_link" ] || continue
            if ! /bin/rm -f "$attach_created_link"; then
                attach_rollback_failed=1
                printf 'ERROR: could not remove created link: %s\n' \
                    "$attach_created_link" >&2
            fi
        done <<EOF
$ATTACH_CREATED_LINKS
EOF
    fi
    if ! atomic_copy "$ATTACH_CONFIG_BACKUP" "$ATTACH_CONFIG_FILE"; then
        attach_rollback_failed=1
        printf 'ERROR: could not restore wrapper configuration: %s\n' \
            "$ATTACH_CONFIG_FILE" >&2
    fi
    if [ "$attach_rollback_failed" -eq 0 ]; then
        /bin/rm -f "$ATTACH_CONFIG_BACKUP"
    else
        printf 'ERROR: recovery backup preserved: %s\n' \
            "$ATTACH_CONFIG_BACKUP" >&2
    fi
    trap - 0 1 2 3 15
}

attach_transaction_commit() {
    ATTACH_TRANSACTION_ACTIVE=0
    ATTACH_CREATED_LINKS=''
    /bin/rm -f "$ATTACH_CONFIG_BACKUP"
    trap - 0 1 2 3 15
}

cmd_attach() {
    case "$#" in
        1)
            wrapper_root=$(infer_wrapper_root)
            repository_path=$1
            ;;
        2)
            wrapper_root=$1
            repository_path=$2
            ;;
        *) die "usage: orbit attach [WRAPPER_ROOT] REPOSITORY_PATH" ;;
    esac
    repository_path=$(physical_dir "$repository_path") \
        || die "repository path is not accessible: ${repository_path}"
    wrapper_contract_validate_attachment "$wrapper_root" "$repository_path"
    ATTACH_CONFIG_FILE=$CONFIG_FILE
    ATTACH_CONFIG_BACKUP=$(mktemp "${ATTACH_CONFIG_FILE}.attach.XXXXXX") \
        || die "could not create attachment backup: ${ATTACH_CONFIG_FILE}"
    if ! cp "$ATTACH_CONFIG_FILE" "$ATTACH_CONFIG_BACKUP"; then
        /bin/rm -f "$ATTACH_CONFIG_BACKUP"
        die "could not back up wrapper configuration: ${ATTACH_CONFIG_FILE}"
    fi
    ATTACH_TRANSACTION_ACTIVE=1
    ATTACH_CREATED_LINKS=''
    trap 'attach_transaction_abort' 0 1 2 3 15
    wrapper_set_config_value repository_path "$repository_path"
    wrapper_ensure_link "$REPO_LINK" "$repository_path" repository
    attach_transaction_commit
    info "Attached repository: ${repository_path}"
}

cmd_doctor() {
    case "$#" in
        0) wrapper_root=$(infer_wrapper_root) ;;
        1) wrapper_root=$1 ;;
        *) die "usage: orbit doctor [WRAPPER_ROOT]" ;;
    esac
    [ -x "$wrapper_root/bin/doctor" ] || die "wrapper doctor not found: ${wrapper_root}"
    "$wrapper_root/bin/doctor"
}

cmd_open() {
    wrapper_root=''
    if [ "$#" -eq 0 ]; then
        wrapper_root=$(infer_wrapper_root)
    else
        case "$1" in
            --dry-run|--launch) wrapper_root=$(infer_wrapper_root) ;;
            *) wrapper_root=$1; shift ;;
        esac
    fi
    load_wrapper_config "$wrapper_root"

    dry_run=1
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=1 ;;
            --launch) dry_run=0 ;;
            -h|--help)
                printf 'Usage: orbit open [WRAPPER_ROOT] [--dry-run|--launch]\n'
                exit 0
                ;;
            *) die "unknown option for open: $1" ;;
        esac
        shift
    done

    printf 'wrapper: %s\n' "$PROJECT_ROOT"
    if [ -n "$REPOSITORY_PATH" ]; then
        printf 'repository: %s\n' "$REPOSITORY_PATH"
    else
        printf 'repository: (not attached yet)\n'
    fi
    printf 'iCloud:    %s\n' "$ICLOUD_PROJECT_PATH"

    if [ "$dry_run" -eq 1 ]; then
        printf '\nDry run only. Use --launch to open Finder, Terminal, and the configured editor.\n'
        return 0
    fi

    command -v open >/dev/null 2>&1 || die "macOS open command is unavailable"
    open "$ICLOUD_PROJECT_LINK"
    open -a Terminal "$PROJECT_ROOT"

    if [ -z "$REPOSITORY_PATH" ]; then
        printf 'Editor not opened: no repository is attached yet.\n' >&2
    elif [ -n "${EDITOR_APP:-}" ]; then
        open -a "$EDITOR_APP" "$REPOSITORY_PATH"
    elif [ -d "/Applications/Visual Studio Code.app" ]; then
        open -a "Visual Studio Code" "$REPOSITORY_PATH"
    elif [ -d "/Applications/Cursor.app" ]; then
        open -a "Cursor" "$REPOSITORY_PATH"
    else
        printf 'Editor not opened: set EDITOR_APP or install Visual Studio Code/Cursor.\n' >&2
    fi
}
