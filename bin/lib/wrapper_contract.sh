wrapper_contract_wrapper_is_git_repo() {
    contract_wrapper_root=${1:-${PROJECT_ROOT:-}}
    [ -n "$contract_wrapper_root" ] || return 1
    [ "$(git -C "$contract_wrapper_root" rev-parse --show-toplevel 2>/dev/null)" = "$(physical_dir "$contract_wrapper_root")" ]
}

wrapper_contract_icloud_project_is_directory() {
    [ -d "${ICLOUD_PROJECT_PATH:-}" ]
}

wrapper_contract_icloud_project_link_is_correct() {
    [ -n "${ICLOUD_PROJECT_LINK:-}" ] || return 1
    [ -L "$ICLOUD_PROJECT_LINK" ] || return 1
    [ -d "${ICLOUD_PROJECT_PATH:-}" ] || return 1
    [ "$(physical_dir "$ICLOUD_PROJECT_LINK")" = "$(physical_dir "$ICLOUD_PROJECT_PATH")" ]
}

wrapper_contract_repository_is_git_repo() {
    contract_repository_path=${1:-${REPOSITORY_PATH:-}}
    [ -n "$contract_repository_path" ] || return 1
    is_git_repository "$contract_repository_path"
}

wrapper_contract_repository_is_outside_wrapper() {
    contract_repository_path=${1:-${REPOSITORY_PATH:-}}
    [ -n "$contract_repository_path" ] || return 1
    path_is_outside "$contract_repository_path" "${PROJECT_ROOT:-}"
}

wrapper_contract_repository_is_outside_icloud_project() {
    contract_repository_path=${1:-${REPOSITORY_PATH:-}}
    [ -n "$contract_repository_path" ] || return 1
    path_is_outside "$contract_repository_path" "${ICLOUD_PROJECT_PATH:-}"
}

wrapper_contract_repo_link_is_correct() {
    [ -n "${REPOSITORY_PATH:-}" ] || return 1
    [ -L "${REPO_LINK:-}" ] || return 1
    [ "$(physical_dir "$REPO_LINK")" = "$(physical_dir "$REPOSITORY_PATH")" ]
}

wrapper_contract_validate_repository_link() {
    if [ -e "$REPO_LINK" ] || [ -L "$REPO_LINK" ]; then
        [ -L "$REPO_LINK" ] \
            || die "refusing to replace non-symlink at ${REPO_LINK}"
        [ -n "$REPOSITORY_PATH" ] \
            || die "repository symlink exists but no repository is configured: ${REPO_LINK}"
        link_target=$(physical_dir "$REPO_LINK") \
            || die "repository symlink is broken: ${REPO_LINK}"
        target_dir=$(physical_dir "$REPOSITORY_PATH") \
            || die "configured repository target is not accessible: ${REPOSITORY_PATH}"
        [ "$link_target" = "$target_dir" ] \
            || die "repository symlink points to ${link_target}; refusing to replace it"
    fi
}

