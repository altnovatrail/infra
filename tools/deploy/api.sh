#!/usr/bin/env bash
# The deployment of api by the list, as R05 lays out its steps (R15).
#
#   tools/deploy/api.sh image   <outputs.json> [<deploy dir>]
#   tools/deploy/api.sh release <outputs.json> [<deploy dir>]
#   tools/deploy/api.sh facts   <outputs.json> [<deploy dir>]
#
# image builds api's image of the list's release and pushes it, tagged with the release, and prints
# its digest: the files of the release are downloaded and verified again, release-verify and sha256,
# by tools/deploy-check/fetch.mjs, and the image is built as api's release says, around the binary
# alone. The first deployment runs it before api_image names the image (T24).
#
# release runs the whole of a new release of api: a release lower than the one that takes the
# traffic is refused; then the image; a new version of the facts' secret; the image set on every job
# of the list, and on a job of the part check that version of the facts too, the one the revision
# will mount; the jobs of the part check, then those of migrate, each to its end, any failure
# stopping the deployment before any revision; a revision by the image's digest with that version of
# the facts, taking no traffic until it is ready, and then all of it; and last the jobs of the part
# after. Before the configuration makes the service there is none to roll, and it says so.
#
# facts takes a new version of the facts alone: the jobs of the part check on the image that takes
# the traffic, with that version, and then a new revision on that image, by its digest, with it. No
# build, no migration and no release-verify, since the release's files have not changed; facts that
# api's check refuses stop before any revision (R05).
#
# What it works on comes from the configuration's outputs, as `tofu output -json` prints them after
# the apply of the same commit: the project, the region, the registry, the service, the jobs with
# their parts, the facts' secret and where the revision reads it. It runs gcloud and docker, signed
# in as api's deployment.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"

fail() {
    echo "deploy-api: $*" >&2
    exit 1
}

[[ $# -ge 2 && $# -le 3 ]] || fail "usage: api.sh image|release|facts <outputs.json> [<deploy dir>]"
command="$1"
outputs="$2"
deploy="${3:-$root/deploy}"
case "$command" in image | release | facts) ;; *) fail "the command is image, release or facts, not ${command}" ;; esac
[[ -f "$outputs" ]] || fail "the configuration's outputs are not there: ${outputs}"
list="$deploy/production.json"
facts_file="$deploy/production/facts.json"
[[ -f "$list" ]] || fail "the list is not there: ${list}"

# One value of the outputs, which must be there: a value missing would aim a step at nothing.
output() {
    local value
    value="$(jq -er --arg name "$1" '.[$name].value | if . == null then error("no value") elif type == "string" then . else tojson end' "$outputs" 2> /dev/null)" ||
        fail "the configuration's outputs name no $1"
    printf '%s\n' "$value"
}

# One value of the list, which its schema makes sure of once deploy-check has passed it.
listed() {
    jq -er "$1" "$list" || fail "the list holds no $1"
}

project="$(output project_id)"
region="$(output region)"
repository="$(output image_repository)"
service="$(output api_service_name)"
secret="$(output admission_facts_secret)"
facts_path="$(output admission_facts_file)"
jobs="$(output api_jobs)"
release="$(listed .api.release)"
image_name="${repository}/api"

