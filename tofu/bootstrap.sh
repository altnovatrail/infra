#!/usr/bin/env bash
# Makes, once and with the operator's own rights, what the configuration in this directory cannot
# make for itself (R13): the project and its link to the billing account, the bucket the state
# lives in, the federated pool that CI signs in through and its provider, the identity the
# configuration is applied as and what that identity may do, and the three custom roles the
# configuration grants. Everything else is the configuration's, and CI applies it.
#
# Safe to run again: every step looks before it makes, and what is written here is brought back
# where it has drifted — the provider's condition, the custom roles' permissions, what the
# identity holds on the project, the state bucket and the billing account, and who may borrow it.
# What the identity holds and this script does not name is taken back, and so are Owner and Editor
# from every service account of the project (R13).
#
# It reads the deployment's values from production.auto.tfvars and backend.hcl beside it, so that
# each is written in one place, and prints at the end the two lines a workflow needs before it can
# sign in at all. The billing account arrives from the environment, as TF_VAR_billing_account, the
# same way it arrives in a plan, and nothing this script prints holds it.
#
# BOOTSTRAP_TOFU_DIR and BOOTSTRAP_RETRY_DELAY are for its test: another directory to read the
# values from, and the seconds between tries.

set -euo pipefail

here="${BOOTSTRAP_TOFU_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
tfvars="$here/production.auto.tfvars"
backend="$here/backend.hcl"
delay="${BOOTSTRAP_RETRY_DELAY:-3}"

fail() {
    echo "bootstrap: $*" >&2
    exit 1
}

[[ "$delay" =~ ^[0-9]+$ ]] || fail "BOOTSTRAP_RETRY_DELAY is a whole number of seconds"

# One value out of an HCL file: the first `name = "value"` it holds, or nothing.
hcl_value() {
    local name="$1" file="$2"
    [[ -f "$file" ]] || return 0
    sed -n "s/^[[:space:]]*${name}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -1
}

# A value the script cannot go on without, in the form the configuration takes it.
require() {
    local name="$1" value="$2" form="$3"
    if [[ -z "$value" || "$value" == REPLACE* ]]; then
        fail "${name} is not filled in yet (${tfvars##*/} and ${backend##*/} beside this script)"
    fi
    [[ "$value" =~ $form ]] || fail "${name} is not of the form the configuration takes: ${value}"
}

# A project just made, an API just enabled and an identity just created each take a few seconds to
# be seen by IAM, and a request in that window is refused as if it were not allowed. So a change is
# tried a few times before its error is shown.
retry() {
    local attempt
    for attempt in 1 2 3 4; do
        if "$@" > /dev/null 2>&1; then
            return 0
        fi
        sleep $((attempt * delay))
    done
    "$@" > /dev/null
}

# A read, tried as often, that hands on what it printed. A read that keeps failing stops the
# script: read as nothing there, it would skip a step without a word.
retry_read() {
    local attempt output
    for attempt in 1 2 3 4; do
        if output="$("$@" 2> /dev/null)"; then
            printf '%s\n' "$output"
            return 0
        fi
        sleep $((attempt * delay))
    done
    "$@"
}

# Makes a thing unless it is there, and looks again before every new try: a create refused on this
# side may still have succeeded on the other, and the next try then finds it.
ensure() {
    local exists="$1" make="$2" attempt
    for attempt in 1 2 3 4; do
        if "$exists" > /dev/null 2>&1 || "$make" > /dev/null 2>&1; then
            return 0
        fi
        sleep $((attempt * delay))
    done
    "$exists" > /dev/null 2>&1 || "$make" > /dev/null
}

command -v gcloud > /dev/null || fail "there is no gcloud here: run this where the Google Cloud CLI is, signed in as someone who may make projects and link them to the billing account"

# -- the values ---------------------------------------------------------------

project="$(hcl_value project_id "$tfvars")"
region="$(hcl_value region "$tfvars")"
pool="$(hcl_value workload_identity_pool_id "$tfvars")"
subject_prefix="$(hcl_value github_oidc_subject_prefix "$tfvars")"
currency="$(hcl_value budget_currency "$tfvars")"
bucket="$(hcl_value bucket "$backend")"

require project_id "$project" '^[a-z][a-z0-9-]{4,28}[a-z0-9]$'
require region "$region" '^[a-z]+-[a-z]+[0-9]+$'
require workload_identity_pool_id "$pool" '^[a-z0-9-]{4,32}$'
require github_oidc_subject_prefix "$subject_prefix" '^repo:[^/@:]+@[0-9]+/[^/@:]+@[0-9]+$'
require budget_currency "$currency" '^[A-Z]{3}$'
require bucket "$bucket" '^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$'

