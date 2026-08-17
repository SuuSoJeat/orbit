consumer_config_path() {
    if [ -n "${CLI_CONFIG_FILE:-}" ]; then
        printf '%s\n' "$CLI_CONFIG_FILE"
    elif [ -n "${ORBIT_CONFIG:-}" ]; then
        printf '%s\n' "$ORBIT_CONFIG"
    elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
        printf '%s/orbit/config\n' "$XDG_CONFIG_HOME"
    else
        printf '%s/.config/orbit/config\n' "$HOME"
    fi
}

expand_config_path() {
    config_path_value=$1
    case "$config_path_value" in
        "~") printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s/%s\n' "$HOME" "${config_path_value#\~/}" ;;
        /*) printf '%s\n' "$config_path_value" ;;
        *) die "configured path must be absolute or begin with ~: ${config_path_value}" ;;
    esac
}

consumer_icloud_root() {
    printf '%s/Library/Mobile Documents/com~apple~CloudDocs\n' "$HOME"
}

validate_config_path() {
    config_key=$1
    config_path_value=$2
    [ -n "$config_path_value" ] || return 0
    case "$config_path_value" in
        "~"|"~/"*|/*) ;;
        *) die "${config_key} must be absolute or begin with ~: ${config_path_value}" ;;
    esac
}

load_consumer_config() {
    CONSUMER_CONFIG_FILE=$(consumer_config_path)
    CONSUMER_COMPANIES_ROOT="$(consumer_icloud_root)/Workspace/Companies"
    CONSUMER_VENTURES_ROOT="$(consumer_icloud_root)/Workspace/Ventures"
    CONSUMER_REPOSITORY_ROOT="${HOME}/Repositories"
    CONSUMER_WRAPPER_ROOT=''

    if [ -f "$CONSUMER_CONFIG_FILE" ]; then
        if config_value_result=$(config_value companies_root "$CONSUMER_CONFIG_FILE"); then
            CONSUMER_COMPANIES_ROOT=$config_value_result
        fi
        if config_value_result=$(config_value ventures_root "$CONSUMER_CONFIG_FILE"); then
            CONSUMER_VENTURES_ROOT=$config_value_result
        fi
        if config_value_result=$(config_value repository_root "$CONSUMER_CONFIG_FILE"); then
            CONSUMER_REPOSITORY_ROOT=$config_value_result
        fi
        if config_value_result=$(config_value wrapper_root "$CONSUMER_CONFIG_FILE"); then
            CONSUMER_WRAPPER_ROOT=$config_value_result
        fi
    elif [ -n "${CLI_CONFIG_FILE:-}" ] || [ -n "${ORBIT_CONFIG:-}" ]; then
        die "consumer configuration not found: ${CONSUMER_CONFIG_FILE}"
    fi

    [ -n "$CONSUMER_REPOSITORY_ROOT" ] \
        || die "repository_root cannot be empty in ${CONSUMER_CONFIG_FILE}"
    [ -n "$CONSUMER_WRAPPER_ROOT" ] || CONSUMER_WRAPPER_ROOT=$CONSUMER_REPOSITORY_ROOT

    if [ -n "$CONSUMER_COMPANIES_ROOT" ]; then
        CONSUMER_COMPANIES_ROOT=$(expand_config_path "$CONSUMER_COMPANIES_ROOT")
    fi
    if [ -n "$CONSUMER_VENTURES_ROOT" ]; then
        CONSUMER_VENTURES_ROOT=$(expand_config_path "$CONSUMER_VENTURES_ROOT")
    fi
    CONSUMER_REPOSITORY_ROOT=$(expand_config_path "$CONSUMER_REPOSITORY_ROOT")
    CONSUMER_WRAPPER_ROOT=$(expand_config_path "$CONSUMER_WRAPPER_ROOT")

    export CONSUMER_CONFIG_FILE CONSUMER_COMPANIES_ROOT CONSUMER_VENTURES_ROOT
    export CONSUMER_REPOSITORY_ROOT CONSUMER_WRAPPER_ROOT
}

cmd_config_init() {
    config_file=$(consumer_config_path)
    companies_root="$(consumer_icloud_root)/Workspace/Companies"
    ventures_root="$(consumer_icloud_root)/Workspace/Ventures"
    repository_root="${HOME}/Repositories"
    wrapper_root=''
    icloud_profile=''
    force=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --companies-root)
                shift
                [ "$#" -gt 0 ] || die "--companies-root requires a path"
                companies_root=$1
                ;;
            --ventures-root)
                shift
                [ "$#" -gt 0 ] || die "--ventures-root requires a path"
                ventures_root=$1
                ;;
            --repository-root)
                shift
                [ "$#" -gt 0 ] || die "--repository-root requires a path"
                repository_root=$1
                ;;
            --wrapper-root)
                shift
                [ "$#" -gt 0 ] || die "--wrapper-root requires a path"
                wrapper_root=$1
                ;;
            --icloud-profile)
                shift
                [ "$#" -gt 0 ] || die "--icloud-profile requires a name"
                icloud_profile=$1
                ;;
            --force) force=1 ;;
            -h|--help)
                cat <<'EOF'
Usage: orbit config init [options]

Options:
  --companies-root PATH
  --ventures-root PATH
  --repository-root PATH
  --wrapper-root PATH
  --icloud-profile NAME
  --force
EOF
                return 0
                ;;
            *) die "unknown option for config init: $1" ;;
        esac
        shift
    done

    case "$icloud_profile" in
        '') ;;
        */*|.|..) die "--icloud-profile must be a single directory name: ${icloud_profile}" ;;
    esac
    if [ -n "$icloud_profile" ]; then
        icloud_workspace_root="$(consumer_icloud_root)/${icloud_profile}/Workspace"
        [ "$companies_root" = "$(consumer_icloud_root)/Workspace/Companies" ] \
            && companies_root="${icloud_workspace_root}/Companies"
        [ "$ventures_root" = "$(consumer_icloud_root)/Workspace/Ventures" ] \
            && ventures_root="${icloud_workspace_root}/Ventures"
    fi
    [ -n "$repository_root" ] || die "--repository-root cannot be empty"
    [ -n "$wrapper_root" ] || wrapper_root=$repository_root

    validate_config_path companies_root "$companies_root"
    validate_config_path ventures_root "$ventures_root"
    validate_config_path repository_root "$repository_root"
    validate_config_path wrapper_root "$wrapper_root"

    if [ -e "$config_file" ] && [ "$force" -ne 1 ]; then
        die "consumer configuration already exists: ${config_file} (use --force to replace it)"
    fi

    case "$config_file" in
        */*) config_parent=${config_file%/*} ;;
        *) config_parent=. ;;
    esac
    mkdir -p "$config_parent"
    (
        umask 077
        atomic_write_stdin "$config_file" <<EOF
# Orbit consumer configuration. Paths may be absolute or begin with ~.
# Leave an iCloud project root empty if that category is not used by this consumer.
companies_root = ${companies_root}
ventures_root = ${ventures_root}
repository_root = ${repository_root}
wrapper_root = ${wrapper_root}
EOF
    ) || die "could not write consumer configuration: ${config_file}"
    info "Created consumer configuration: ${config_file}"
}

cmd_config_show() {
    [ "$#" -eq 0 ] || die "usage: orbit config show"
    config_file=$(consumer_config_path)
    printf 'config: %s\n' "$config_file"
    if [ -f "$config_file" ]; then
        printf 'status: configured\n'
    else
        printf 'status: using built-in defaults\n'
    fi
    load_consumer_config
    printf 'companies_root: %s\n' "$CONSUMER_COMPANIES_ROOT"
    printf 'ventures_root: %s\n' "$CONSUMER_VENTURES_ROOT"
    printf 'repository_root: %s\n' "$CONSUMER_REPOSITORY_ROOT"
    printf 'wrapper_root: %s\n' "$CONSUMER_WRAPPER_ROOT"
}

cmd_config_check() {
    [ "$#" -eq 0 ] || die "usage: orbit config check"
    config_file=$(consumer_config_path)
    load_consumer_config
    if [ -f "$config_file" ]; then
        printf 'Source: %s\n' "$config_file"
    else
        printf 'Source: built-in defaults\n'
    fi
    printf 'OK   companies_root = %s\n' "$CONSUMER_COMPANIES_ROOT"
    printf 'OK   ventures_root = %s\n' "$CONSUMER_VENTURES_ROOT"
    printf 'OK   repository_root = %s\n' "$CONSUMER_REPOSITORY_ROOT"
    printf 'OK   wrapper_root = %s\n' "$CONSUMER_WRAPPER_ROOT"
    printf 'Configuration checks passed.\n'
}

cmd_config() {
    [ "$#" -gt 0 ] || {
        printf 'Usage: orbit config init|show|check\n' >&2
        exit 1
    }
    subcommand=$1
    shift
    case "$subcommand" in
        init) cmd_config_init "$@" ;;
        show) cmd_config_show "$@" ;;
        check) cmd_config_check "$@" ;;
        -h|--help) printf 'Usage: orbit config init|show|check\n' ;;
        *) die "unknown config command: ${subcommand}" ;;
    esac
}
