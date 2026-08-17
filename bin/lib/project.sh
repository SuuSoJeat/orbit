cmd_new() {
    project_name=''
    interactive=0
    if [ "$#" -gt 0 ]; then
        case "$1" in
            --*) ;;
            *) project_name=$1; shift ;;
        esac
    fi
    [ -n "$project_name" ] || interactive=1

    category=companies
    company_name=''
    client_name=''
    no_client=0
    icloud_project_path=''
    with_wrapper=0
    wrapper_root=''

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --category)
                shift
                [ "$#" -gt 0 ] || die "--category requires companies or ventures"
                category=$1
                ;;
            --company)
                shift
                [ "$#" -gt 0 ] || die "--company requires a name"
                company_name=$1
                ;;
            --client)
                shift
                [ "$#" -gt 0 ] || die "--client requires a name"
                client_name=$1
                ;;
            --no-client) no_client=1 ;;
            --icloud-root)
                option_name=$1
                shift
                [ "$#" -gt 0 ] || die "${option_name} requires a path"
                icloud_project_path=$1
                ;;
            --with-wrapper) with_wrapper=1 ;;
            --wrapper-root)
                shift
                [ "$#" -gt 0 ] || die "--wrapper-root requires a path"
                wrapper_root=$1
                with_wrapper=1
                ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option for new: $1" ;;
        esac
        shift
    done

    if [ -z "$project_name" ]; then
        prompt_for_name project
        project_name=$SELECTED_NAME
    fi
    [ -n "$project_name" ] || die "project name cannot be empty"
    case "$project_name" in
        */*) die "project name cannot contain '/': ${project_name}" ;;
    esac
    [ "$no_client" -eq 0 ] || [ -z "$client_name" ] \
        || die "use either --client or --no-client, not both"

    slug=$(slugify "$project_name")
    [ -n "$slug" ] || die "project name must contain letters or numbers"

    load_consumer_config

    if [ -z "$icloud_project_path" ]; then
        case "$category" in
            companies)
                [ -n "$CONSUMER_COMPANIES_ROOT" ] \
                    || die "companies_root is not configured; run orbit config init or use --icloud-root"
                cloud_base=$CONSUMER_COMPANIES_ROOT
                [ -z "$client_name" ] || [ -n "$company_name" ] \
                    || die "--client requires --company"
                if [ -z "$company_name" ]; then
                    interactive=1
                    select_or_create "$cloud_base" company 0
                    company_name=$SELECTED_NAME
                fi
                case "$company_name" in
                    */*) die "company name cannot contain '/': ${company_name}" ;;
                esac
                company_root="${cloud_base}/${company_name}"
                if [ "$no_client" -eq 0 ] && [ -z "$client_name" ]; then
                    interactive=1
                    select_or_create "${company_root}/Clients" client 1
                    client_name=$SELECTED_NAME
                fi
                if [ -n "$client_name" ]; then
                    case "$client_name" in
                        */*) die "client name cannot contain '/': ${client_name}" ;;
                    esac
                    icloud_project_path="${company_root}/Clients/${client_name}/${project_name}"
                else
                    icloud_project_path="${company_root}/${project_name}"
                fi
                ;;
            ventures)
                [ -z "$company_name" ] && [ -z "$client_name" ] \
                    || die "company/client options require --category companies"
                [ -n "$CONSUMER_VENTURES_ROOT" ] \
                    || die "ventures_root is not configured; run orbit config init or use --icloud-root"
                cloud_base=$CONSUMER_VENTURES_ROOT
                icloud_project_path="${cloud_base}/${project_name}"
                ;;
            *) die "category must be companies or ventures" ;;
        esac
    elif [ -n "$company_name" ] || [ -n "$client_name" ]; then
        die "--company and --client cannot be combined with --icloud-root"
    fi

    if [ "$interactive" -eq 1 ] && [ "$with_wrapper" -eq 0 ]; then
        select_wrapper
    fi

    journal_init "$project_name"
    journal_root "$(journal_scope_root "$icloud_project_path")"
    journal_command "orbit new $(shell_quote "$project_name") --category $(shell_quote "$category")"
    create_icloud_project "$icloud_project_path"
    info "Created or confirmed iCloud project: ${icloud_project_path}"

    if [ "$with_wrapper" -eq 1 ]; then
        if [ -z "$wrapper_root" ]; then
            wrapper_root="${CONSUMER_WRAPPER_ROOT}/${slug}-orbit"
        fi
        journal_root "$(journal_scope_root "$wrapper_root")"
    create_wrapper "$wrapper_root" "$project_name" "$icloud_project_path" \
            "$TEMPLATE_ROOT" "${CLI_ROOT}/bin/lib/wrapper_runtime.sh"
        info "Created wrapper: ${wrapper_root}"
    else
        info "No wrapper created. Add one later with --with-wrapper."
    fi
    creation_commit
    info "Creation recorded: ${CREATION_LOG}"
}