wrapper_contract_validate_initialization() {
    contract_wrapper_root=$1
    contract_repository_path=${REPOSITORY_PATH:-}

    [ -d "$contract_wrapper_root" ] \
        || die "wrapper root is not a directory: ${contract_wrapper_root}"
    [ -d "${contract_wrapper_root}/config" ] \
        || die "wrapper config directory is missing: ${contract_wrapper_root}/config"
    [ -d "${contract_wrapper_root}/bin" ] \
        || die "wrapper bin directory is missing: ${contract_wrapper_root}/bin"
    [ -n "$ICLOUD_PROJECT_PATH" ] \
        || die "icloud_project_path cannot be empty in ${CONFIG_FILE}"
    if [ -e "$ICLOUD_PROJECT_PATH" ] || [ -L "$ICLOUD_PROJECT_PATH" ]; then
        [ -d "$ICLOUD_PROJECT_PATH" ] \
            || die "iCloud project path is not a directory: ${ICLOUD_PROJECT_PATH}"
    fi

    for boundary_directory in local remote; do
        boundary_path="${contract_wrapper_root}/${boundary_directory}"
        if [ -e "$boundary_path" ] || [ -L "$boundary_path" ]; then
            [ -d "$boundary_path" ] \
                || die "wrapper boundary is not a directory: ${boundary_path}"
        fi
    done

    if [ -e "$ICLOUD_PROJECT_LINK" ] || [ -L "$ICLOUD_PROJECT_LINK" ]; then
        [ -L "$ICLOUD_PROJECT_LINK" ] \
            || die "refusing to replace non-symlink at ${ICLOUD_PROJECT_LINK}"
        [ -d "$ICLOUD_PROJECT_PATH" ] \
            || die "iCloud project target is missing: ${ICLOUD_PROJECT_PATH}"
        link_target=$(physical_dir "$ICLOUD_PROJECT_LINK") \
            || die "iCloud project symlink is broken: ${ICLOUD_PROJECT_LINK}"
        target_dir=$(physical_dir "$ICLOUD_PROJECT_PATH") \
            || die "iCloud project target is not accessible: ${ICLOUD_PROJECT_PATH}"
        [ "$link_target" = "$target_dir" ] \
            || die "iCloud project symlink points to ${link_target}, expected ${target_dir}"
    fi

    if [ -n "$contract_repository_path" ] && [ -e "$contract_repository_path" ]; then
        wrapper_contract_repository_is_git_repo "$contract_repository_path" \
            || die "repository is not an independent Git repository: ${contract_repository_path}"
    fi
    if [ -e "$REPO_LINK" ] || [ -L "$REPO_LINK" ]; then
        [ -L "$REPO_LINK" ] \
            || die "refusing to replace non-symlink at ${REPO_LINK}"
        [ -n "$contract_repository_path" ] \
            || die "repository symlink exists but no repository is configured: ${REPO_LINK}"
        [ -d "$contract_repository_path" ] \
            || die "repository target is missing: ${contract_repository_path}"
        link_target=$(physical_dir "$REPO_LINK") \
            || die "repository symlink is broken: ${REPO_LINK}"
        target_dir=$(physical_dir "$contract_repository_path") \
            || die "repository target is not accessible: ${contract_repository_path}"
        [ "$link_target" = "$target_dir" ] \
            || die "repository symlink points to ${link_target}, expected ${target_dir}"
    fi
}

wrapper_contract_validate_attachment() {
    contract_wrapper_root=$1
    contract_repository_path=$2

    load_wrapper_config "$contract_wrapper_root"
    contract_wrapper_physical=$(physical_dir "$contract_wrapper_root") \
        || die "wrapper root is not accessible: ${contract_wrapper_root}"
    [ -d "$contract_wrapper_root/config" ] \
        || die "wrapper config directory is missing: ${contract_wrapper_root}/config"
    [ -d "$contract_wrapper_root/bin" ] \
        || die "wrapper bin directory is missing: ${contract_wrapper_root}/bin"
    [ -d "$contract_wrapper_root/local" ] \
        || die "wrapper local boundary is missing: ${contract_wrapper_root}/local"
    [ -d "$contract_wrapper_root/remote" ] \
        || die "wrapper remote boundary is missing: ${contract_wrapper_root}/remote"
    [ "$(git -C "$contract_wrapper_root" rev-parse --show-toplevel 2>/dev/null)" = "$contract_wrapper_physical" ] \
        || die "wrapper is not an independent Git repository: ${contract_wrapper_root}"
    [ -d "$ICLOUD_PROJECT_PATH" ] \
        || die "iCloud project target is missing: ${ICLOUD_PROJECT_PATH}"
    [ -L "$ICLOUD_PROJECT_LINK" ] \
        || die "iCloud project symlink is missing: ${ICLOUD_PROJECT_LINK}"
    link_target=$(physical_dir "$ICLOUD_PROJECT_LINK") \
        || die "iCloud project symlink is broken: ${ICLOUD_PROJECT_LINK}"
    target_dir=$(physical_dir "$ICLOUD_PROJECT_PATH") \
        || die "iCloud project target is not accessible: ${ICLOUD_PROJECT_PATH}"
    [ "$link_target" = "$target_dir" ] \
        || die "iCloud project symlink points to ${link_target}, expected ${target_dir}"
    [ -d "$contract_repository_path" ] \
        || die "repository is not a directory: ${contract_repository_path}"
    wrapper_contract_repository_is_git_repo "$contract_repository_path" \
        || die "repository must be an independent Git repository: ${contract_repository_path}"
    wrapper_contract_repository_is_outside_wrapper "$contract_repository_path" \
        || die "repository must be outside the wrapper: ${contract_repository_path}"
    wrapper_contract_repository_is_outside_icloud_project "$contract_repository_path" \
        || die "repository must be outside the iCloud project: ${contract_repository_path}"
    wrapper_contract_validate_repository_link
}
