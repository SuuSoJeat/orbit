journal_init() { creation_begin "$@"; }
journal_command() { creation_record_command "$@"; }
journal_root() { creation_record_root "$@"; }
journal_scope_root() { creation_scope_root "$@"; }
journal_path() { creation_record_path "$@"; }
journal_tree() { creation_record_tree "$@"; }
ensure_directory() { creation_ensure_directory "$@"; }

cmd_undo() {
    [ "$#" -eq 0 ] || die "usage: orbit undo"
    creation_root="$(orbit_state_root)/creations"
    [ -d "$creation_root" ] || {
        info "No project creations recorded."
        return 0
    }

    log_list=$(mktemp "${TMPDIR:-/tmp}/orbit-undo.XXXXXX")
    find "$creation_root" -type f -name '*.log' -print 2>/dev/null | sort > "$log_list"
    log_count=$(wc -l < "$log_list" | tr -d ' ')
    if [ "$log_count" -eq 0 ]; then
        /bin/rm "$log_list"
        info "No project creations recorded."
        return 0
    fi

    printf '\nRecorded project creations:\n'
    log_number=1
    while IFS= read -r log_path; do
        log_timestamp=$(awk -F '\t' '$1 == "timestamp" { print $2; exit }' "$log_path")
        log_orbit=$(awk -F '\t' '$1 == "project" || $1 == "orbit" { print $2; exit }' "$log_path")
        log_status=$(awk -F '\t' '$1 == "status" { value = $2 } END { print value }' "$log_path")
        printf '  %d) %s — %s [%s]\n' "$log_number" "$log_orbit" "$log_timestamp" "$log_status"
        log_number=$((log_number + 1))
    done < "$log_list"

    printf 'Select project [1-%d]: ' "$log_count"
    IFS= read -r selection || die "could not read project selection"
    case "$selection" in
        ''|*[!0-9]*) die "invalid project selection: ${selection}" ;;
    esac
    [ "$selection" -ge 1 ] && [ "$selection" -le "$log_count" ] || die "invalid project selection: ${selection}"

    selected_log=$(sed -n "${selection}p" "$log_list")
    selected_orbit=$(awk -F '\t' '$1 == "project" || $1 == "orbit" { print $2; exit }' "$selected_log")
    selected_paths=$(mktemp "${TMPDIR:-/tmp}/orbit-undo-paths.XXXXXX")
    awk -F '\t' '$1 == "path" { print length($2) "\t" $2 }' "$selected_log" \
        | sort -rn > "$selected_paths"
    selected_roots=$(mktemp "${TMPDIR:-/tmp}/orbit-undo-roots.XXXXXX")
    awk -F '\t' '$1 == "root" { print $2 }' "$selected_log" > "$selected_roots"
    root_count=$(wc -l < "$selected_roots" | tr -d ' ')
    [ "$root_count" -gt 0 ] || die "project record lacks safety roots; refusing to undo it"
    path_count=$(wc -l < "$selected_paths" | tr -d ' ')

    printf '\nSelected project: %s\n' "$selected_orbit"
    printf 'Recorded commands: %s\n' "$(awk -F '\t' '$1 == "command" { count += 1 } END { print count + 0 }' "$selected_log")"
    printf 'Recorded paths to remove: %s\n' "$path_count"
    printf 'Preview of paths to remove:\n'
    while IFS="$(printf '\t')" read -r path_length path_to_remove; do
        [ -n "$path_to_remove" ] || continue
        if [ -L "$path_to_remove" ]; then
            preview_type=symlink
        elif [ -f "$path_to_remove" ]; then
            preview_type=file
        elif [ -d "$path_to_remove" ]; then
            preview_type=directory
        else
            preview_type=already-absent
        fi
        printf '  - [%s] %s\n' "$preview_type" "$path_to_remove"
    done < "$selected_paths"
    printf 'Remove this project and its recorded files/folders? [y/N]: '
    IFS= read -r confirmation || die "could not read undo confirmation"
    case "$confirmation" in
        y|Y|yes|YES) ;;
        *)
            /bin/rm "$selected_paths" "$selected_roots" "$log_list"
            info "Undo cancelled."
            return 0
            ;;
    esac

    if creation_rollback_paths "$selected_log"; then
        /bin/rm "$selected_paths" "$selected_roots" "$log_list" "$selected_log"
        info "Removed recorded project: ${selected_orbit}"
    else
        /bin/rm "$selected_paths" "$selected_roots" "$log_list"
        die "undo was incomplete; project record preserved: ${selected_log}"
    fi
}
