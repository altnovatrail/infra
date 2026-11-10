# Self-hosting NovaTrail

This guide takes you from an empty Google Cloud account to your own copy of the NovaTrail platform, ready to deploy. It uses the same code the platform uses, with your own values. Why things are built the way they are is in [docs/architecture.md](docs/architecture.md) and [docs/decisions.md](docs/decisions.md). Those are in Russian, and this guide links to them only for the reasons behind a step.

> **Status, 2026-11-10.** Everything up to [Your list](#8-your-list) has run on the platform's own project (`novatrail`) and is held by tests on a copy's values. A first deployment cannot be finished yet, on the platform or a copy: the start of [Your list](#8-your-list) says why, and epic E4 of [RUN.md](RUN.md) removes what stands in its way. Sections 8 and 9 are written from the code and will be checked against the platform's first deployment.

## 1. What a copy is

A copy runs the same releases of `api` and `app` as the platform. They are downloaded from `altnovatrail`'s GitHub releases and accepted by `spec`'s `release-verify`, on infrastructure this repository describes. Everything that differs lives in files you own:

- `tofu/production.auto.tfvars` holds your project, region, budget, pool and repository.
- `tofu/backend.hcl` holds the bucket that keeps the configuration's state.
- `tofu/ci.env` holds the two lines `bootstrap.sh` prints.
- The `deploy/` directory holds your list of releases, your `/deployment.json` and your deployment facts.

The full table of what a copy sets and what every copy shares is in [docs/architecture.md](docs/architecture.md), section 3.5. Nothing of the platform's own deployment reaches a copy: no project, region, pool or repository number. `tofu/tests/copy.tftest.hcl` and the copy tests of `tofu/tests/bootstrap.test.mjs` and `tools/deploy/test/` hold that.

**The main path is a fork of this repository with GitHub Actions**, which is how the platform runs. Every merge to `main` applies the configuration and deploys what changed, as the limited identity `infra-config` (R13, R18). [Without GitHub Actions](#10-without-github-actions) covers the other path.

## 2. Before you start

You need:

- **A Google Cloud billing account.** Firebase calls a project with billing the Blaze plan. Before the first deployment the project should cost close to nothing. Its secrets have no versions, no service runs, and the rest stays within free tiers. Your budget alert ([section 3](#3-your-values)) mails you when it doesn't. The prices, as read on 2026-11-09 — check them again on the providers' pages:
  - IAM and Workload Identity Federation: "All use of Identity and Access Management API is free of charge" ([IAM pricing](https://cloud.google.com/iam/pricing)).
  - Secret Manager: 6 active versions a month free, then $0.000082192 an hour per version ([pricing](https://cloud.google.com/secret-manager/pricing)).
  - Cloud Logging: the first 50 GiB a project a month free. Alerting: "$0.35 per month for each metric reference in an alerting policy", not charged until September 1, 2027 ([pricing](https://cloud.google.com/stackdriver/pricing)).
  - Identity Platform: up to 50,000 monthly active users free ([pricing](https://cloud.google.com/identity-platform/pricing)).
  - Firebase Hosting: 10 GB stored and 360 MB a day served free ([pricing](https://firebase.google.com/pricing)).
  - Artifact Registry: 0.5 GiB free ([pricing](https://cloud.google.com/artifact-registry/pricing)).
  - The state bucket is a few kilobytes in Cloud Storage ([pricing](https://cloud.google.com/storage/pricing)).
- **A Google account that may create projects and link them to that billing account.**
- **A fork of this repository on GitHub**, with Actions turned on, cloned with `--recurse-submodules`.
- **The devcontainer.** Open the clone in VS Code and choose "Reopen in Container". It has OpenTofu, `just`, Node and the checks at the versions this repository pins.
- **The Google Cloud CLI.** The container does not include it. Install the pinned version, checked against its sha256, outside the repository:

  ```bash
  tools/ci/install.sh "$HOME/.cache/infra-tools" gcloud
  export PATH="$HOME/.cache/infra-tools/google-cloud-sdk/bin:$PATH"
  gcloud auth login --no-launch-browser
  ```

If your billing account is a free trial, upgrade it to a paid account before the trial ends. Google says: "If you don't upgrade to a Paid billing account before 90 days pass or if you spend the $300 in free credit, then your Free Trial billing account will be closed and all of its associated projects and resources will be stopped" ([Free Trial](https://cloud.google.com/free/docs/free-cloud-features), read 2026-11-09).

## 3. Your values

Your fork carries the platform's own `tofu/production.auto.tfvars`, `tofu/backend.hcl` and `tofu/ci.env`. **Replace all three** with yours in your first commit, and drop the platform's `eval_github_subject_prefixes`. Until then, a push to your `main` runs `Deploy` against the platform's project, and it fails to sign in: the platform's pool admits only the platform's repository.

Write `tofu/production.auto.tfvars`. It is committed: nothing in it is a secret.

```hcl
project_id = "acme-learning-1"
region     = "europe-west3"

budget_amount   = "20"
budget_currency = "EUR"

workload_identity_pool_id  = "acme-ci"
github_oidc_subject_prefix = "repo:acme@555/platform@777"
```

- **`project_id`** — your new project's ID: 6 to 30 lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen. It is permanent, and it names your app's address `https://<project_id>.web.app` and its sign-in domain `<project_id>.firebaseapp.com`.
- **`region`** — where everything regional lives: the services and jobs, the images, the secrets' replicas, the logs and the traces. The platform's region is `us-east4`, chosen for its learners (R04). Yours is yours.
- **`budget_amount`, `budget_currency`** — a monthly spend alert, in whole units of your billing account's own currency. It is an alert, not a cap. `bootstrap.sh` refuses a currency other than the account's.
- **`workload_identity_pool_id`** — the federated pool your GitHub Actions sign in through: 4 to 32 lowercase letters, digits and hyphens, and not `github-eval`.
- **`github_oidc_subject_prefix`** — how GitHub begins the subject of your fork's tokens. Print it with:

  ```bash
  gh api repos/<owner>/<fork>/actions/oidc/customization/sub --jq .sub_claim_prefix
  ```

  It must read `repo:<owner>@<owner's number>/<repository>@<repository's number>`, and the pool admits tokens of these two numbers alone. If it prints another form, your repository does not put the numbers into its tokens' subject. GitHub's documentation on OIDC subject claims says how to turn that on; this guide has not checked the steps.
- **`deploy_environment`, `hosting_environment`** — optional. They name the GitHub environments of api's deployment and of app's publisher, `production` and `production-hosting` by default. The configuration's own environment is always `production-config`.
- **`eval_github_subject_prefixes`** — leave it out. The platform's keys for eval are the platform's own (R20). A copy has none.

The other variables of `tofu/variables.tf` have defaults that fit a small copy.

Write `tofu/backend.hcl`. `bootstrap.sh` makes the bucket under this name, and bucket names are global, so pick one nobody else has:

```hcl
bucket = "acme-learning-1-state"
prefix = "tofu"
```

## 4. Bootstrap

`tofu/bootstrap.sh` makes once, with your own rights, what the configuration cannot make for itself (R13):

- the project and its link to the billing account;
- the state bucket, versioned, in your region;
- the federated pool and its GitHub provider;
- the identity the configuration is applied as, `infra-config`, with exactly its roles;
- three custom roles.

Your billing account's ID goes in the environment, never in a file or your shell's history:

```bash
gcloud billing accounts list
read -rsp "Billing account: " TF_VAR_billing_account && export TF_VAR_billing_account
just bootstrap
```

It is safe to run again: every step looks before it makes, and it brings back what drifted. Run it again whenever `bootstrap.sh` or the values it reads change, before you merge.

At the end it prints two lines. Neither is a secret:

```
GCP_WORKLOAD_IDENTITY_PROVIDER=projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/github
GCP_CONFIG_SERVICE_ACCOUNT=infra-config@<project_id>.iam.gserviceaccount.com
```

Write exactly these two lines into `tofu/ci.env`, and nothing else.

## 5. GitHub

In your fork's Settings → Environments, make three environments. Use the names your values give, or the defaults:

| Environment | Deployment branches and tags | Secrets |
|---|---|---|
| `production-config` | Selected branches and tags → `main` | `TF_VAR_billing_account`, `TF_VAR_operator_email` |
| `production` (`deploy_environment`) | Selected branches and tags → `main` | none |
| `production-hosting` (`hosting_environment`) | Selected branches and tags → `main` | none |

`TF_VAR_operator_email` is the address the alerts on Cloud Run's metrics, and the budget's too, are mailed to. Without it no alert on Cloud Run is made, and the budget mails only the billing account's administrators and users. Set the secrets with `gh secret set <name> --env production-config` so their values stay out of your shell's history. None of the environments asks for reviewers: the review of the pull request is the approval (R05).

The deployment checks these environments itself. After its apply, the job `Configuration` asks GitHub's API that all three exist and run from `main` alone, and stops if not, before the jobs of `api` and `app` run in theirs. GitHub would otherwise create an environment a job names, with no rule of branches (R18). `Configuration` itself runs in `production-config`, so make that one before your first merge.

**Protect your `main`.** A fork does not inherit the platform's ruleset, and the rule "`main` alone" of the environments means only as much as `main` is protected. In Settings → Rules → Rulesets, make one for the default branch:
- no deletion and no force push;
- changes by pull request only;
- required checks, at least `OpenTofu`, `Deploy` and `Documents / docs-check-repo`.

The platform's own ruleset also requires secret scanning, DCO, CodeQL and SonarCloud.

## 6. First apply

Commit `tofu/production.auto.tfvars`, `tofu/backend.hcl` and `tofu/ci.env`. Open a pull request in your fork, and merge it once its checks pass. They include the configuration's own tests (`just tf-check`). They run on synthetic values: `tofu/tests/terraform.tfvars` sets every variable, so nothing you write in `production.auto.tfvars` reaches them.

The merge starts the workflow `Deploy` (`.github/workflows/deploy.yml`), and its job `Configuration` applies the configuration as `infra-config`. On the platform, the first apply made 48 resources with no refusal of rights. Run the workflow again by hand with no part chosen: its apply should say "No changes".

From then on, every merge that changes what the workflow watches applies the configuration again.

## 7. Sign-in with Google

The configuration turns your project to Identity Platform and holds its settings: two authorized domains, no email, phone or anonymous sign-in, no request logging (R16). Turning on Google as a provider is one step in the console. "The IAP OAuth Admin API was shut down on March 19, 2026" ([Programmatically create OAuth clients for IAP](https://docs.cloud.google.com/iap/docs/programmatic-oauth-clients), updated 2026-10-26), and a provider in the module would keep the client's secret in the state.

1. Open the Firebase console of your project → Authentication → Sign-in method → Add new provider → Google → Enable.
2. Set the public name and the support email. Until Google verifies your brand, which needs a domain of your own, users see `<project_id>.firebaseapp.com` on the consent screen rather than the name ([OAuth App Verification](https://support.google.com/cloud/answer/9110914)). If the console asks for a Web client ID and secret, create a client of type "Web application" in Google Cloud → APIs & Services → Credentials. Give it the authorized redirect URI `https://<project_id>.firebaseapp.com/__/auth/handler`, and paste the secret into this form alone. On the platform, the console made the client by itself and asked for nothing.
3. Open Google Auth Platform → Audience: **External** and **In production**. In Testing, sign-in is "limited to up to 100 test users listed in the OAuth consent screen" ([Manage App Audience](https://support.google.com/cloud/answer/15549945)). "If your app utilizes only non-sensitive scopes, it is not mandatory for your app to complete the app verification process" ([OAuth App Verification](https://support.google.com/cloud/answer/9110914)), and the default scopes (email, profile, openid) are not sensitive.
4. Leave the authorized domains alone. The configuration holds them, and its next apply removes any you add by hand.

Run `Deploy` by hand once more. Its apply should still say "No changes".

## 8. Your list

> **A first deployment cannot be finished yet, on the platform or a copy.** Three things stand in its way, and epic E4 of [RUN.md](RUN.md) removes them with the platform's first deployment:
>
> - **`api` has no check of its configuration yet.** A release of `api` runs a job that checks the facts and the rung before the migrations (R05). `api`'s releases do not have that command yet, the default `api_jobs` has no job for it, and `just deploy-api` refuses a release without one.
> - **The service gets no database settings.** `api` reads `API_DATABASE_URL`, `API_OPENFGA_DATABASE_URL` and `API_APP_ORIGIN` (its README), and the configuration does not give them to the service yet.
> - **The order is not settled.** Your `/deployment.json` names `api`'s address, which exists only once the service does. Yet the merge of a first list delivers `app` at once, with the image of `api`. E4 settles the order.
>
> This section and the next say what the list is made of and how the deployment goes once E4 is through. Do not merge a list into your `main` until then.

The deployment ships what `deploy/` names. A pull request that changes it is checked before the merge, and the merge deploys what changed (R05).

- **`deploy/production.json`** — the list. Its schema is `deploy/schema/production.schema.json`, and [docs/architecture.md](docs/architecture.md), section 3.2, has an example. It names:
  - the exact release of `api` and the sha256 of its binary `api_<tag>_linux_amd64` and of its `Dockerfile`;
  - the exact release of `app` and the name and sha256 of its archive;
  - the sha256 of your `deploy/production/deployment.json`;
  - the admission rung, which is always `full`.

  Take the files from the releases on GitHub (`gh release download <tag> -R altnovatrail/api`, and the same for `app`), and take each sha256 with `sha256sum`. `api`'s releases also carry a `SHA256SUMS`.
- **`deploy/production/deployment.json`** — the file your copy of `app` reads at its start. Its format is `spec`'s `deployment/`, version 1 (`spec/deployment/README.md`), and it holds:
  - `"format": 1`;
  - `"api"`, the origin of your `api`: `https://…run.app`, with no path. It exists once the service does;
  - `"signIn"`, the output `app_sign_in` of your configuration. It is in the file `outputs.json` that every run of `Deploy` keeps as an artifact, or `tofu -chdir=tofu output -json app_sign_in` after you sign in as in [Without GitHub Actions](#10-without-github-actions).

  `spec`'s schema at the submodule's tag and the schema in the build of `app` must both accept it.
- **`deploy/production/facts.json`** — the deployment facts your copy declares for `api`'s admission to AI, by provider and fact, each to the age categories it holds for. For example, `{"openai": {"data_processing_agreement": ["adult"]}}`. The providers and facts it may name, and its form, are `spec`'s admission table (`spec/admission/admission-table.json` and `$defs/declared_facts` in `spec/admission/schemas/answer-vector.schema.json`). A copy declares only what is true of its own contracts with AI providers. The platform's facts are not yours.
- **The databases.** `api` keeps its data in two Postgres databases, its own and OpenFGA's. The platform's are on Neon (R03 api). Their direct connection strings for the migrations are the values of the secrets `api-migrate-database-url` and `api-migrate-openfga-database-url`, which you add yourself with `gcloud secrets versions add`, before the first release of `api`.

Run `just deploy-check` before you open the pull request. It downloads the releases from GitHub and checks their signatures with Sigstore, so it needs the network and a fetched `origin/main`. The pull request's check `Deploy` runs it again.

## 9. Deploying

> Not run yet, on the platform or anywhere, and not possible before E4: see the start of section 8. This is the order the code follows today. E4 checks it against the first deployment.

After a merge, the workflow delivers only the parts of the list that changed: `api`'s image or release, the facts, `app`'s build. `api` goes in steps, because its jobs and its service are made with their first image (R11):

1. With no `api_image` in your values, there are no jobs and no service. A run that delivers `api` builds and pushes its image alone, from the release, into your registry, and prints `IMAGE=<region>-docker.pkg.dev/<project_id>/images/api@sha256:…`. To ask for that alone, run `Deploy` by hand with **image** chosen.
2. Put that whole reference, not only the `sha256:…`, into `tofu/production.auto.tfvars` as `api_image`, and merge. The jobs are made.
3. Run `Deploy` by hand with **api** chosen. It runs the check of the configuration and the migrations, and adds a version of the facts.
4. Set `api_serving = true`, and merge. The service is made. Run **api** again to roll it out.
5. Run `Deploy` by hand with **app** chosen. It ships the build with your `/deployment.json` to `https://<project_id>.web.app`.

## 10. Without GitHub Actions

You can run every step by hand with the same recipes, but as **your own account rather than `infra-config`**. You still need the GitHub repository of your fork. `bootstrap.sh` and the configuration build the pool and its provider for its subject, and they cannot be left out. A copy not on GitHub at all would have to change both, and that is not supported. The limits R13 puts on the configuration's identity then do not hold. Whatever your account may do, the apply may do. Prefer the fork with Actions.

```bash
gcloud auth application-default login
read -rsp "Billing account: " TF_VAR_billing_account && export TF_VAR_billing_account
read -rp "Operator's email: " TF_VAR_operator_email && export TF_VAR_operator_email

tofu -chdir=tofu init -backend-config=backend.hcl -lockfile=readonly
tofu -chdir=tofu plan                       # read what it will change
just ci-tf-apply                            # apply it
just ci-tf-outputs /tmp/outputs.json        # the outputs the deployment reads

just deploy-check                           # the list, as a pull request would check it
just deploy-api-image /tmp/outputs.json     # api's image, before api_image is set
just deploy-api /tmp/outputs.json           # api's release: check, migrations, revision
just deploy-api-facts /tmp/outputs.json     # a new version of the facts alone
just deploy-app /tmp/outputs.json           # app's build on Hosting
just deploy-app-check /tmp/outputs.json     # what the site answers
```

The provider bills your project for the calls, through `billing_project` in `tofu/versions.tf`, so your own login works for the apply. Two things are not checked:

- **`app`'s release with your own login.** `just deploy-app` sends your access token to Hosting's API without naming a project to bill. Google's APIs may refuse a person's token like that. Nobody has run it so.
- **Docker.** Building `api`'s image needs Docker with buildx, and the devcontainer has neither. Run those recipes where Docker is.

The workflow's checks of `main` and of the environments do not apply either, so deploy only from your `main`.

## 11. Logs, region and what only the platform has

- **Logs** follow R07, as on the platform. Cloud Run's request logs, which hold the client's IP address, are excluded before storage. Your logs are kept 30 days in your region, and Google's audit logs 400 days.
- **Traces.** Cloud Run traces some requests by itself. Cloud Trace's API stays on, because Cloud Scheduler depends on it, so traces may come. They are kept in your region.
- **Region.** Everything regional is in yours. What the platform decided about its learners' region (R04) is the platform's.
- **Only the platform's:**
  - the project `novatrail` and its address;
  - the keys for eval and their pool, `github-eval`;
  - the platform's deployment facts.

  None of them reaches a copy.
