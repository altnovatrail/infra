# infra — measurements

> The results of the repository's measurements: what was measured, how, on what, and the numbers. The documents that describe how things are built cite them as a section, `measurements 1`; the facts no run of ours checks that they rest on are records of [sources.md](sources.md), and a program's documentation or code at a version or commit is a link beside the claim. A measurement taken again is a new row or item with its date, and an earlier one is not edited.

## 1. Tokens of the epics' sessions

At the archive of an epic, `just -f spec/justfile tokens-report --since … --until … --row` measures the sessions of Claude Code in the epic's window, on the author's machine, by their transcripts in the folder `-workspaces-infra` (measurements 1.9 spec). A window runs from the commit that archived the epic before to the start of the session that archives this one. A session that crosses a boundary is counted by its calls inside the window.

| Epic | Window, UTC | Sessions | Calls, main / subagents | Context of a call, k, main / subagents | Compactions | Cost at API prices |
|---|---|---|---|---|---|---|
| before one task a session — the row `-workspaces-infra` of measurements 1.9 spec, E1–E4 | 2026-10-13T00:00 … 2026-11-12T14:27 | 6 | 2,175 / 1,714 | 354.7 / 80.0 | 6 | $321.70 |
| E5, with three tasks outside it | 2026-11-12T20:27 … 2026-11-15T02:21 | 17 | 1,613 / 709 | 177.8 / 90.6 | 1 | $150.22 |

- Measured 2026-11-15, when E5 was archived. The window of E5 starts after f79f0f2, the commit that closed E4, so the session of E4's last task and of E5's planning counts by its calls after it.
- With one task a session, from the first of those three tasks, the context of a main call fell from 354.7 to 177.8 thousand, −50%. The windows differ in work: the detail, the first code and the first deployment against the bucket and the breach procedure. This repository's reference for the threshold of a new analysis is its row marked the reference in measurements 1.9 spec.

## 2. The speed of CI

### 2.1. The jobs `OpenTofu` and `Deploy` before and after the tests four at a time, 2026-11-16

The times of the jobs and of their steps from `actions/runs/<id>/jobs` of the GitHub API, and of the recipes from the `duration_ms` that `node --test` prints in the jobs' logs, read 2026-11-16. Before — the run of CI on `main` 43805765623, the merge of the move to `.github` v0.1.24, with the image from the cache; after — the runs 43810340096 and 43813641572 of pull request 85, on runners `ubuntu-24.04`. One run each: the runners' times vary — `tf-check` took 36 s on `main` and 57 s in the second run of the pull request, with no change to `tofu/`'s module.

| | `main`, 43805765623 | pull request 85, 43810340096 | pull request 85, 43813641572 |
|---|---|---|---|
| `OpenTofu`, the job | 187 s | 111 s, three tests failed (below) | 158 s |
| `bootstrap-test` | 117.3 s, 63 tests one after another | 43.1 s, 63 tests four at a time | 65.8 s, 64 tests four at a time |
| `Deploy`, the job | 68 s | 50 s | 59 s |
| `Deploy`, the step of the recipes | 32 s | 25 s | 27 s |
| `deploy-check-release-test` | 7.7 s, in turn | in the background | 9.0 s, in the background |

- **The race.** In 43810340096 three tests of `bootstrap.sh` failed, each a run again that did not find a bucket it had made; four runs of the suite in the devcontainer, on four of its cores by `taskset -c 0-3`, failed one to two tests each. The cause was `grep -q` under `pipefail` in `bootstrap.sh`; with it fixed, three runs on four cores — 64 of 64 each.
- **Locally.** The devcontainer, 20 cores: `just bootstrap-test` took 130 s with the tests one after another, 95 s of user time, and 45 s four at a time, 121 s of user time; on four of its cores, 130–141 s four at a time. Its times change with what else the machine runs.

### 2.2. The image of the stage `toolchain` before and after one build a run, 2026-11-16