# The numbers GitHub gives the owner and the repository, which nobody else can take over as a name
# can be: repo:OWNER@OWNER_ID/NAME@REPOSITORY_ID.
[[ "$subject_prefix" =~ ^repo:[^/@:]+@([0-9]+)/[^/@:]+@([0-9]+)$ ]]
owner_id="${BASH_REMATCH[1]}"
repository_id="${BASH_REMATCH[2]}"

# The jobs that apply the configuration run in an environment of their own, which only main may
# run in, and no other job borrows the identity: not api's deployment, not the publisher of app's
# build, not a pull request's (R13). GitHub compares environments' names in any case of letters.
config_environment="production-config"
deploy_environment="$(hcl_value deploy_environment "$tfvars")"
hosting_environment="$(hcl_value hosting_environment "$tfvars")"
for other in "${deploy_environment:-production}" "${hosting_environment:-production-hosting}"; do
    if [[ "${other,,}" == "${config_environment,,}" ]]; then
        fail "the environment ${other} of ${tfvars##*/} is the configuration's own, ${config_environment}: the configuration's identity is lent to no job but its own"
    fi
done

# The account that pays is not written beside the deployment's other values, which are public.
billing="${TF_VAR_billing_account:-}"
[[ "$billing" =~ ^[0-9A-Z]{6}-[0-9A-Z]{6}-[0-9A-Z]{6}$ ]] || fail "TF_VAR_billing_account is not set, or is not the id of a billing account, which reads like 01ABCD-234567-89EFGH"

# gcloud names the billing account in its errors about it, and a refusal is the likeliest thing for
# it to say here. So a command given the account shows what it wrote to stderr with the id replaced
# by its name.
billing_hidden() {
    local errors status=0
    errors="$(mktemp)"
    "$@" 2> "$errors" || status=$?
    sed "s/${billing}/<billing account>/g" "$errors" >&2
    rm -f "$errors"
    return "$status"
}

service_account="infra-config@${project}.iam.gserviceaccount.com"

# -- the custom roles the configuration grants ----------------------------------
#
# They are made here, not by the configuration: the configuration's identity may grant
# hostingPublisher and signInUsers on the project, and IAM's limit on that grant holds only if the
# identity cannot change the role it grants ("Don't include ... Custom roles that the limited IAM admin can
# modify", IAM, Set limits on granting roles). So that identity holds no right to change any role,
# and a change to a role's permissions is a change here, run again before the merge (R13).

# api's deployment, granted on its service and each of its jobs: it reads them, sets the image of
# each, runs the jobs and rolls a new revision, and nothing else — no create, no delete, no IAM
# (R11).
deployer_role=apiDeployer
deployer_permissions=(
    run.services.get
    run.services.update
    run.revisions.get
    run.revisions.list
    run.operations.get
    run.jobs.get
    run.jobs.update
    run.jobs.run
    run.jobs.runWithOverrides
    run.executions.get
    run.executions.list
)

# The publisher of app's build, granted on the project, since Hosting takes no grant on a site:
# Firebase Hosting Admin less firebasehosting.sites.create and .delete, so that the site app's
# address is cannot be made anew or deleted by the Firebase CLI (R12).
publisher_role=hostingPublisher
publisher_permissions=(
    firebase.clients.get
    firebase.clients.list
    firebase.projects.get
    firebasehosting.sites.get
    firebasehosting.sites.list
    firebasehosting.sites.update
    resourcemanager.projects.get
    resourcemanager.projects.list
)

# api's own identity, granted on the project, since sign-in takes no grant on anything smaller: it
# reads a user — the check of a token for revocation and the list the operator's job goes through —,
# revokes a user's tokens and deletes the user, and nothing else (R16). Firebase Authentication
# Admin would hand api firebaseauth.configs.update too, and with it the settings of sign-in that
# the configuration holds.
sign_in_role=signInUsers
sign_in_permissions=(
    firebaseauth.users.get
    firebaseauth.users.update
    firebaseauth.users.delete
)

