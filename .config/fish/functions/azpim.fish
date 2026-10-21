function azpim --description 'Activate eligible Azure PIM roles in the current tenant'
    # Usage: azpim [-d 8h] [-j "justification"]
    argparse 'd/duration=' 'j/justification=' h/help -- $argv; or return 1
    if set -q _flag_help
        echo "azpim [-d 8h|30m] [-j justification]  pick eligible roles (TAB) in the current az tenant"
        return 0
    end
    set -l duration (string upper -- (set -q _flag_duration; and echo $_flag_duration; or echo 8h))
    set -l justification (set -q _flag_justification; and echo $_flag_justification; or echo "Travaux infra")

    if not az account show >/dev/null 2>&1
        echo "Not logged in - run azlogin first"
        return 1
    end
    set -l tenant_id (az account show --query tenantId -o tsv)
    set -l arm https://management.azure.com
    set -l api api-version=2020-10-01

    # Active activations, keyed "roleDefinitionId|scope" -> end time
    set -l active (az rest --method get \
            --url "$arm/providers/Microsoft.Authorization/roleAssignmentScheduleInstances?$api&\$filter=asTarget()" -o json 2>/dev/null \
        | jq -r '.value[].properties | select(.assignmentType == "Activated") | "\(.roleDefinitionId)|\(.scope)\t\(.endDateTime)"')

    # Eligible roles: scheduleId, roleDefinitionId, scope, label. Management-group scopes first.
    set -l eligible (az rest --method get \
            --url "$arm/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?$api&\$filter=asTarget()" -o json 2>/dev/null \
        | jq -r '.value
            | sort_by((.properties.scope | test("managementGroups") | not), .properties.scope, .properties.expandedProperties.roleDefinition.displayName)
            | .[].properties
            | "\(.roleEligibilityScheduleId)\t\(.roleDefinitionId)\t\(.scope)\t\(.expandedProperties.roleDefinition.displayName)  @ \(.expandedProperties.scope.displayName) (\(.expandedProperties.scope.type))"')
    if test (count $eligible) -eq 0
        echo "No eligible PIM roles in tenant $tenant_id"
        return 1
    end

    # Annotate already-active roles; preselect management-group scopes (or everything if none)
    set -l lines
    set -l n_default 0
    for e in $eligible
        set -l f (string split \t -- $e)
        set -l hit (string match -- "$f[2]|$f[3]"\t'*' $active | string split -f2 \t)
        set -l label $f[4]
        if test -n "$hit"
            set -l epoch (TZ=UTC date -j -f %Y-%m-%dT%H:%M:%S (string sub -l 19 -- $hit) +%s 2>/dev/null)
            set label "$label   [active until "(date -r $epoch +%H:%M 2>/dev/null; or echo $hit)"]"
        end
        set -a lines "$f[1]\t$f[2]\t$f[3]\t$label"
        string match -q '*managementGroups*' -- $f[3]; and set n_default (math $n_default + 1)
    end
    test $n_default -eq 0; and set n_default (count $lines)
    set -l preselect (string repeat -n $n_default 'toggle+down+')first

    set -l picked (printf '%b\n' $lines \
        | fzf --multi --with-nth=4.. --delimiter='\t' \
              --prompt='Role> ' --height=40% --reverse --preview='' \
              --bind "load:$preselect" \
              --header="Tenant: $tenant_id  |  TAB toggle, Enter activate for $duration")
    or return 1

    set -l me (az ad signed-in-user show --query id -o tsv); or return 1
    for p in $picked
        set -l f (string split \t -- $p)
        if string match -q '*[active until*' -- $f[4]
            echo "= already active: $f[4]"
            continue
        end
        set -l body (jq -nc --arg p $me --arg r $f[2] --arg s $f[1] --arg j $justification --arg d PT$duration \
            '{properties: {principalId: $p, roleDefinitionId: $r, requestType: "SelfActivate",
              linkedRoleEligibilityScheduleId: $s, justification: $j,
              scheduleInfo: {expiration: {type: "AfterDuration", duration: $d}}}}')
        if az rest --method put \
                --url "$arm$f[3]/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/"(uuidgen)"?$api" \
                --body "$body" -o none
            echo "✓ $f[4] for $duration"
        else
            echo "✗ $f[4]"
        end
    end
    echo "RBAC can take a few minutes to propagate (403 right after activation is normal)."
end