The times of the runs, the jobs and their steps from `actions/runs/<id>` and `actions/runs/<id>/jobs` of the GitHub API, the steps of the composite action `.github/actions/toolchain` as one step; the rest from the jobs' logs, read 2026-11-16. Before — on `.github` v0.1.24, each job restoring the entry itself: the run of CI on `main` 43818580587, and of pull request 86, 43817589511. After — on v0.1.30 with the job `Toolchain image`, which alone builds the image on a miss: pull request 87, 43855940093, with the entry of `main`, and the trial pull request 88, not for merge, 43855945017, whose action looked for a key no entry held, so that `Toolchain image`, `OpenTofu` and `Deploy` missed while the shared Documents check hit. One run each, on runners `ubuntu-24.04`, while the orchestrator ran other repositories' CI.

| | `main`, 43818580587 | PR 86, 43817589511 | PR 87, 43855940093, a hit | PR 88, 43855945017, a miss |
|---|---|---|---|---|
| the run, from its creation to its end | 129 s | 145 s | 187 s | 356 s |
| `Toolchain image`, the job | — | — | 5 s, the lookup under 1 s | 60 s |
| `OpenTofu` starts, after the run's creation | 18 s | 2 s | 18 s | 186 s |
| `OpenTofu`, the job / the image / the recipes | 110 / 17 / 84 s | 143 / 37 / 100 s | 169 / 32 / 128 s | 169 / 49 / 114 s |
| `Deploy` starts, after the run's creation | 7 s | 3 s | 12 s | 138 s |
| `Deploy`, the job / the image / the recipes | 53 / 17 / 26 s | 72 / 37 / 29 s | 81 / 43 / 32 s | 77 / 35 / 36 s |

- **The miss.** In `Toolchain image` the build took 16 s, `docker save` about 8 s and the upload 19 s; the artifact `toolchain-image` is 535,180,543 bytes at level 1, kept to 2026-11-17. `OpenTofu` and `Deploy` each logged "Cache not found", downloaded it by its ID in 11–12 s with its SHA256 digest checked, and loaded it: neither ran the Dockerfile. Neither pull request saved an entry: `actions/caches?key=toolchain` holds none of the trial's key and none of `refs/pull/87/merge` or `refs/pull/88/merge` — only the entry of `refs/heads/main` and those of pull requests 82 and 83 from before the change, which go after seven days unread.
- **The waits.** In the trial `OpenTofu` waited 123 s and `Deploy` 75 s for a runner after `Toolchain image` ended, when the jobs of other repositories' runs held the organization's runners; on a hit the two started 12–18 s after the run, against 2–3 s in pull request 86 before the change and 7–18 s on `main`: the wait for `Toolchain image` and a second runner, which a hit pays on every run. The run of pull request 87 took 42 s longer than that of 86, and its recipes in `OpenTofu` 28 s longer, with the same module and tests: the runners' times vary, as in measurements 2.1, and one run each does not tell the change's part from that.

### 2.3. The stages `toolchain-core` and `toolchain`, 2026-11-16

The sizes of the three tools infra's container adds to spec's, as the stage `toolchain` installs them, by `ls -l` of `/usr/local/bin` in the devcontainer, 2026-11-16: `tofu` 114,192,544 bytes, `shellcheck` 16,213,136 and `actionlint` 6,074,530, 136,480,210 together. The image of `toolchain` holds them beyond the core, and `toolchain-core`, which the Documents check and `Deploy` load, does not.

The run of CI of pull request 90, 43907985039, a miss of both entries, since the Dockerfile is new; the times from `actions/runs/<id>/jobs` of the GitHub API and the jobs' logs, read 2026-11-16:
- **the run** — 296 s from its creation to its end, all green;
- **`Toolchain image`** — 106 s: the core built, saved and uploaded as `toolchain-core-image`, 489,200,988 bytes at level 1, by 16:30:26, 61 s after the job's first lookup; then `toolchain` as `toolchain-image`, 535,206,283 bytes, by 16:31:04, 37 s more;
- **Documents** — "The checks without a browser run in the stage toolchain-core.", "Cache not found" for `toolchain-core-Linux-X64-<sha256>`, its own build, 48 s;
- **`Deploy`** — 104 s, the core by the artifact's ID after "Cache not found"; **`OpenTofu`** — 148 s, `toolchain` the same way. Neither ran the Dockerfile.