# -- what the configuration's identity may do -------------------------------------
#
# Enumerated rather than Owner: enough to make everything the configuration describes, and nothing
# beyond this project. Each line is a role and the types of resource and data in tofu/ it is held
# for, and just tf-check refuses a type of the configuration that no line names, or a line that
# names a type no longer there. The pool and its provider are not among them: what the identity
# signs in through is not its to change. Nor is iam.roleAdmin (above).
project_roles=(
    "roles/serviceusage.serviceUsageAdmin google_project_service"
    "roles/browser data.google_project"
    "roles/artifactregistry.admin google_artifact_registry_repository google_artifact_registry_repository_iam_member"
    "roles/run.admin google_cloud_run_v2_service google_cloud_run_v2_service_iam_member google_cloud_run_v2_job google_cloud_run_v2_job_iam_member"
    "roles/iam.serviceAccountAdmin google_service_account google_service_account_iam_member"
    "roles/iam.serviceAccountUser google_cloud_run_v2_service google_cloud_run_v2_job google_cloud_scheduler_job"
    "roles/secretmanager.admin google_secret_manager_secret google_secret_manager_secret_iam_member"
    "roles/cloudscheduler.admin google_cloud_scheduler_job"
    "roles/firebase.admin google_firebase_project google_firebase_hosting_site google_firebase_web_app data.google_firebase_web_app_config google_identity_platform_config"
    "roles/monitoring.notificationChannelEditor google_monitoring_notification_channel"
    "roles/monitoring.alertPolicyEditor google_monitoring_alert_policy"
    "roles/logging.configWriter google_logging_project_bucket_config google_logging_project_sink"
    "roles/observability.editor google_observability_project_settings"
)

# The spend alert lives on the billing account, outside the project's policy.
billing_roles=(
    "roles/billing.costsManager google_billing_budget"
)

# Who holds what in the project may be changed for two roles alone, the publisher's and api's of
# sign-in: without the condition this role would make the identity the project's owner in all but
# name.
admin_roles=(
    "roles/resourcemanager.projectIamAdmin google_project_iam_member"
)
admin_role="${admin_roles[0]%% *}"
expression="api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly(['projects/${project}/roles/${publisher_role}', 'projects/${project}/roles/${sign_in_role}'])"

# -- the steps ------------------------------------------------------------------

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

project_exists() { gcloud projects describe "$project"; }
make_project() { gcloud projects create "$project" --name="NovaTrail"; }

bucket_exists() { gcloud storage buckets describe "gs://${bucket}"; }
make_bucket() {
    gcloud storage buckets create "gs://${bucket}" \
        --project="$project" \
        --location="$region" \
        --uniform-bucket-level-access \
        --public-access-prevention
}

pool_exists() { gcloud iam workload-identity-pools describe "$pool" --project="$project" --location=global; }
make_pool() {
    gcloud iam workload-identity-pools create "$pool" \
        --project="$project" \
        --location=global \
        --display-name="GitHub Actions"
}

provider_exists() {
    gcloud iam workload-identity-pools providers describe github \
        --project="$project" --location=global --workload-identity-pool="$pool"
}
make_provider() {
    gcloud iam workload-identity-pools providers create-oidc github \
        --project="$project" \
        --location=global \
        --workload-identity-pool="$pool" \
        --display-name="GitHub Actions" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="$mapping" \
        --attribute-condition="$condition"
}

identity_exists() { gcloud iam service-accounts describe "$service_account" --project="$project"; }
make_identity() {
    gcloud iam service-accounts create infra-config \
        --project="$project" \
        --display-name="Identity the configuration is applied as"
}

# A custom role, made, or brought back to what is written here. One deleted not long ago still
# holds its id and is undeleted. One deleted longer ago may hold its id while it can no longer be
# undeleted; the create is then refused, and the script stops on that refusal. A describe that fails
# for any other reason than that the role is not there is tried again, and stops the script if it
# keeps failing: read as no role, it would send the script to make one that exists.
custom_role() {
    local id="$1" title="$2" description="$3"
    shift 3
    local permissions deleted
    permissions="$(IFS=,; echo "$*")"
    if ! deleted="$(gcloud iam roles describe "$id" --project="$project" --format='value(deleted)' 2> "$work/role-error")"; then
        if grep -q NOT_FOUND "$work/role-error"; then
            retry gcloud iam roles create "$id" --project="$project" \
                --title="$title" --description="$description" --permissions="$permissions" --stage=GA --quiet
            echo "    projects/${project}/roles/${id}: made"
            return
        fi
        deleted="$(retry_read gcloud iam roles describe "$id" --project="$project" --format='value(deleted)')"
    fi
    if [[ "$deleted" == "True" ]]; then
        retry gcloud iam roles undelete "$id" --project="$project" --quiet
    fi
    retry gcloud iam roles update "$id" --project="$project" \
        --title="$title" --description="$description" --permissions="$permissions" --stage=GA --quiet
    echo "    projects/${project}/roles/${id}"
}

