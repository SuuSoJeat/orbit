prompt_for_name() {
    name_kind=$1
    printf 'New %s name: ' "$name_kind"
    IFS= read -r candidate || die "could not read ${name_kind} name"
    [ -n "$candidate" ] || die "${name_kind} name cannot be empty"
    case "$candidate" in
        */*) die "${name_kind} name cannot contain '/': ${candidate}" ;;
    esac
    SELECTED_NAME=$candidate
}

select_or_create() {
    collection_root=$1
    item_kind=$2
    allow_none=$3
    options_file=$(mktemp "${TMPDIR:-/tmp}/orbit-options.XXXXXX")
    find "$collection_root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort > "$options_file"
    option_count=$(wc -l < "$options_file" | tr -d ' ')
    create_option=$((option_count + 1))
    none_option=$((option_count + 2))

    case "$item_kind" in
        company) item_plural=companies ;;
        client) item_plural=clients ;;
        *) item_plural="${item_kind}s" ;;
    esac
    printf '\nAvailable %s:\n' "$item_plural"
    if [ "$option_count" -eq 0 ]; then
        printf '  (none found)\n'
    else
        option_number=1
        while IFS= read -r option_path; do
            printf '  %d) %s\n' "$option_number" "${option_path##*/}"
            option_number=$((option_number + 1))
        done < "$options_file"
    fi
    printf '  %d) Create new %s\n' "$create_option" "$item_kind"
    if [ "$allow_none" -eq 1 ]; then
        printf '  %d) No client (company project)\n' "$none_option"
    fi

    max_option=$create_option
    [ "$allow_none" -eq 1 ] && max_option=$none_option
    printf 'Select %s [1-%d]: ' "$item_kind" "$max_option"
    IFS= read -r selection || die "could not read ${item_kind} selection"
    case "$selection" in
        ''|*[!0-9]*) die "invalid ${item_kind} selection: ${selection}" ;;
    esac
    [ "$selection" -ge 1 ] && [ "$selection" -le "$max_option" ] \
        || die "invalid ${item_kind} selection: ${selection}"

    if [ "$selection" -le "$option_count" ]; then
        selected_path=$(sed -n "${selection}p" "$options_file")
        SELECTED_NAME=${selected_path##*/}
    elif [ "$selection" -eq "$create_option" ]; then
        prompt_for_name "$item_kind"
    else
        SELECTED_NAME=''
    fi
    /bin/rm "$options_file"
}

select_wrapper() {
    printf '\nOptional local wrapper:\n'
    printf '  1) Create wrapper\n'
    printf '  2) No wrapper (iCloud project only)\n'
    printf 'Select an option [1-2]: '
    IFS= read -r selection || die "could not read wrapper selection"
    case "$selection" in
        1) with_wrapper=1 ;;
        2) with_wrapper=0 ;;
        *) die "invalid wrapper selection: ${selection}" ;;
    esac
}
