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
    if [ "${ATTACH_CREATED_REPO_DIRECTORY:-0}" -eq 1 ] && [ -d "$ATTACH_REPO_DIRECTORY" ]; then
        if ! rmdir "$ATTACH_REPO_DIRECTORY" 2>/dev/null; then
            attach_rollback_failed=1
            printf 'ERROR: could not remove created repository link directory: %s\n' \
                "$ATTACH_REPO_DIRECTORY" >&2
        fi
    fi
    if [ -n "${ATTACH_LEGACY_REPO_TARGET:-}" ] && [ ! -e "$ATTACH_REPO_DIRECTORY" ]; then
        if ! /bin/ln -s "$ATTACH_LEGACY_REPO_TARGET" "$ATTACH_REPO_DIRECTORY"; then
            attach_rollback_failed=1
            printf 'ERROR: could not restore legacy repository link: %s\n' \
                "$ATTACH_REPO_DIRECTORY" >&2
        fi
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
    [ "$#" -gt 0 ] || die "usage: orbit attach [WRAPPER_ROOT] REPOSITORY_PATH..."
    if [ "$#" -gt 1 ] && wrapper_root_is_valid "$1"; then
        wrapper_root=$1
        shift
    else
        wrapper_root=$(infer_wrapper_root)
    fi
    [ "$#" -gt 0 ] || die "usage: orbit attach [WRAPPER_ROOT] REPOSITORY_PATH..."

    attach_name=''
    attach_repository_paths=''
    attach_repository_count=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name)
                shift
                [ "$#" -gt 0 ] || die "--name requires a name"
                repository_name_is_valid "$1" \
                    || die "repository name must be a single directory name: $1"
                [ -z "$attach_name" ] || die "--name may be specified only once"
                attach_name=$1
                ;;
            -*) die "unknown attach option: $1" ;;
            *)
                repository_path=$(physical_dir "$1") \
                    || die "repository path is not accessible: $1"
                wrapper_contract_validate_attachment "$wrapper_root" "$repository_path"
                attach_repository_count=$((attach_repository_count + 1))
                if [ -n "$attach_repository_paths" ]; then
                    attach_repository_paths="${attach_repository_paths}
${repository_path}"
                else
                    attach_repository_paths=$repository_path
                fi
                ;;
        esac
        shift
    done
    [ "$attach_repository_count" -gt 0 ] || die "usage: orbit attach [WRAPPER_ROOT] REPOSITORY_PATH..."
    [ -z "$attach_name" ] || [ "$attach_repository_count" -eq 1 ] \
        || die "--name can be used with one repository at a time"

    ATTACH_CONFIG_FILE=$CONFIG_FILE
    ATTACH_CONFIG_BACKUP=$(mktemp "${ATTACH_CONFIG_FILE}.attach.XXXXXX") \
        || die "could not create attachment backup: ${ATTACH_CONFIG_FILE}"
    if ! cp "$ATTACH_CONFIG_FILE" "$ATTACH_CONFIG_BACKUP"; then
        /bin/rm -f "$ATTACH_CONFIG_BACKUP"
        die "could not back up wrapper configuration: ${ATTACH_CONFIG_FILE}"
    fi
    ATTACH_TRANSACTION_ACTIVE=1
    ATTACH_CREATED_LINKS=''
    ATTACH_LEGACY_REPO_TARGET=''
    ATTACH_REPO_DIRECTORY="${wrapper_root}/local/repo"
    ATTACH_CREATED_REPO_DIRECTORY=0
    trap 'attach_transaction_abort' 0 1 2 3 15
    while IFS= read -r repository_path; do
        [ -n "$repository_path" ] || continue
        attach_current_repository_path=$repository_path
        if [ -n "$attach_name" ]; then
            attach_current_repository_name=$attach_name
        else
            attach_current_repository_name=$(repository_link_name "$attach_current_repository_path")
            repository_name_is_valid "$attach_current_repository_name" \
                || die "repository folder name cannot be used as an attachment name: ${attach_current_repository_name}"
        fi
        wrapper_add_repository_entry \
            "$attach_current_repository_name" "$attach_current_repository_path"
        load_wrapper_config "$wrapper_root"
        if [ -L "$REPO_LINK" ]; then
            ATTACH_LEGACY_REPO_TARGET=$(readlink "$REPO_LINK")
            /bin/rm "$REPO_LINK" || die "could not migrate legacy repository link: ${REPO_LINK}"
        fi
        if [ -L "$REPO_LINK" ]; then
            die "repository link boundary is a symlink; cannot attach multiple repositories: ${REPO_LINK}"
        fi
        if [ ! -e "$REPO_LINK" ]; then
            ATTACH_CREATED_REPO_DIRECTORY=1
        fi
        ensure_directory "$REPO_LINK"
        wrapper_ensure_repository_links
        info "Attached repository: ${attach_current_repository_path} as ${attach_current_repository_name}"
    done <<EOF
$attach_repository_paths
EOF
    attach_transaction_commit
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
    if [ -n "$REPOSITORY_PATHS" ]; then
        while IFS= read -r repository_path; do
            [ -n "$repository_path" ] || continue
            printf 'repository: %s\n' "$repository_path"
        done <<EOF
$REPOSITORY_PATHS
EOF
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

    if [ -z "$REPOSITORY_PATHS" ]; then
        printf 'Editor not opened: no repository is attached yet.\n' >&2
    else
        while IFS= read -r repository_path; do
            [ -n "$repository_path" ] || continue
            if [ -n "${EDITOR_APP:-}" ]; then
                open -a "$EDITOR_APP" "$repository_path"
            elif [ -d "/Applications/Visual Studio Code.app" ]; then
                open -a "Visual Studio Code" "$repository_path"
            elif [ -d "/Applications/Cursor.app" ]; then
                open -a "Cursor" "$repository_path"
            else
                printf 'Editor not opened: set EDITOR_APP or install Visual Studio Code/Cursor.\n' >&2
                break
            fi
        done <<EOF
$REPOSITORY_PATHS
EOF
    fi
}