# Who holds what, out of a policy read as lines of role, member and condition, tab-separated: the
# roles one member holds, each with its condition, or nothing.
held_by() {
    local who="$1" policy="$2"
    awk -F '\t' -v who="$who" '$2 == who { print $1 "\t" $3 }' <<< "$policy"
}

# The billing account is read first: its currency is the budget's, and a budget in another one would
# be refused only at the first apply, after a merge.
echo "==> billing account"
billed_in="$(billing_hidden gcloud billing accounts describe "$billing" --format='value(currencyCode)')"
if [[ -z "$billed_in" ]]; then
    echo "    its currency is not shown: compare it with budget_currency (${currency}) in the billing console"
elif [[ "$billed_in" != "$currency" ]]; then
    fail "the billing account is billed in ${billed_in}, and budget_currency in ${tfvars##*/} is ${currency}"
fi

echo "==> project ${project}"
ensure project_exists make_project
# A project marked for deletion is still found, and is not the script's to bring back.
if [[ "$(retry_read gcloud projects describe "$project" --format='value(lifecycleState)')" == DELETE_REQUESTED ]]; then
    fail "the project ${project} is marked for deletion: bring it back by hand, gcloud projects undelete, if it is the one to keep"
fi
project_number="$(retry_read gcloud projects describe "$project" --format='value(projectNumber)')"
# The budget counts the spend of the account the project pays through, so it is that account or
# none: a project already paid for by another is not moved here.
linked="$(billing_hidden retry_read gcloud billing projects describe "$project" --format='value(billingAccountName)')"
if [[ -z "$linked" ]]; then
    retry billing_hidden gcloud billing projects link "$project" --billing-account="$billing"
    echo "    linked to the billing account"
elif [[ "$linked" != "billingAccounts/${billing}" ]]; then
    fail "the project pays through another billing account than TF_VAR_billing_account: link it by hand, or give that account"
fi

# Without the first six nothing below can be made, and they are why this script exists rather than
# one more file of the configuration. Observability is here because its settings refuse requests
# for a while after the API is enabled, so it goes on long before the apply that says where the
# traces are kept (canvas-api). The last four are the services the custom roles name permissions
# of: a permission "might not be available for use in custom roles if you have not enabled the API
# for the service" (IAM, Create and manage custom roles).
echo "==> the APIs this script and the first apply need"
retry gcloud services enable \
    serviceusage.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    sts.googleapis.com \
    iamcredentials.googleapis.com \
    storage.googleapis.com \
    observability.googleapis.com \
    run.googleapis.com \
    firebase.googleapis.com \
    firebasehosting.googleapis.com \
    identitytoolkit.googleapis.com \
    --project="$project"

echo "==> custom roles"
custom_role "$deployer_role" "Deploys api" \
    "Reads api's service and jobs, sets the image of each, runs the jobs and rolls a new revision. Nothing else." \
    "${deployer_permissions[@]}"
custom_role "$publisher_role" "Publishes app's build" \
    "Reads the project and its Hosting sites and releases new versions of them. It makes and deletes no site." \
    "${publisher_permissions[@]}"
custom_role "$sign_in_role" "Manages api's users of sign-in" \
    "Reads users of sign-in, revokes their tokens and deletes them. It changes no setting of sign-in." \
    "${sign_in_permissions[@]}"

echo "==> state bucket gs://${bucket}"
ensure bucket_exists make_bucket
# Versions are what let a state file that was written badly be rolled back.
retry gcloud storage buckets update "gs://${bucket}" --versioning

# Who may sign in through the pool at all: the jobs of infra's repository, by the numbers of its
# owner and of the repository, and nobody else's (R13). Which identity a job may borrow is said by
# each identity, by the environment GitHub names in the job's subject. A pool or a provider deleted
# not long ago is still found, and is undeleted; one that exists is given this condition again, so
# that what is written here is what holds.
echo "==> federated pool ${pool}"
ensure pool_exists make_pool
if [[ "$(retry_read gcloud iam workload-identity-pools describe "$pool" --project="$project" --location=global --format='value(state)')" == DELETED ]]; then
    retry gcloud iam workload-identity-pools undelete "$pool" --project="$project" --location=global
    echo "    undeleted"
fi