## 3. Checks on the project

### 3.1. `DELETE` of an absent object without `storage.objects.get`, 2026-11-14

What `sweep` of `api` meets when it erases a scan erased already: by the JSON API of Cloud Storage, as `api-run`, which holds `storage.objects.create` and `storage.objects.delete` under `consent-forms/` of the bucket of the scans and no `storage.objects.get`, on the project `novatrail`. `DELETE` of an object it had just erased, and of one never made, answered `404`, "No such object: novatrail-consent-forms/consent-forms/…", not `403`. So `sweep` takes a scan erased already for erased, as the store's `Delete` of `api` expects: it takes `204` or `404` ([`internal/forms/forms.go`](https://github.com/altnovatrail/api/blob/v0.1.27/internal/forms/forms.go) at v0.1.27).

### 3.2. The alert on a job by the clock reads the sum of its window, 2026-11-15

By the Monitoring API's `timeSeries` and `alertPolicies` on `novatrail`: the policy `api jobs by the clock not run`, made 2026-11-13T19:10:57Z, enabled; the raw points of `completed_execution_count` of `api-sweep`, `result=succeeded`, are `1` at 2026-11-13T09:01:00Z and 2026-11-14T09:01:00Z and `0` at 09:02–09:05 of 2026-11-14, none between; the same summed over `90000s`, `ALIGN_SUM` and `REDUCE_SUM`, `1` at 2026-11-13T23:36:11Z and 2026-11-15T00:36:11Z. No incident of the policy, open or closed, and no mail, from its making to 2026-11-15 00:36 UTC: the condition reads the window's sum, not the raw points.

### 3.3. A POST policy signed through IAM serves until its expiration, 2026-11-13 and 2026-11-14

A page of the organizer's tool signed 2026-11-13 at 21:38:01 UTC as `upload-measure`, for 12 hours, took two sample files by the forms of one policy, at 21:42:13 and 21:42:14, and a scan by the form of another at 21:46:28; a sample sent by it on 2026-11-14 at 23:43:47 UTC was refused, `400`, `InvalidPolicyDocument` — "The content of the form does not meet the conditions specified in the policy document. Form expired", "Expiration: 2026-11-14T09:38:01Z, Now: 2026-11-14T23:43:47.957791Z". So a policy signed through IAM serves several uploads until its expiration and none after it.

### 3.4. What the service accounts may do in the buckets, 2026-11-14

By requests of the JSON API as each service account: `upload-measure` created `measure/samples/<folder>/probe.json` (`200`), and was refused its read, its metadata and the bucket's list (`403`, "does not have storage.objects.get access", "storage.objects.list"), an insert of the same name again — "does not have storage.objects.delete access" —, its delete, and an insert under `measure/records/`, `eval-set/samples/` and the scans' `consent-forms/` ("storage.objects.create"); `upload-eval-set` created under `eval-set/samples/` and was refused its read and an insert under `measure/samples/`; `api-run` created under `consent-forms/` and inserted the same name again (`200` both, as it holds `storage.objects.delete`), and was refused its read, its metadata, the list of either bucket and an insert outside the prefix. So a condition on `resource.name` holds an insert and a delete to the prefix, and an overwrite takes `storage.objects.delete` (sources 10.2).

### 3.5. A Custom-Time in the future, and a rewrite with an earlier one, 2026-11-15

