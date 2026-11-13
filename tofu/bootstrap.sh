#!/usr/bin/env bash
# Makes, once and with the operator's own rights, what the configuration in this directory cannot
# make for itself (R13): the project and its link to the billing account, the bucket the state
# lives in, the federated pool that CI signs in through and its provider, the identity the
# configuration is applied as and what that identity may do, the three custom roles the
# configuration grants, and the pool github-eval with its provider, which the eval jobs of modules
# and tutor read the keys for eval through (R120 spec; R20). It also makes and keeps the operator's
# bucket and the bucket of the scans of consents: their settings and lifecycle rules, the custom
# roles granted in them, the two upload service accounts and the whole policy of each bucket (R28;
# the 2026-11-13 amendment to R13). Everything else is the configuration's, and CI applies it.
#
# Safe to run again: every step looks before it makes, and what is written here is brought back
# where it has drifted — the provider's condition, the custom roles' permissions, what the
# identity holds on the project, the state bucket and the billing account, and who may borrow it,
# the two buckets' settings, rules and policies, and who may sign as an upload service account.
# What the identity holds and this script does not name is taken back, and so are Owner and Editor
# from every service account of the project (R13), and whatever else the buckets' and the upload
# service accounts' policies hold (R28).
#
# It reads the deployment's values from production.auto.tfvars and backend.hcl beside it, so that
# each is written in one place, and prints at the end the two lines a workflow needs before it can
# sign in at all. The billing account arrives from the environment, as TF_VAR_billing_account, the
# same way it arrives in a plan, and so do the addresses of the organizers and of the operator,
# each in a variable of its own: nothing this script prints holds any of them.
#
# BOOTSTRAP_TOFU_DIR and BOOTSTRAP_RETRY_DELAY are for its test: another directory to read the
# values from, and the seconds between tries.

set -euo pipefail

# gcloud names in its errors the account it runs as, the operator's own, spelled as Google keeps it,
# capitals and all; a member it was given or is taking back, a person this run no longer names among
# them; and the billing account. A refusal is the likeliest thing for it to say here. So all the
# script writes to stderr goes through one filter, which replaces any address of a person, in any
# case, and any billing account's id; a service account's address, which is no person's, stays.
# What it writes to stdout names neither. The filter is waited for at the end, so that its last
# lines come before the shell's prompt.
hide() {
    sed -E \
        -e 's/@([A-Za-z0-9.-]*\.gserviceaccount\.com)/<at>\1/g' \
        -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+/<address>/g' \
        -e 's/<at>/@/g' \
        -e 's/[0-9A-Za-z]{6}-[0-9A-Za-z]{6}-[0-9A-Za-z]{6}/<billing account>/g'
}
exec 2> >(hide >&2)
hider=$!
work=""
finish() {
    [[ -z "$work" ]] || rm -rf "$work"
    exec 2>&-
    wait "$hider" || true
}
trap finish EXIT

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