echo "==> pool provider github"
mapping="google.subject=assertion.sub"
condition="assertion.repository_owner_id=='${owner_id}' && assertion.repository_id=='${repository_id}'"
if provider_exists > /dev/null 2>&1; then
    if [[ "$(retry_read gcloud iam workload-identity-pools providers describe github --project="$project" --location=global --workload-identity-pool="$pool" --format='value(state)')" == DELETED ]]; then
        retry gcloud iam workload-identity-pools providers undelete github \
            --project="$project" --location=global --workload-identity-pool="$pool"
        echo "    undeleted"
    fi
    retry gcloud iam workload-identity-pools providers update-oidc github \
        --project="$project" \
        --location=global \
        --workload-identity-pool="$pool" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="$mapping" \
        --attribute-condition="$condition"
else
    ensure provider_exists make_provider
fi

echo "==> identity ${service_account}"
ensure identity_exists make_identity
member="serviceAccount:${service_account}"

# What the identity holds and this script does not name is taken back first, under whatever
# condition, on the project, on the state bucket and on the billing account, so that the lists
# below are the whole of it. A binding comes off with every condition it is held under, since gcloud
# names a condition to take back by its title too; so what is named is granted after, and a role held
# both bare and under a condition comes back bare. The IAM admin role is seen to on its own, below.
# Which version of a policy gcloud reads it chooses itself: "These tools specify the version
# automatically" (IAM, Allow policies). In version 3 a binding under a condition carries its
# expression; in version 1 IAM "appends the string _withcond_ to the role name, followed by a hash
# value", and gives no condition. So the IAM admin role is matched as a prefix, as canvas-api matched
# it, and the first run checks that the condition comes back (T23).
read_project_policy() {
    retry_read gcloud projects get-iam-policy "$project" \
        --flatten='bindings[].members' \
        --format='value(bindings.role,bindings.members,bindings.condition.expression)'
}
wanted=()
for entry in "${project_roles[@]}"; do
    wanted+=("${entry%% *}")
done
billing_wanted=()
for entry in "${billing_roles[@]}"; do
    billing_wanted+=("${entry%% *}")
done

echo "==> what it holds and is not named here"
policy="$(read_project_policy)"
while IFS=$'\t' read -r role held_under; do
    [[ -n "$role" && "$role" != "$admin_role"* ]] || continue
    [[ -z "$held_under" && " ${wanted[*]} " == *" ${role} "* ]] && continue
    retry gcloud projects remove-iam-policy-binding "$project" \
        --member="$member" --role="$role" --all --quiet
    echo "    ${role}${held_under:+ under a condition}: taken back"
done < <(held_by "$member" "$policy")

bucket_policy="$(retry_read gcloud storage buckets get-iam-policy "gs://${bucket}" \
    --flatten='bindings[].members' --format='value(bindings.role,bindings.members,bindings.condition.expression)')"
while IFS=$'\t' read -r role held_under; do
    [[ -n "$role" ]] || continue
    [[ -z "$held_under" && "$role" == roles/storage.objectAdmin ]] && continue
    retry gcloud storage buckets remove-iam-policy-binding "gs://${bucket}" \
        --member="$member" --role="$role" --all --quiet
    echo "    ${role} on gs://${bucket}: taken back"
done < <(held_by "$member" "$bucket_policy")

billing_policy="$(billing_hidden retry_read gcloud billing accounts get-iam-policy "$billing" \
    --flatten='bindings[].members' --format='value(bindings.role,bindings.members,bindings.condition.expression)')"
while IFS=$'\t' read -r role _; do
    [[ -n "$role" && " ${billing_wanted[*]} " != *" ${role} "* ]] || continue
    retry billing_hidden gcloud billing accounts remove-iam-policy-binding "$billing" \
        --member="$member" --role="$role" --quiet
    echo "    ${role} on the billing account: taken back"
done < <(held_by "$member" "$billing_policy")

echo "==> what it may do"
for role in "${wanted[@]}"; do
    retry gcloud projects add-iam-policy-binding "$project" \
        --member="$member" --role="$role" --condition=None --quiet
    echo "    $role"
done

retry gcloud storage buckets add-iam-policy-binding "gs://${bucket}" \
    --member="$member" --role=roles/storage.objectAdmin --quiet
echo "    roles/storage.objectAdmin on gs://${bucket}"

for role in "${billing_wanted[@]}"; do
    retry billing_hidden gcloud billing accounts add-iam-policy-binding "$billing" \
        --member="$member" --role="$role" --quiet
    echo "    ${role} on the billing account"
done

