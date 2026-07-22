function azlogin --description 'Pick an Azure tenant then subscription interactively'
    # 1. Make sure we have at least one active login (needed to enumerate tenants)
    if not az account show >/dev/null 2>&1
        echo "Not logged in - launching az login..."
        az login >/dev/null; or return 1
    end

    # 2. Pick a tenant (names come from the ARM tenants endpoint)
    set -l tenant (az rest --method get \
            --url 'https://management.azure.com/tenants?api-version=2022-12-01' -o json 2>/dev/null \
        | jq -r '.value[] | "\(.tenantId)\t\(.displayName // "?")  (\(.defaultDomain // "?"))"' \
        | fzf --with-nth=2.. --delimiter='\t' \
              --prompt='Tenant> ' --height=40% --reverse --preview='' \
              --header='Select a tenant')
    or return 1
    set -l tenant_id (string split -f1 \t -- $tenant)
    set -l tenant_name (string split -f2 \t -- $tenant)

    # 3. Make sure we have subs for this tenant; log into it if not
    if test -z (az account list --all --query "[?tenantId=='$tenant_id'] | [0].id" -o tsv 2>/dev/null)
        echo "Logging into tenant $tenant_name..."
        az login --tenant $tenant_id >/dev/null; or return 1
    end

    # 4. Pick a subscription within that tenant
    set -l sub (az account list --all --query "[?tenantId=='$tenant_id'].{id:id,name:name}" -o json 2>/dev/null \
        | jq -r '.[] | "\(.id)\t\(.name)"' \
        | fzf --with-nth=2.. --delimiter='\t' \
              --prompt='Subscription> ' --height=40% --reverse --preview='' \
              --header="Tenant: $tenant_name")
    or return 1
    set -l sub_id (string split -f1 \t -- $sub)
    set -l sub_name (string split -f2 \t -- $sub)

    # 5. Activate it
    az account set --subscription $sub_id; or return 1
    echo "✓ Active: $sub_name ($sub_id)"
    echo "  Tenant: $tenant_name ($tenant_id)"
end
