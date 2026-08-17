wrapper_root_is_valid() {
    candidate_root=$1
    [ -x "$candidate_root/bin/doctor" ] \
        && [ -f "$candidate_root/config/orbit.conf" ] \
        && [ -f "$candidate_root/bin/lib.sh" ] \
        && [ -f "$candidate_root/bin/contract.sh" ]
}

infer_wrapper_root() {
    candidate_root=$(CDPATH= cd -P -- "${PWD}" 2>/dev/null && pwd -P) \
        || die "cannot determine the current directory"
    while :; do
        if wrapper_root_is_valid "$candidate_root"; then
            printf '%s\n' "$candidate_root"
            return 0
        fi
        [ "$candidate_root" = "/" ] && break
        candidate_root=${candidate_root%/*}
        [ -n "$candidate_root" ] || candidate_root=/
    done
    die "could not infer a wrapper root from ${PWD}; supply WRAPPER_ROOT explicitly"
}

create_icloud_project() {
    icloud_project_path=$1

    ensure_directory "$icloud_project_path"
    for folder in Notes References Assets Exports Private; do
        ensure_directory "$icloud_project_path/$folder"
    done
}

wrapper_is_empty_or_missing() {
    wrapper_root=$1
    [ ! -e "$wrapper_root" ] && return 0
    [ -d "$wrapper_root" ] || return 1
    [ -z "$(find "$wrapper_root" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]
}

wrapper_set_config_value() {
    config_key=$1
    config_value=$2
    atomic_write "$CONFIG_FILE" awk -v wanted="$config_key" -v value="$config_value" '
        function trim(text) {
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            return text
        }
        {
            line = $0
            left = line
            sub(/^[[:space:]]*/, "", left)
            separator = index(left, "=")
            key = separator > 0 ? trim(substr(left, 1, separator - 1)) : ""
            if (key == wanted) {
                if (!found) print wanted " = " value
                found = 1
            } else {
                print line
            }
        }
        END { if (!found) print wanted " = " value }
    ' "$CONFIG_FILE" || die "could not update wrapper configuration: ${CONFIG_FILE}"
}

wrapper_validate_initialization() {
    wrapper_contract_validate_initialization "$@"
}

wrapper_validate_attachment() {
    wrapper_contract_validate_attachment "$@"
}

wrapper_ensure_link() {
    link_path=$1
    target_path=$2
    link_label=$3

    if [ -e "$link_path" ] || [ -L "$link_path" ]; then
        [ -L "$link_path" ] || die "refusing to replace non-symlink at ${link_path}"
        link_target=$(physical_dir "$link_path") \
            || die "${link_label} symlink is broken: ${link_path}"
        target_dir=$(physical_dir "$target_path") \
            || die "${link_label} target is not accessible: ${target_path}"
        [ "$link_target" = "$target_dir" ] \
            || die "${link_label} symlink points to ${link_target}, expected ${target_dir}"
    else
        ln -s "$target_path" "$link_path"
        wrapper_record_created_link "$link_path"
        info "Created ${link_label} boundary symlink at ${link_path}"
    fi
}

wrapper_record_created_link() {
    [ "${ATTACH_TRANSACTION_ACTIVE:-0}" -eq 1 ] || return 0
    if [ -n "${ATTACH_CREATED_LINKS:-}" ]; then
        ATTACH_CREATED_LINKS="${ATTACH_CREATED_LINKS}
${1}"
    else
        ATTACH_CREATED_LINKS=$1
    fi
}

wrapper_initialize() {
    [ "$#" -eq 1 ] || die "wrapper_initialize requires a wrapper root"
    wrapper_root=$1
    load_wrapper_config "$wrapper_root"
    wrapper_validate_initialization "$wrapper_root"
    create_icloud_project "$ICLOUD_PROJECT_PATH"

    if [ ! -d "${wrapper_root}/.git" ]; then
        journal_command "git -C $(shell_quote "$wrapper_root") init"
        git -C "$wrapper_root" init >/dev/null
        info "Initialized wrapper Git repository"
    fi

    ensure_directory "${wrapper_root}/local"
    ensure_directory "${wrapper_root}/remote"
    wrapper_ensure_link "$ICLOUD_PROJECT_LINK" "$ICLOUD_PROJECT_PATH" "iCloud project"

    if [ -n "$REPOSITORY_PATH" ] && [ -d "$REPOSITORY_PATH" ]; then
        wrapper_ensure_link "$REPO_LINK" "$REPOSITORY_PATH" repository
    elif [ -n "$REPOSITORY_PATH" ]; then
        info "Repository attachment is configured but not present yet: ${REPOSITORY_PATH}"
    else
        info "No repository attached yet; the iCloud project can start independently."
    fi

    info "Wrapper ready. Run orbit doctor to verify it."
}

create_wrapper() {
    wrapper_root=$1
    new_project_name=$2
    new_icloud_project_path=$3
    template_root=$4
    common_source=$5

    wrapper_is_empty_or_missing "$wrapper_root" || die "wrapper path is not empty: ${wrapper_root}"
    wrapper_preexisted=0
    if [ -e "$wrapper_root" ] || [ -L "$wrapper_root" ]; then
        wrapper_preexisted=1
    fi
    ensure_directory "$wrapper_root"
    journal_command "cp -R $(shell_quote "$template_root/.") $(shell_quote "$wrapper_root/")"
    cp -R "$template_root"/. "$wrapper_root"/
    journal_command "cp $(shell_quote "$common_source") $(shell_quote "$wrapper_root/bin/lib.sh")"
    cp "$common_source" "$wrapper_root/bin/lib.sh"
    journal_command "cp wrapper contract $(shell_quote "$CLI_ROOT/bin/lib/wrapper_contract.sh") $(shell_quote "$wrapper_root/bin/contract.sh")"
    cp "${CLI_ROOT}/bin/lib/wrapper_contract.sh" "$wrapper_root/bin/contract.sh"
    [ "$wrapper_preexisted" -eq 0 ] || journal_tree "$wrapper_root"

    journal_command "write $(shell_quote "$wrapper_root/config/orbit.conf")"
    atomic_write_stdin "$wrapper_root/config/orbit.conf" <<EOF
# Generated by orbit. Machine-specific; do not commit.
project_name = ${new_project_name}
repository_path =
icloud_project_path = ${new_icloud_project_path}
EOF

    [ "$wrapper_preexisted" -eq 0 ] || journal_tree "$wrapper_root"
    wrapper_initialize "$wrapper_root"
    [ "$wrapper_preexisted" -eq 0 ] || journal_tree "$wrapper_root"
}