# IAM tells bindings apart by their condition, so a condition written anew would be granted beside
# the one before it, and a role taken out of it would stay grantable under the old binding. So the
# role is held under this expression alone: under any other, or none, it is taken back first, and
# when it is held under this one, nothing is touched. The condition goes in from a file, since the
# commas in it would split it on the command line.
cat > "$work/condition" << CONDITION
expression: ${expression}
title: The publisher's role and api's of sign-in alone
description: Grants and revokes on the project only the roles the publisher of app's build and api's sign-in hold.
CONDITION
held="$(held_by "$member" "$policy" | awk -F '\t' -v role="$admin_role" 'index($1, role) == 1 { print "held under: " $2 }')"
if [[ "$held" != "held under: ${expression}" ]]; then
    if [[ -n "$held" ]]; then
        retry gcloud projects remove-iam-policy-binding "$project" \
            --member="$member" --role="$admin_role" --all --quiet
        echo "    ${admin_role} under another condition: taken back"
    fi
    retry gcloud projects add-iam-policy-binding "$project" \
        --member="$member" --role="$admin_role" --condition-from-file="$work/condition" --quiet
fi
echo "    ${admin_role}, for the publisher's role and api's of sign-in alone"

# The identity may act as any service account of the project: it makes them, and the right to say
# who may act as them is the right to act as them, for each of them. So none of the project's own
# service accounts may hold Owner or Editor, through which acting as it would reach past every limit
# above — the default one of Compute Engine and of App Engine among them, which Google grants
# Editor on its own where no organization says otherwise, and this project has none (Д3). The
# configuration never enables Compute Engine or App Engine; this takes the role back from any that
# holds it at each run, and an account given one between two runs holds it until the next (R13).
# Google's own service agents are not the project's accounts and are left alone.
echo "==> basic roles of the project's service accounts"
policy="$(read_project_policy)"
taken=0
while IFS=$'\t' read -r role holder _; do
    [[ "$role" == roles/owner || "$role" == roles/editor ]] || continue
    case "$holder" in
        "serviceAccount:"*"@${project}.iam.gserviceaccount.com" | \
            "serviceAccount:${project_number}-compute@developer.gserviceaccount.com" | \
            "serviceAccount:${project}@appspot.gserviceaccount.com") ;;
        *) continue ;;
    esac
    retry gcloud projects remove-iam-policy-binding "$project" \
        --member="$holder" --role="$role" --all --quiet
    echo "    ${role} of ${holder#serviceAccount:}: taken back"
    taken=$((taken + 1))
done <<< "$policy"
[[ "$taken" -gt 0 ]] || echo "    none holds Owner or Editor"

# Who may borrow it: the jobs of the environment production-config of this repository, by the
# subject GitHub gives them, and nobody else in any role on the identity. What else its policy holds
# is taken back first, and the one borrower granted after, as above.
echo "==> who may borrow it"
borrower="principal://iam.googleapis.com/projects/${project_number}/locations/global/workloadIdentityPools/${pool}/subject/${subject_prefix}:environment:${config_environment}"
borrowers="$(retry_read gcloud iam service-accounts get-iam-policy "$service_account" --project="$project" \
    --flatten='bindings[].members' --format='value(bindings.role,bindings.members,bindings.condition.expression)')"
while IFS=$'\t' read -r role holder held_under; do
    [[ -n "$role" ]] || continue
    [[ "$role" == roles/iam.workloadIdentityUser && "$holder" == "$borrower" && -z "$held_under" ]] && continue
    retry gcloud iam service-accounts remove-iam-policy-binding "$service_account" \
        --project="$project" --member="$holder" --role="$role" --all --quiet
    echo "    ${role} of ${holder##*/subject/}: not named here, taken back"
done <<< "$borrowers"
retry gcloud iam service-accounts add-iam-policy-binding "$service_account" \
    --project="$project" --member="$borrower" --role=roles/iam.workloadIdentityUser --quiet
echo "    ${borrower##*/subject/}"

provider="projects/${project_number}/locations/global/workloadIdentityPools/${pool}/providers/github"

cat << SUMMARY

Done. A workflow signs in with these two lines; neither is a secret:

GCP_WORKLOAD_IDENTITY_PROVIDER=${provider}
GCP_CONFIG_SERVICE_ACCOUNT=${service_account}

Left to do once, in the repository's settings rather than here: the environment
${config_environment}, which only main may run in, and its secrets TF_VAR_billing_account,
the same id this script was given, and TF_VAR_operator_email, without which no alert is made.
SUMMARY