where=(--project="$project" --region="$region")

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The major, minor and patch of a tag, as numbers, or a refusal.
numbers() {
    [[ "$1" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail "$1 is not an exact tag of a release"
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
}

# Whether the tag $1 is lower than $2, by numbers: v0.10.0 is higher than v0.9.0.
lower() {
    local a b i
    read -ra a <<< "$(numbers "$1")"
    read -ra b <<< "$(numbers "$2")"
    for i in 0 1 2; do
        ((a[i] < b[i])) && return 0
        ((a[i] > b[i])) && return 1
    done
    return 1
}

# The service, as JSON, or nothing when the configuration has not made it yet. Any other failure to
# read it stops the deployment: read as no service, it would skip the revision without a word.
# gcloud says a service is not there by the code NOT_FOUND or in words, "Cannot find service".
describe_service() {
    local errors status=0 described
    errors="$work/describe-errors"
    described="$(gcloud run services describe "$service" "${where[@]}" --format=json 2> "$errors")" || status=$?
    if ((status == 0)); then
        printf '%s\n' "$described"
    elif ! grep -qE 'NOT_FOUND|Cannot find service' "$errors"; then
        cat "$errors" >&2
        fail "the service ${service} cannot be read"
    fi
}

# The digest of the image the revision that takes the traffic runs. Traffic split between revisions
# is a rollout that did not end, and is refused: which release serves would be a guess.
serving_digest() {
    local described="$1" revisions revision digest
    revisions="$(jq -r '[.status.traffic[]? | select((.percent // 0) > 0) | (.revisionName // "LATEST")] | unique | .[]' <<< "$described")"
    [[ -n "$revisions" ]] || fail "no revision of ${service} takes traffic"
    [[ "$(wc -l <<< "$revisions")" -eq 1 ]] || fail "the traffic of ${service} is split between revisions $(tr '\n' ' ' <<< "$revisions"): end or undo that rollout by hand first"
    revision="$revisions"
    if [[ "$revision" == LATEST ]]; then
        revision="$(jq -er '.status.latestReadyRevisionName' <<< "$described")" || fail "the revision of ${service} that takes traffic has no name"
    fi
    digest="$(gcloud run revisions describe "$revision" "${where[@]}" --format=json | jq -er '.status.imageDigest')" ||
        fail "the revision ${revision} names no digest of its image"
    [[ "$digest" == "${image_name}@sha256:"* ]] || fail "the revision ${revision} runs ${digest}, which is not of ${image_name}"
    printf '%s\n' "$digest"
}

# The registry's tags of api's image, as lines of tag and digest.
registry_tags() {
    gcloud artifacts docker tags list "$image_name" --format=json |
        jq -r '.[] | [(.tag | split("/") | last), (.version | split("/") | last)] | @tsv'
}

# The release the image of that digest is tagged with in the registry: one exact tag, as the
# deployment gives each image, or a refusal (R15).
release_of() {
    local digest="$1" all tags
    all="$(registry_tags)" || fail "the registry's tags of ${image_name} cannot be read"
    tags="$(awk -F '\t' -v digest="${digest##*@}" '$2 == digest { print $1 }' <<< "$all")"
    [[ -n "$tags" ]] || fail "the image ${digest} that takes the traffic has no tag in the registry, so its release cannot be told"
    [[ "$(wc -l <<< "$tags")" -eq 1 ]] || fail "the image ${digest} that takes the traffic has more than one tag: $(tr '\n' ' ' <<< "$tags")"
    numbers "$tags" > /dev/null
    printf '%s\n' "$tags"
}

# The image of the list's release, by digest. One the registry holds under the release's tag already,
# from an earlier deployment of it, is the one taken: built again it would get another digest, and
# the tag would leave the image that may be taking the traffic. Otherwise the release's files are
# downloaded and verified again, and the image is built around the binary alone, for linux/amd64,
# the binary's platform and Cloud Run's, and pushed; its digest is the one the push reports.
build_image() {
    local all existing name binary_sha256 dockerfile_sha256 binary dockerfile pushed digest
    all="$(registry_tags)" || fail "the registry's tags of ${image_name} cannot be read"
    existing="$(awk -F '\t' -v tag="$release" '$1 == tag { print $2 }' <<< "$all")"
    if [[ -n "$existing" ]]; then
        image="${image_name}@${existing}"
        echo "==> the image of api ${release} is in the registry already: ${image}"
        return
    fi
    name="$(listed .api.binary.name)"
    binary_sha256="$(listed .api.binary.sha256)"
    dockerfile_sha256="$(listed .api.dockerfile.sha256)"
    echo "==> the files of api ${release}, verified again"
    binary="$(node "$root/tools/deploy-check/fetch.mjs" api "$release" "$name" "$binary_sha256" "$work/files")"
    dockerfile="$(node "$root/tools/deploy-check/fetch.mjs" api "$release" Dockerfile "$dockerfile_sha256" "$work/files")"

    # The release's Dockerfile reads the binary as api from the build context binary, and nothing of
    # the main context, which is left empty (R28 api).
    echo "==> the image ${image_name}:${release}"
    mkdir -p "$work/binary" "$work/context"
    cp "$binary" "$work/binary/api"
    chmod 0755 "$work/binary/api"
    gcloud auth configure-docker "${repository%%/*}" --quiet > /dev/null
    docker build --platform=linux/amd64 --target release --build-context "binary=$work/binary" \
        -f "$dockerfile" -t "${image_name}:${release}" "$work/context"
    pushed="$(docker push "${image_name}:${release}")"
    digest="$(grep -oE 'digest: sha256:[0-9a-f]{64}' <<< "$pushed" | tail -1)" || fail "the push of ${image_name}:${release} reported no digest"
    image="${image_name}@${digest#digest: }"
    echo "    ${image}"
}

# A new version of the facts' secret, from the list's facts.json: its number.
add_facts() {
    local name
    [[ -f "$facts_file" ]] || fail "the facts are not there: ${facts_file}"
    name="$(gcloud secrets versions add "$secret" --project="$project" --data-file="$facts_file" --format='value(name)')"
    [[ "$name" =~ /versions/([0-9]+)$ ]] || fail "the new version of ${secret} is named ${name:-nothing}"
    echo "==> the facts: version ${BASH_REMATCH[1]} of ${secret}" >&2
    printf '%s\n' "${BASH_REMATCH[1]}"
}

# The image on each job; with a version of the facts first, as set_image <version> <job>..., that
# version too, in the same update: a job of the check gets the exact version the revision will
# mount, which run as it is would be the latest, whichever that is by then (R15).
set_image() {
    local version="" job flags
    if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
        version="$1"
        shift
    fi
    for job in "$@"; do
        flags=(--image="$image")
        [[ -z "$version" ]] || flags+=(--update-secrets="${facts_path}=${secret}:${version}")
        gcloud run jobs update "$job" "${where[@]}" "${flags[@]}" --quiet > /dev/null
        echo "==> the image of the job ${job}${version:+, and version ${version} of the facts}"
    done
}

run_jobs() {
    local part="$1" job
    shift
    for job in "$@"; do
        echo "==> the job ${job} (${part})"
        gcloud run jobs execute "$job" "${where[@]}" --wait --quiet > /dev/null || fail "the job ${job} did not end well, and the deployment stops here"
    done
}

# A revision by the image's digest with that version of the facts, taking no traffic; when it is
# the service's ready one, all the traffic to that revision, by its name.
roll() {
    local version="$1" described created ready
    echo "==> a revision of ${service}, with no traffic yet"
    gcloud run services update "$service" "${where[@]}" --image="$image" \
        --update-secrets="${facts_path}=${secret}:${version}" --no-traffic --quiet > /dev/null
    described="$(describe_service)"
    created="$(jq -r '.status.latestCreatedRevisionName // empty' <<< "$described")"
    ready="$(jq -r '.status.latestReadyRevisionName // empty' <<< "$described")"
    [[ -n "$created" && "$created" == "$ready" ]] || fail "the revision ${created:-made} is not ready, and takes no traffic"
    echo "==> all the traffic to ${created}"
    gcloud run services update-traffic "$service" "${where[@]}" --to-revisions="${created}=100" --quiet > /dev/null
}

numbers "$release" > /dev/null

# The jobs by their part, read once: a list read wrong would run no job and go on.
jq -e 'type == "object" and all(.[]; (.job | type) == "string" and (.deploy == null or (.deploy | IN("check", "migrate", "after"))))' <<< "$jobs" > /dev/null ||
    fail "the configuration's api_jobs are not jobs with their parts"
jobs_of() {
    jq -r --arg part "$1" 'to_entries | sort_by(.key) | .[] | select((.value.deploy // "clock") == $part) | .value.job' <<< "$jobs"
}
mapfile -t check_jobs < <(jobs_of check)
mapfile -t migrate_jobs < <(jobs_of migrate)
mapfile -t after_jobs < <(jobs_of after)
mapfile -t clock_jobs < <(jobs_of clock)

case "$command" in
    image)
        build_image
        echo "IMAGE=${image}"
        ;;

    release)
        ((${#migrate_jobs[@]} > 0)) || fail "the configuration's api_jobs name no job of the part migrate, and a release does not go without its migrations"
        ((${#check_jobs[@]} > 0)) || fail "the configuration's api_jobs name no job of the part check, and a release does not go without api's check of its facts and rung before the migrations (R05; the second 2026-11-08 amendment to R106 spec)"
        described="$(describe_service)"
        if [[ -n "$described" ]]; then
            serving_image="$(serving_digest "$described")"
            serving="$(release_of "$serving_image")"
            if lower "$release" "$serving"; then
                fail "api ${release} is lower than ${serving}, which takes the traffic: api goes forward only (R05)"
            fi
            echo "==> api ${release} after ${serving}, which takes the traffic"
        else
            echo "==> no service ${service} yet: the jobs alone, and the revision once the configuration makes it"
        fi
        build_image
        version="$(add_facts)"
        # Before the migrations only the jobs that run before them get the new image: a job of the
        # clock or of after would run the new release against a database not migrated yet, were the
        # migrations to fail.
        set_image "$version" "${check_jobs[@]}"
        set_image "${migrate_jobs[@]}"
        run_jobs check "${check_jobs[@]}"
        run_jobs migrate "${migrate_jobs[@]}"
        if [[ -n "$described" ]]; then
            roll "$version"
        fi
        set_image "${after_jobs[@]}" "${clock_jobs[@]}"
        if [[ -n "$described" ]]; then
            run_jobs after "${after_jobs[@]}"
        fi
        echo "deploy-api: api ${release}, ${image}"
        ;;

    facts)
        ((${#check_jobs[@]} > 0)) || fail "the configuration's api_jobs name no job of the part check, and new facts do not go without api's check of them (R05)"
        described="$(describe_service)"
        [[ -n "$described" ]] || fail "there is no service ${service} to give the facts to"
        image="$(serving_digest "$described")"
        version="$(add_facts)"
        set_image "$version" "${check_jobs[@]}"
        run_jobs check "${check_jobs[@]}"
        roll "$version"
        echo "deploy-api: the facts of version ${version}, on ${image}"
        ;;
esac