The organizer's tool set the Custom-Time `2028-11-14T00:00:00Z` on a form under `measure/forms/` made at 00:26:51 UTC, and it was taken; a rewrite of that form by `gcloud storage mv` with `--custom-time` of `2026-11-15`, earlier, made the object anew, `timeCreated` 00:27:04, with the earlier Custom-Time.

### 3.6. The organizer's tool against Cloud Storage, 2026-11-14 and 2026-11-15

The page of measurements 3.3, with `"expiration": "2026-11-14T09:38:01Z"` and the credential `upload-measure@novatrail.iam.gserviceaccount.com/20261113/auto/storage/goog4_request`, took its files, and Cloud Storage named the same expiration when it refused one after it: it takes the expiration in the extended format and the credential's location `auto`. `gcloud storage objects list` and `describe` with `--raw --format=json` gave `name`, `contentType`, `size`, `timeCreated` — `"2026-11-13T21:42:14.262000+00:00"` —, `customTime` — `"2028-11-14T00:00:00+00:00"` — and `metadata` — `{"withdrawn": "2026-11-15"}` —, as the tool reads them; `withdraw` moved the form back from `<name>.rewrite`, which is gone after it, with the earlier Custom-Time (measurements 3.5), and `time` then refused the form as withdrawn.

### 3.7. The first runs of `bootstrap.sh`: the owners' binding, the members' spelling and `gcloud`'s outputs, 2026-11-13

Once the binding of `projectOwner:novatrail` to `legacyBucketOwner` was taken back, the next call on the bucket as the project's owner was refused, "does not have storage.buckets.getIamPolicy access to the Google Cloud Storage bucket", and a run again was refused its `storage.buckets.update`. The refusal names the account it runs as, spelled with capitals as Google keeps it, and IAM keeps the member of a person granted by an address in lower case in that spelling, `user:` and each word of the name with a capital: a run again read it so on both upload service accounts and in both buckets. `gcloud storage buckets describe --format='value(location)'` prints `US-EAST4`, `gcloud storage buckets list --project=novatrail --format='value(name)'` prints the names alone, one a line, and `gcloud storage buckets get-iam-policy` reads the policy in version 3, a binding under a condition as its role, with the condition's expression and title.

### 3.8. Owner and a service account's token, 2026-11-14

The project's owner was refused a token as `api-run` — "Permission 'iam.serviceAccounts.getAccessToken' denied" —, so Owner does not impersonate a service account without `roles/iam.serviceAccountTokenCreator` on it. A binding of that role granted to `user:<the address in lower case>` was kept in the capitals' spelling, and `gcloud iam service-accounts remove-iam-policy-binding` with the address in lower case refused: "Policy binding with the specified principal, role, and condition not found!"; with the member as `get-iam-policy` printed it, the binding was taken back.

## 4. The tools and the providers

### 4.1. The schemas of the providers 8.10.0, 2026-11-24

`tofu providers schema -json` of OpenTofu 1.13.9 in the devcontainer, on `versions.tf` and `.terraform.lock.hcl` of `tofu/` without the backend, the providers `hashicorp/google` and `hashicorp/google-beta` 8.10.0 from `registry.opentofu.org`:
- `env` of `containers` of `google_cloud_run_v2_service` and of `google_cloud_run_v2_job` is a block of `nesting_mode` `set`; `tofu validate` of a service with `ignore_changes = [template[0].containers[0].env[0]]` refuses: "Cannot index a set value", "Block type "env" is represented by a set of objects, and set elements do not have addressable keys";
- `google_firebase_project`, `google_firebase_hosting_site` and `google_firebase_web_app` are in `google-beta` alone, and the site has `deletion_policy`; `google_identity_platform_config` has `authorized_domains`, "List of domains authorized for OAuth redirects.";
- `google_artifact_registry_repository` has `registry_uri`, "The repository endpoint"; `billing_account` of the data source `google_project` — "must have Billing Account Administrator privileges (roles/billing.admin)";
- `budget_filter` of `google_billing_budget`: `credit_types_treatment` — "Default value: "INCLUDE_ALL_CREDITS" Possible values: ["INCLUDE_ALL_CREDITS", "EXCLUDE_ALL_CREDITS", "INCLUDE_SPECIFIED_CREDITS"]"; `credit_types` — "If creditTypesTreatment is INCLUDE_SPECIFIED_CREDITS, this is a list of credit types to be subtracted from gross cost to determine the spend for threshold calculations".