# A list out of an HCL file, written on its one line, `name = ["a", "b"]`: its values, one a line,
# or nothing when the file does not name it. A list of another form is refused rather than misread.
hcl_list() {
    local name="$1" file="$2" line rest item more
    [[ -f "$file" ]] || return 0
    line="$(sed -n "/^[[:space:]]*${name}[[:space:]]*=/{p;q;}" "$file")"
    [[ -n "$line" ]] || return 0
    [[ "$line" =~ =[[:space:]]*\[([^]#]*)\][[:space:]]*(#.*)?$ ]] || fail "${name} in ${file##*/} is not a list on one line, [\"…\", \"…\"], the one form this script reads"
    rest="${BASH_REMATCH[1]}"
    while [[ "$rest" =~ ^[[:space:]]*\"([^\"]*)\"[[:space:]]*(,?)(.*)$ ]]; do
        item="${BASH_REMATCH[1]}" more="${BASH_REMATCH[2]}" rest="${BASH_REMATCH[3]}"
        printf '%s\n' "$item"
        [[ -n "$more" ]] || break
    done
    [[ "$rest" =~ ^[[:space:]]*$ ]] || fail "${name} in ${file##*/} is not a list on one line, [\"…\", \"…\"], the one form this script reads"
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
operator_bucket="$(hcl_value operator_bucket "$tfvars")"
consent_forms_bucket="$(hcl_value consent_forms_bucket "$tfvars")"
api_service_name="$(hcl_value api_service_name "$tfvars")"
api_service_name="${api_service_name:-api}"

require project_id "$project" '^[a-z][a-z0-9-]{4,28}[a-z0-9]$'
require region "$region" '^[a-z]+-[a-z]+[0-9]+$'
require workload_identity_pool_id "$pool" '^[a-z0-9-]{4,32}$'
require github_oidc_subject_prefix "$subject_prefix" '^repo:[^/@:]+@[0-9]+/[^/@:]+@[0-9]+$'
require budget_currency "$currency" '^[A-Z]{3}$'
require bucket "$bucket" '^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$'
require operator_bucket "$operator_bucket" '^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$'
require consent_forms_bucket "$consent_forms_bucket" '^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$'
require api_service_name "$api_service_name" '^[a-z][a-z0-9-]{0,18}[a-z0-9]$'

# Three buckets of three purposes: the state, the organizers' files and the scans that only the
# operator lists (R28). One name for two would put the policy written for one over the other's files.
[[ "$operator_bucket" != "$consent_forms_bucket" ]] || fail "operator_bucket and consent_forms_bucket are one bucket, ${operator_bucket}: the organizers would list the names of the scans"
for named in "$operator_bucket" "$consent_forms_bucket"; do
    [[ "$named" != "$bucket" ]] || fail "the bucket ${named} of ${tfvars##*/} is the state bucket of ${backend##*/}: learners' files are not kept beside the state"
done

# The numbers GitHub gives the owner and the repository, which nobody else can take over as a name
# can be: repo:OWNER@OWNER_ID/NAME@REPOSITORY_ID.
[[ "$subject_prefix" =~ ^repo:[^/@:]+@([0-9]+)/[^/@:]+@([0-9]+)$ ]]
owner_id="${BASH_REMATCH[1]}"
repository_id="${BASH_REMATCH[2]}"

# The repositories whose jobs of the environment eval read the keys for eval, by the same numbers,
# all of one owner, as the configuration takes them (R120 spec; R20). The pool's id is the one the
# configuration's grants name.
eval_pool=github-eval
[[ "$pool" != "$eval_pool" ]] || fail "workload_identity_pool_id is ${eval_pool}, the pool of eval: the pool the configuration signs in through is another"
eval_list="$(hcl_list eval_github_subject_prefixes "$tfvars")"
eval_owner_id=""
eval_repository_ids=()
while IFS= read -r eval_prefix; do
    [[ -n "$eval_prefix" ]] || continue
    [[ "$eval_prefix" =~ ^repo:[^/@:]+@([0-9]+)/[^/@:]+@([0-9]+)$ ]] || fail "eval_github_subject_prefixes holds ${eval_prefix}, not of the form the configuration takes: repo:OWNER@OWNER_ID/NAME@REPOSITORY_ID"
    [[ -z "$eval_owner_id" || "$eval_owner_id" == "${BASH_REMATCH[1]}" ]] || fail "eval_github_subject_prefixes are of more than one owner, and the condition of ${eval_pool} names one"
    eval_owner_id="${BASH_REMATCH[1]}"
    for known in "${eval_repository_ids[@]}"; do
        [[ "$known" != "${BASH_REMATCH[2]}" ]] || fail "eval_github_subject_prefixes names the repository ${BASH_REMATCH[2]} twice, which the configuration refuses"
    done
    eval_repository_ids+=("${BASH_REMATCH[2]}")
done <<< "$eval_list"

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

# The people who hold the operator's buckets, each a Google account by a variable of its own, never
# by a file of the repository (R28): the measurement organizer, the eval-set organizer, and the
# operator, who lists and reads the scans of consents. A variable not set is a refusal, since a run
# from a shell that lacks it would take that person's access away; none means no binding for them.
# Today all three are the author (R139 spec). The address of the alerts, TF_VAR_operator_email, is
# not reused: it may be a list, not an account. An address is never printed, not even in a refusal.
person() {
    local name="$1" who="$2" value
    [[ -n "${!name:-}" ]] || fail "${name} is not set: the address of the ${who}'s Google account, or none for no binding"
    value="${!name}"
    value="${value,,}"
    [[ "$value" == none || "$value" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || fail "${name} is neither the address of a Google account nor none"
    printf '%s' "$value"
}
measure_organizer="$(person BOOTSTRAP_MEASURE_ORGANIZER "measurement organizer")"
eval_set_organizer="$(person BOOTSTRAP_EVAL_SET_ORGANIZER "eval-set organizer")"
operator="$(person BOOTSTRAP_OPERATOR operator)"

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
# Firebase Hosting Admin less firebasehosting.sites.create and .delete, so that the site that is
# app's address cannot be made anew or deleted by the publisher (R12), and less
# resourcemanager.projects.list, which a role of a project cannot hold: IAM refuses it as "not
# valid" there (T23).
publisher_role=hostingPublisher
publisher_permissions=(
    firebase.clients.get
    firebase.clients.list
    firebase.projects.get
    firebasehosting.sites.get
    firebasehosting.sites.list
    firebasehosting.sites.update
    resourcemanager.projects.get
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

# The roles of the operator's bucket and of the scans' bucket, which this script alone grants, in
# the buckets' own policies (R28). Each organizer lists the whole operator's bucket, as a list is
# granted on the bucket and no condition on names narrows it (sources 10.2); what they read, write
# and erase, roles/storage.objectUser grants them under a condition on their prefixes.
lister_role=operatorBucketLister
lister_permissions=(
    storage.objects.list
)

# api's own identity on the scans' prefix: it puts each scan under a new name and erases one by a
# name from its database, and reads and lists none; an insert that overwrites nothing needs no more
# (sources 10.2, 10.5).
consent_writer_role=consentFormsWriter
consent_writer_permissions=(
    storage.objects.create
    storage.objects.delete
)

# What an upload link may do, as the upload service account that signs it: put a new object under
# its organizer's upload prefixes, and neither read, list, overwrite nor erase one (R28).
uploader_role=bucketUploader
uploader_permissions=(
    storage.objects.create
)

# -- what the configuration's identity may do -------------------------------------
#
# Enumerated rather than Owner: enough to make everything the configuration describes, and nothing
# beyond this project. Each line is a role and the types of resource and data in tofu/ it is held
# for, and just tf-check refuses a type of the configuration that no line names, or a line that
# names a type no longer there. The pools and their providers are not among them: what the identity
# signs in through is not its to change, and no condition of IAM narrows a right over pools to one,
# so this script makes both pools. Nor is iam.roleAdmin (above).
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

# The pool at hand, at_pool, and its provider, by federated_pool below.
pool_exists() { gcloud iam workload-identity-pools describe "$at_pool" --project="$project" --location=global; }
make_pool() {
    gcloud iam workload-identity-pools create "$at_pool" \
        --project="$project" \
        --location=global \
        --display-name="$at_name"
}

provider_exists() {
    gcloud iam workload-identity-pools providers describe github \
        --project="$project" --location=global --workload-identity-pool="$at_pool"
}
make_provider() {
    gcloud iam workload-identity-pools providers create-oidc github \
        --project="$project" \
        --location=global \
        --workload-identity-pool="$at_pool" \
        --display-name="$at_name" \
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
billed_in="$(gcloud billing accounts describe "$billing" --format='value(currencyCode)')"
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
linked="$(retry_read gcloud billing projects describe "$project" --format='value(billingAccountName)')"
if [[ -z "$linked" ]]; then
    retry gcloud billing projects link "$project" --billing-account="$billing"
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
custom_role "$lister_role" "Lists the operator's bucket" \
    "Lists the names of the objects of the operator's bucket, and reads none of them." \
    "${lister_permissions[@]}"
custom_role "$consent_writer_role" "Writes api's scans of consents" \
    "Creates and erases the scans of consents under api's prefix, and reads and lists none." \
    "${consent_writer_permissions[@]}"
custom_role "$uploader_role" "Uploads to the operator's bucket" \
    "Creates new objects under an organizer's upload prefixes, and reads, overwrites and erases none." \
    "${uploader_permissions[@]}"

echo "==> state bucket gs://${bucket}"
ensure bucket_exists make_bucket
# Versions are what let a state file that was written badly be rolled back.
retry gcloud storage buckets update "gs://${bucket}" --versioning

# Who may sign in through a pool at all, said by its provider's condition. A pool or a provider
# deleted not long ago is still found, and is undeleted; one that exists is given its condition
# again, so that what is written here is what holds.
federated_pool() {
    at_pool="$1" at_name="$2" condition="$3"
    echo "==> federated pool ${at_pool}"
    ensure pool_exists make_pool
    if [[ "$(retry_read gcloud iam workload-identity-pools describe "$at_pool" --project="$project" --location=global --format='value(state)')" == DELETED ]]; then
        retry gcloud iam workload-identity-pools undelete "$at_pool" --project="$project" --location=global
        echo "    undeleted"
    fi

    echo "==> pool provider github of ${at_pool}"
    if provider_exists > /dev/null 2>&1; then
        if [[ "$(retry_read gcloud iam workload-identity-pools providers describe github --project="$project" --location=global --workload-identity-pool="$at_pool" --format='value(state)')" == DELETED ]]; then
            retry gcloud iam workload-identity-pools providers undelete github \
                --project="$project" --location=global --workload-identity-pool="$at_pool"
            echo "    undeleted"
        fi
        retry gcloud iam workload-identity-pools providers update-oidc github \
            --project="$project" \
            --location=global \
            --workload-identity-pool="$at_pool" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-mapping="$mapping" \
            --attribute-condition="$condition"
    else
        ensure provider_exists make_provider
    fi
}

# The jobs of infra's repository, by the numbers of its owner and of the repository, and nobody
# else's (R13). Which identity a job may borrow is said by each identity, by the environment GitHub
# names in the job's subject.
mapping="google.subject=assertion.sub"
federated_pool "$pool" "GitHub Actions" "assertion.repository_owner_id=='${owner_id}' && assertion.repository_id=='${repository_id}'"

# The jobs of the environment eval of modules and tutor, which read the platform's keys for eval and
# nothing else: no identity is lent through this pool, and the module grants its principals the
# secrets of eval alone. Dependabot's are not let in, though its workflows may ask for a token
# (R120 spec). The pool is made here and not by the configuration, which would need the right to
# change every pool of the project, the one it signs in through among them (R20). With no
# repository of eval, it is not made; one made before is kept, as a pool's id is not taken again
# for 30 days after it is deleted, and its provider is given the condition false, which admits
# nobody.
if ((${#eval_repository_ids[@]})); then
    eval_repositories="$(printf " || assertion.repository_id=='%s'" "${eval_repository_ids[@]}")"
    federated_pool "$eval_pool" "GitHub Actions, eval" "assertion.repository_owner_id=='${eval_owner_id}' && (${eval_repositories# || }) && assertion.environment=='eval' && assertion.actor!='dependabot[bot]'"
else
    at_pool="$eval_pool"
    if pool_exists > /dev/null 2>&1 && provider_exists > /dev/null 2>&1; then
        echo "==> pool provider github of ${eval_pool}: no repository of eval, so it admits nobody"
        retry gcloud iam workload-identity-pools providers update-oidc github \
            --project="$project" \
            --location=global \
            --workload-identity-pool="$eval_pool" \
            --attribute-condition="false"
    fi
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

billing_policy="$(retry_read gcloud billing accounts get-iam-policy "$billing" \
    --flatten='bindings[].members' --format='value(bindings.role,bindings.members,bindings.condition.expression)')"
while IFS=$'\t' read -r role _; do
    [[ -n "$role" && " ${billing_wanted[*]} " != *" ${role} "* ]] || continue
    retry gcloud billing accounts remove-iam-policy-binding "$billing" \
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
    retry gcloud billing accounts add-iam-policy-binding "$billing" \
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

# -- the operator's buckets (R28) -------------------------------------------------
#
# The policy of a bucket is one resource, and the configuration would grant it at each apply of CI,
# so the buckets and all their access are made here, as the pools and the custom roles are (the
# 2026-11-13 amendment to R13). How they are built and why is docs/architecture.md, section 3.7.

# A member of a policy as the script names it in what it prints: a person by what they are, never
# by their address, also once their account is deleted.
shown() {
    case "$1" in
        user:* | group:* | domain:*) echo "a ${1%%:*}" ;;
        deleted:*) echo "a deleted account" ;;
        *) echo "$1" ;;
    esac
}

# A policy, brought to exactly the bindings given: each binding a line of role, member, condition's
# expression, its title and what the script prints of it, apart by the unit separator, the
# expression and the title empty for a binding with none. What the policy holds beyond them, under
# any condition, is taken back; then a binding given and not held under its very expression is
# granted, and a binding held as it is given is left alone. IAM tells bindings apart by their
# condition, and gcloud takes a member's role back under every condition at once, so a member whose
# role is taken back under one is granted the others again. A condition goes in from a file, since
# its commas would split it on the command line. Which version of the policy gcloud reads it chooses
# itself (R13); in version 1 a binding under a condition would read as a role named
# <role>_withcond_<hash>, not given, and taking it back by that name would fail and stop the script
# rather than pass by it. On the project it reads a bucket's conditions as they are (T49). A member
# is compared in any case: IAM keeps a person's address as Google spells the account, capitals and
# all, and this script takes it in lower case, so that a run would otherwise take each person's
# binding back and grant it again (T49). One is taken back as IAM spells it.
#   keep_policy bucket <name> <bindings>...
#   keep_policy account <email> <bindings>...
keep_policy() {
    local kind="$1" target="$2"
    shift 2
    local -a group at
    case "$kind" in
        bucket) group=(storage buckets) at=("gs://${target}") ;;
        account) group=(iam service-accounts) at=("$target" --project="$project") ;;
    esac
    local line role holder held_under expression title label sep=$'\x1f'
    local given=$'\n' held=$'\n' cleared=$'\n' policy
    for line in "$@"; do
        IFS="$sep" read -r role holder expression _ <<< "$line"
        given+="${role}${sep}${holder,,}${sep}${expression}"$'\n'
    done
    policy="$(retry_read gcloud "${group[@]}" get-iam-policy "${at[@]}" \
        --flatten='bindings[].members' --format='value(bindings.role,bindings.members,bindings.condition.expression)')"
    while IFS=$'\t' read -r role holder held_under; do
        [[ -n "$role" ]] || continue
        held+="${role}${sep}${holder,,}${sep}${held_under}"$'\n'
        [[ "$given" == *$'\n'"${role}${sep}${holder,,}${sep}${held_under}"$'\n'* ]] && continue
        [[ "$cleared" == *$'\n'"${role}${sep}${holder,,}"$'\n'* ]] && continue
        retry gcloud "${group[@]}" remove-iam-policy-binding "${at[@]}" \
            --member="$holder" --role="$role" --all --quiet
        cleared+="${role}${sep}${holder,,}"$'\n'
        echo "    ${role} of $(shown "$holder")${held_under:+ under a condition}: not named here, taken back"
    done <<< "$policy"
    for line in "$@"; do
        IFS="$sep" read -r role holder expression title label <<< "$line"
        if [[ "$cleared" != *$'\n'"${role}${sep}${holder,,}"$'\n'* && "$held" == *$'\n'"${role}${sep}${holder,,}${sep}${expression}"$'\n'* ]]; then
            echo "    ${label}"
            continue
        fi
        if [[ -z "$expression" ]]; then
            retry gcloud "${group[@]}" add-iam-policy-binding "${at[@]}" \
                --member="$holder" --role="$role" --condition=None --quiet
        else
            printf 'expression: %s\ntitle: %s\n' "$expression" "$title" > "$work/binding-condition"
            retry gcloud "${group[@]}" add-iam-policy-binding "${at[@]}" \
                --member="$holder" --role="$role" --condition-from-file="$work/binding-condition" --quiet
        fi
        echo "    ${label}: granted"
    done
}

# A binding, as keep_policy takes it.
binding() {
    local IFS=$'\x1f'
    echo "$*"
}

# The condition on objects whose names start with one of the prefixes given, in the bucket given.
under() {
    local in="$1" prefix expression=""
    shift
    for prefix in "$@"; do
        expression+="${expression:+ || }resource.name.startsWith('projects/_/buckets/${in}/objects/${prefix}')"
    done
    echo "$expression"
}

# A bucket of learners' files, made, or brought back to its settings: in the region, of the class
# Standard, with uniform access, public access prevention enforced, no soft delete, no object
# versions and no CORS (R28; sources 10.3, 10.7). It is the project's own or none: names are
# global, and a bucket of the name in another project, the operator's own among them, would get
# these rules and this policy over its files, so it is looked for among the project's buckets, and
# the create of a name taken elsewhere is refused and stops the script. Its place cannot change once
# it is made, so a bucket of the project found in another place stops the script too.
at_bucket=""
data_bucket_exists() {
    gcloud storage buckets list --project="$project" --format='value(name)' | grep -qxF "$at_bucket"
}
make_data_bucket() {
    gcloud storage buckets create "gs://${at_bucket}" \
        --project="$project" \
        --location="$region" \
        --default-storage-class=STANDARD \
        --uniform-bucket-level-access \
        --public-access-prevention \
        --soft-delete-duration=0
}
data_bucket() {
    at_bucket="$1"
    local lifecycle="$2" location
    echo "==> bucket gs://${at_bucket}"
    ensure data_bucket_exists make_data_bucket
    location="$(retry_read gcloud storage buckets describe "gs://${at_bucket}" --format='value(location)')"
    [[ "${location,,}" == "${region,,}" ]] || fail "the bucket gs://${at_bucket} is in ${location:-no place shown}, not in ${region}: a bucket's place cannot change, so move its files to a bucket made anew in the region, by hand"
    local -a rules=(--clear-lifecycle)
    [[ -z "$lifecycle" ]] || rules=(--lifecycle-file="$lifecycle")
    retry gcloud storage buckets update "gs://${at_bucket}" \
        --default-storage-class=STANDARD \
        --uniform-bucket-level-access \
        --public-access-prevention \
        --clear-soft-delete \
        --no-versioning \
        --clear-cors \
        "${rules[@]}"
    echo "    in ${region}, Standard, uniform access, public access prevented, no soft delete, no versions, no CORS"
    if [[ -n "$lifecycle" ]]; then echo "    its lifecycle rules"; else echo "    no lifecycle rule"; fi
}

# The lifecycle of the operator's bucket, docs/architecture.md, section 3.7. Rules of one action
# hold where any of them matches, and a rule's conditions where all of them do (sources 10.7). The
# files of a session are erased by their age, as nobody rewrites one; what an organizer may rewrite,
# by the Custom-Time the organizer's tool sets: two years are at least 730 days and five years at
# most 1827, and the link adds up to half a day to the session (sources 10.3).
cat > "$work/lifecycle.json" << 'LIFECYCLE'
{
  "lifecycle": {
    "rule": [
      { "action": { "type": "Delete" }, "condition": { "age": 728, "matchesPrefix": ["measure/samples/", "child/samples/"] } },
      { "action": { "type": "Delete" }, "condition": { "daysSinceCustomTime": 728, "matchesPrefix": ["measure/records/", "child/records/", "measure/reports/", "child/reports/"] } },
      { "action": { "type": "Delete" }, "condition": { "daysSinceCustomTime": 1827, "matchesPrefix": ["measure/forms/", "child/forms/"] } },
      { "action": { "type": "Delete" }, "condition": { "age": 364, "matchesPrefix": ["eval-set/forms/"] } },
      { "action": { "type": "Delete" }, "condition": { "daysSinceCustomTime": 364, "matchesPrefix": ["eval-set/forms/"] } }
    ]
  }
}
LIFECYCLE

# The scans have no rule: a scan's period is its consent's and five years, and api's sweep erases it
# (R116, R136 spec).
data_bucket "$operator_bucket" "$work/lifecycle.json"
data_bucket "$consent_forms_bucket" ""

# The service accounts an upload link is signed as, one per organizer, so that one's link does not
# reach the other's prefixes (R28). Each holds nothing on the project, and its own policy lends it to
# its organizer alone, by the Token Creator, which signs blobs (sources 10.2).
at_account=""
upload_account_exists() { gcloud iam service-accounts describe "${at_account}@${project}.iam.gserviceaccount.com" --project="$project"; }
make_upload_account() {
    gcloud iam service-accounts create "$at_account" \
        --project="$project" \
        --display-name="Signs the ${at_account#upload-} organizer's upload links"
}
upload_account() {
    at_account="$1"
    local organizer="$2" who="$3"
    local email="${at_account}@${project}.iam.gserviceaccount.com"
    local -a bindings=()
    echo "==> upload service account ${email}"
    ensure upload_account_exists make_upload_account
    # Whoever signs as it may act as it in full, so a role on the project would carry an upload link,
    # and the organizer, past create-only.
    local role held_under on_project
    on_project="$(read_project_policy)"
    while IFS=$'\t' read -r role held_under; do
        [[ -n "$role" ]] || continue
        retry gcloud projects remove-iam-policy-binding "$project" \
            --member="serviceAccount:${email}" --role="$role" --all --quiet
        echo "    ${role}${held_under:+ under a condition} on the project: taken back"
    done < <(held_by "serviceAccount:${email}" "$on_project")
    if [[ "$organizer" == none ]]; then
        echo "    the ${who}: none, so nobody signs as it"
    else
        bindings+=("$(binding roles/iam.serviceAccountTokenCreator "user:${organizer}" "" "" "roles/iam.serviceAccountTokenCreator of the ${who}")")
    fi
    keep_policy account "$email" "${bindings[@]}"
}
upload_account upload-measure "$measure_organizer" "measurement organizer"
upload_account upload-eval-set "$eval_set_organizer" "eval-set organizer"

# api's identity is the configuration's, made by the first apply. Until then the scans' bucket is
# made without its binding, and the script is run again after that apply. A look that fails for
# another reason than that it is not there is tried again, and stops the script if it keeps failing:
# read as no identity, it would take api's right away.
api_account="${api_service_name}-run@${project}.iam.gserviceaccount.com"
api_exists=true
if ! gcloud iam service-accounts describe "$api_account" --project="$project" > /dev/null 2> "$work/api-error"; then
    if grep -q NOT_FOUND "$work/api-error"; then
        api_exists=false
    else
        retry_read gcloud iam service-accounts describe "$api_account" --project="$project" > /dev/null
    fi
fi

custom="projects/${project}/roles"
# Each bucket keeps one of the bindings Cloud Storage gives a new bucket: the project's owners, as
# legacyBucketOwner. The basic role Owner holds no storage.buckets.get, update, getIamPolicy or
# setIamPolicy of its own, only through this binding (sources 10.9), so a policy without it would
# shut out whoever runs this script, the operator, who could then neither keep the bucket nor give
# its access back; the first run on the project did so (T49). The role reads no object: it lists
# them, creates and erases them, and keeps the bucket and its policy. The other bindings of a new
# bucket, of the project's editors and viewers and the owners' object roles, are taken back.
owners="$(binding roles/storage.legacyBucketOwner "projectOwner:${project}" "" "" "roles/storage.legacyBucketOwner of the project's owners")"
operator_bindings=("$owners")
if [[ "$measure_organizer" != none ]]; then
    operator_bindings+=(
        "$(binding roles/storage.objectUser "user:${measure_organizer}" "$(under "$operator_bucket" measure/ child/)" "measure and child" "roles/storage.objectUser of the measurement organizer, under measure/ and child/")"
        "$(binding "${custom}/${lister_role}" "user:${measure_organizer}" "" "" "${lister_role} of the measurement organizer")"
    )
fi
if [[ "$eval_set_organizer" != none ]]; then
    operator_bindings+=(
        "$(binding roles/storage.objectUser "user:${eval_set_organizer}" "$(under "$operator_bucket" eval-set/)" "eval-set" "roles/storage.objectUser of the eval-set organizer, under eval-set/")"
    )
    # One person may be both organizers, and a binding is held once.
    [[ "$eval_set_organizer" == "$measure_organizer" ]] ||
        operator_bindings+=("$(binding "${custom}/${lister_role}" "user:${eval_set_organizer}" "" "" "${lister_role} of the eval-set organizer")")
fi
operator_bindings+=(
    "$(binding "${custom}/${uploader_role}" "serviceAccount:upload-measure@${project}.iam.gserviceaccount.com" "$(under "$operator_bucket" measure/samples/ measure/forms/ child/samples/ child/forms/)" "measure and child uploads" "${uploader_role} of upload-measure, under measure/ and child/, samples/ and forms/")"
    "$(binding "${custom}/${uploader_role}" "serviceAccount:upload-eval-set@${project}.iam.gserviceaccount.com" "$(under "$operator_bucket" eval-set/samples/ eval-set/forms/)" "eval-set uploads" "${uploader_role} of upload-eval-set, under eval-set/samples/ and eval-set/forms/")"
)
echo "==> who holds gs://${operator_bucket}"
keep_policy bucket "$operator_bucket" "${operator_bindings[@]}"

consent_bindings=("$owners")
if [[ "$operator" == none ]]; then
    echo "    the operator: none, so nobody reads the scans"
else
    consent_bindings+=("$(binding roles/storage.objectViewer "user:${operator}" "" "" "roles/storage.objectViewer of the operator")")
fi
if [[ "$api_exists" == true ]]; then
    consent_bindings+=("$(binding "${custom}/${consent_writer_role}" "serviceAccount:${api_account}" "$(under "$consent_forms_bucket" consent-forms/)" "consent-forms" "${consent_writer_role} of ${api_account}, under consent-forms/")")
fi
echo "==> who holds gs://${consent_forms_bucket}"
keep_policy bucket "$consent_forms_bucket" "${consent_bindings[@]}"
if [[ "$api_exists" == false ]]; then
    echo "    ${api_account} is not there yet: the first apply makes it, and this script, run again after it, grants it ${consent_writer_role}"
fi

provider="projects/${project_number}/locations/global/workloadIdentityPools/${pool}/providers/github"

eval_summary=""
if ((${#eval_repository_ids[@]})); then
    eval_summary="The eval jobs of modules and tutor sign in through this provider, with no service account:

GCP_EVAL_WORKLOAD_IDENTITY_PROVIDER=projects/${project_number}/locations/global/workloadIdentityPools/${eval_pool}/providers/github

"
fi

api_summary=""
if [[ "$api_exists" == false ]]; then
    api_summary="

Run this script again after the first apply, which makes ${api_account}: until then api
may not write the scans of consents to gs://${consent_forms_bucket}."
fi

cat << SUMMARY

Done. A workflow signs in with these two lines; neither is a secret:

GCP_WORKLOAD_IDENTITY_PROVIDER=${provider}
GCP_CONFIG_SERVICE_ACCOUNT=${service_account}

${eval_summary}Left to do once, in the repository's settings rather than here: the environment
${config_environment}, which only main may run in, and its secrets TF_VAR_billing_account,
the same id this script was given, and TF_VAR_operator_email, without which no alert is made.${api_summary}
SUMMARY