### 4.2. The archives of OpenTofu, ShellCheck and the Google Cloud CLI, 2026-11-08 and 2026-11-09

- **OpenTofu 1.13.9.** `tofu_1.13.9_SHA256SUMS` of [the release](https://github.com/opentofu/opentofu/releases/tag/v1.13.9), 2026-11-08: `b34b327cc1ef07178207b6f2cd1f5276537d3e5b7be316500f6dac50d4c0a857  tofu_1.13.9_linux_amd64.tar.gz`, `5dc196dde75b667e4806d358310ec96742774cd0993c54c1237efee5644b69b8  tofu_1.13.9_linux_arm64.tar.gz`, the same sums as the field `digest` of these assets in the GitHub API. `gpg` checked `tofu_1.13.9_SHA256SUMS.gpgsig` with the key [opentofu.asc](https://get.opentofu.org/opentofu.asc): "Good signature from "OpenTofu (This key is used to sign opentofu providers) <core@opentofu.org>"", the fingerprint `E3E6 E43D 84CB 852E ADB0 051D 0C0A F313 E5FD 9F80`; again 2026-11-09, with the same fingerprint. 2026-11-09 both archives were downloaded and matched these sums, `tofu_1.13.9_linux_amd64.tar.gz` 35,124,830 bytes; the archive holds `tofu`, `LICENSE`, `README.md` and `CHANGELOG.md`, and `tofu version -json` gives `"terraform_version": "1.13.9"`.
- **ShellCheck 0.11.0**, 2026-11-09. [The release](https://github.com/koalaman/shellcheck/releases/tag/v0.11.0) publishes no list of sums; the field `digest` of its assets in the GitHub API is `sha256:b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6` for `shellcheck-v0.11.0.linux.x86_64.tar.gz` and `sha256:68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc` for `shellcheck-v0.11.0.linux.aarch64.tar.gz`, and `sha256sum` of both downloaded archives is the same; the archive holds `shellcheck`, `LICENSE.txt` and `README.txt`.
- **The Google Cloud CLI 592.0.0**, 2026-11-09. Two downloads of `google-cloud-cli-592.0.0-linux-x86_64.tar.gz` gave the same sha256, `2d841a23…d50b`, the one `GCLOUD_SHA256_AMD64` of `tools/ci/versions.env` took.

### 4.3. The lock file of the providers, 2026-11-09

`tofu providers lock` of OpenTofu 1.13.9 wrote `hashicorp/google` and `hashicorp/google-beta` 8.10.0 into `tofu/.terraform.lock.hcl` with the source `registry.opentofu.org`, 15 hashes `h1:` and `zh:` per provider; with a single `-platform=linux_amd64` the file was the same, byte for byte.

## 5. GitHub

### 5.1. The subjects of GitHub's OIDC tokens, 2026-11-24

`gh api repos/altnovatrail/<repository>/actions/oidc/customization/sub` and `gh api repos/altnovatrail/<repository>`:

| Repository | `sub_claim_prefix` | `use_immutable_subject` | ID | Owner's ID | Private |
|---|---|---|---|---|---|
| `infra` | `repo:altnovatrail@344507087/infra@1425816333` | `true` | 1425816333 | 344507087 | no |
| `modules` | `repo:altnovatrail@344507087/modules@1425775415` | `true` | 1425775415 | 344507087 | no |
| `tutor` | `repo:altnovatrail@344507087/tutor@1425813274` | `true` | 1425813274 | 344507087 | no |

Each answered `"use_default":true` too.
