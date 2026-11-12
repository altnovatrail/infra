# Self-hosting NovaTrail

This guide takes you from an empty Google Cloud account to your own copy of the NovaTrail platform, ready to deploy. It uses the same code the platform uses, with your own values. Why things are built the way they are is in [docs/architecture.md](docs/architecture.md) and [docs/decisions.md](docs/decisions.md). Those are in Russian, and this guide links to them only for the reasons behind a step. To run the whole platform from source on one machine, with no copy at all, go to [section 12](#12-running-the-whole-platform-on-one-machine).

> **Status, 2026-11-10.** Everything up to [Your list](#8-your-list) has run on the platform's own project (`novatrail`) and is held by tests on a copy's values, except the steps it marks as not checked. A first deployment cannot be finished yet, on the platform or a copy: the start of [Your list](#8-your-list) says why, and epic E4 of [RUN.md](RUN.md) removes what stands in its way. Sections 8 and 9 are written from the code and will be checked against the platform's first deployment. Section 12, a local run, has not run either: `app` has no code yet.

## 1. What a copy is

A copy runs the same releases of `api` and `app` as the platform. They are downloaded from `altnovatrail`'s GitHub releases and accepted by `spec`'s `release-verify`, on infrastructure this repository describes. Everything that differs lives in files you own:

- `tofu/production.auto.tfvars` holds your project, region, budget, pool and repository.
- `tofu/backend.hcl` holds the bucket that keeps the configuration's state.
- `tofu/ci.env` holds the two lines `bootstrap.sh` prints.
- The `deploy/` directory holds your list of releases, your `/deployment.json` and your deployment facts.

The full table of what a copy sets and what every copy shares is in [docs/architecture.md](docs/architecture.md), section 3.5. Nothing of the platform's own deployment reaches a copy: no project, region, pool or repository number. `tofu/tests/copy.tftest.hcl` and the copy tests of `tofu/tests/bootstrap.test.mjs` and `tools/deploy/test/` hold that. The name NovaTrail does reach a copy, on purpose: it is the display name of the project `bootstrap.sh` makes, and Hosting's versions carry the label `deployment-tool: novatrail-infra`.

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

The platform's first deployment went this way on 2026-11-12, with `api` v0.1.22 and `app` v0.1.0 (R25 in [docs/decisions.md](docs/decisions.md)). This section says what the list is made of, and the next how the deployment goes.

The deployment ships what `deploy/` names. A pull request that changes it is checked before the merge, and the merge deploys what changed (R05).

- **`deploy/production.json`** — the list. Its schema is `deploy/schema/production.schema.json`, and [docs/architecture.md](docs/architecture.md), section 3.2, has an example. It names:
  - the exact release of `api` and the sha256 of its binary `api_<tag>_linux_amd64` and of its `Dockerfile`;
  - the exact release of `app` and the name and sha256 of its archive;
  - the sha256 of your `deploy/production/deployment.json`;
  - the admission rung, which is always `full`.

  Take the files from the releases on GitHub (`gh release download <tag> -R altnovatrail/api`, and the same for `app`), and take each sha256 with `sha256sum`. `api`'s releases also carry a `SHA256SUMS`.
- **`deploy/production/deployment.json`** — the file your copy of `app` reads at its start. Its format is `spec`'s `deployment/`, version 1 (`spec/deployment/README.md`), and it holds:
  - `"format": 1`;
  - `"api"`, the origin of your `api`: the output `api_origin` of your configuration, `https://<api_service_name>-<project number>.<region>.run.app` — copy the output's value. It is the service's deterministic address, known before the service is, so you write it with your first list; the release of `app` refuses a file that names another;
  - `"signIn"`, the output `app_sign_in` of your configuration.

  Both outputs are in the file `outputs.json` that a run of `Deploy` keeps as an artifact when it delivers something, or come from `tofu -chdir=tofu output -json` after you sign in as in [Without GitHub Actions](#10-without-github-actions).

  `spec`'s schema at the submodule's tag and the schema in the build of `app` must both accept it.
- **`deploy/production/facts.json`** — the deployment facts your copy declares for `api`'s admission to AI, by provider and fact, each to the age categories it holds for. For example, `{"openai": {"data_processing_agreement": ["adult"]}}`. The providers and facts it may name, and its form, are `spec`'s admission table (`spec/admission/admission-table.json` and `$defs/declared_facts` in `spec/admission/schemas/answer-vector.schema.json`). A copy declares only what is true of its own contracts with AI providers. The platform's facts are not yours.
- **The databases.** `api` keeps its data in two Postgres databases, its own and OpenFGA's. The platform's are on Neon (R03 api). You add four connection strings yourself, as the values of secrets the configuration makes, with `gcloud secrets versions add`:
  - the direct ones, for the migrations: `api-migrate-database-url` and `api-migrate-openfga-database-url`;
  - the pooler's, for the service, for `sweep` and, `api-database-url` alone, for `after`: `api-database-url` and `api-openfga-database-url`. The service reads them at its start and does not start without them.

  Add all four before you set `api_image`: the jobs that come with it mount them.

  Each must ask for `sslmode=verify-full`: `api` refuses any other, and its jobs stop with "must ask for sslmode=verify-full" (`api`'s README). Neon's Connect window gives `sslmode=require`; change it. In Cloud Shell, or wherever `gcloud` is signed in as an owner of your project, this asks for each string without echoing it, mends its `sslmode` and adds it:

  ```bash
  for s in api-migrate-database-url api-migrate-openfga-database-url api-database-url api-openfga-database-url; do
    read -rsp "$s: " v; echo
    v="${v/sslmode=require/sslmode=verify-full}"
    [[ "$v" == *sslmode=verify-full* ]] || { echo "$s has no sslmode=verify-full"; continue; }
    printf '%s' "$v" | gcloud secrets versions add "$s" --project=<project_id> --data-file=-
    unset v
  done
  ```

  A string goes from Neon to the secret and nowhere else: not into a file of the repository, not into a chat.

Run `just deploy-check` before you open the pull request. It downloads the releases from GitHub and checks their signatures with Sigstore, so it needs the network and a fetched `origin/main`. The pull request's check `Deploy` runs it again.

## 9. Deploying

After a merge, the workflow delivers only the parts of the list that changed: `api`'s image or release, the facts, `app`'s build. `api` goes in steps, because its jobs and its service are made with their first image (R11), and `app` goes after `api`'s service, which its `/deployment.json` names (R05):

1. With no `api_image` in your values, there are no jobs and no service. The run of the merge that brings your list builds and pushes `api`'s image alone, from the release, into your registry, holds `app` back, and prints `IMAGE=<region>-docker.pkg.dev/<project_id>/images/api@sha256:…` in its job `api`. To ask for that alone, run `Deploy` by hand with **image** chosen.
2. Put that whole reference, not only the `sha256:…`, into `tofu/production.auto.tfvars` as `api_image`, and merge. The jobs are made. Before this merge, add the values of the four connection strings ([Your list](#8-your-list)), and a first version of the facts, `gcloud secrets versions add api-admission-facts --data-file=deploy/production/facts.json`: the jobs mount them, the job of the check the facts. The deployment adds the version it checks and deploys anyway.
3. Run `Deploy` by hand with **api** chosen. It adds a version of the facts, runs the check of the configuration on exactly that version, then the migrations. A job that fails stops the run there; its own log is in Cloud Run → Jobs → the job → its execution → Logs, and the run's log says only which job it was.
4. Set `api_serving = true`, and merge. The values of the four connection strings must be there by now ([Your list](#8-your-list)): the service reads the pooler's at its start, and without them its first revision does not become ready. The service is made, and with it the schedule of `sweep`, every day at 09:00 UTC: before it, the databases are not migrated yet. Run **api** again to roll it out. If you named an operator, they get a mail when a run of `sweep` fails.
5. The run of the merge that sets `api_serving = true` ships `app` too: the build with your `/deployment.json` to `https://<project_id>.web.app`. Until then a run holds `app` back and says so, and a release of `app` started by hand refuses while the configuration has no service; it refuses too a `/deployment.json` whose `api` is not `api_origin`.
6. Let your learners in. `api` takes nobody from a country you have not allowed, and an account is made only by an invite code. Both are commands of `api`'s binary that you run yourself, not jobs of the deployment: "a job's output is kept in its log, the code with it" (`api`'s README). In Cloud Shell, with the binary of your list's release checked against its sha256 in `deploy/production.json` and the pooler's string read from its secret:

   ```bash
   cd ~ && curl -fsSLo api https://github.com/altnovatrail/api/releases/download/<tag>/api_<tag>_linux_amd64
   echo "<sha256 of the binary>  api" | sha256sum --check && chmod +x api
   export API_DATABASE_URL="$(gcloud secrets versions access latest --secret=api-database-url --project=<project_id>)"
   ./api countries allow US     # once for each country, here the platform's own
   ./api countries list
   ./api invite                 # once for each learner: its last line is the code
   unset API_DATABASE_URL; rm -f api
   ```

   Each code makes one account, and you hand it to the learner yourself. A learner who signs in with Google and gives the code has an account.

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
just deploy-api-facts /tmp/outputs.json     # a new version of the facts alone, checked before the revision
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

## 12. Running the whole platform on one machine

> **Status, 2026-11-11.** Not run yet: `app` has no code. This section says how the pieces fit, by what `api`, `app` and `spec`'s format hold today (R22 and its 2026-11-11 amendment). `spec` has answered both questions this section once left open, В19 and В20: `api` is reached through `app`'s own origin, and the Firebase project is `api`'s dev project. One thing is left to `app`'s first code: which address of `api` its proxy reaches.

A local run is the platform from source: `api` and `app`, each in its own devcontainer and run by its own recipes, with the browser on your machine. It is how the author's first app runs (R76 spec). It needs no copy on Google Cloud, no list and nothing from this repository: `infra` deploys releases, and a local run has none. What `infra` gives here is this section.

It is not offline. Sign-in goes to a Firebase project and `api`'s databases are on Neon. `api` puts it so: "the first app runs locally: `app` and `api` on one machine, preflight is local, and the token check, the database and the AI provider go over the network, as in a deployment" (`api`'s `docs/architecture.md`, «Протокол между `app` и `api`», in Russian). `api` has no setting for an AI provider yet.

### `api`

Follow "Run on the dev projects" in [`api`'s README](https://github.com/altnovatrail/api#run-on-the-dev-projects), in `api`'s devcontainer. In short:

1. Write the configuration: the file `/home/vscode/.novatrail-dev/dev.env`, in a Docker volume of the container, outside the repository. It holds the databases' strings, the Firebase project, the path of the service account's key and `API_PACKAGES_DIR` (R39 api). For `app` on its own origin, add one more line: `API_APP_ORIGIN=http://127.0.0.1:<app's port>`, the origin your browser opens `app` at. `api` then answers CORS for that origin alone, and off a deployment it accepts `http` there.
2. `just packages` lays the modules' packages into `/home/vscode/.novatrail-dev/packages`, the folder `API_PACKAGES_DIR` names. The release of modules that `api` pins holds no package of the current format yet, so the catalog is empty until `modules` moves to it (`api`'s README, Status).
3. `just dev migrate`, then `just dev countries allow US` and `just dev invite`. The country lets the owner's profile be created; the invite code, printed once, lets one owner create an account.
4. `just dev serve`. The server listens on `PORT`, 8080 by default, on every interface of its container. To take another port, set `PORT` in the shell: `dev.env` takes `API_*` names alone.

`just dev-check` runs the whole way once by itself, with a test user, and is a quick check that the configuration holds. It also needs `API_DEV_WEB_API_KEY`, the project's Web API key, in `dev.env`.

### `app`

`app` has no code yet. When it has, its README will name the recipe that serves it, and the file its dev server serves as `/deployment.json`: its plan is a git-ignored `deployment.local.json` (`app`'s `docs/architecture.md`, «Конфигурация развёртывания», in Russian). The file has `spec`'s format, version 1 (`spec/deployment/README.md`):

```json
{
  "format": 1,
  "api": "http://127.0.0.1:5173",
  "signIn": {
    "service": "firebase",
    "apiKey": "<the Web App's API key>",
    "authDomain": "<project_id>.firebaseapp.com",
    "projectId": "<project_id>",
    "appId": "<the Web App's ID>"
  }
}
```

- `api` is the origin of `app` itself, as your browser opens it: put `app`'s port in place of 5173. `app`'s server leads `api`'s paths to `api` by a proxy, its dev server and `vite preview` alike (R09 app; architecture 3.7 app). The lower layer of the page's CSP lets no origin over `http` but its own, so a browser would refuse `api` on a port of its own, though the file is accepted.
- `projectId` is the project in `API_FIREBASE_PROJECT_ID`: `api` accepts ID tokens of that one project.
- `api` may be `http` only because `app` itself is open on a loopback host: the rule `deployment.loopback`. A loopback host is `127.0.0.1`, `localhost` or `[::1]`, and nothing else.
- `api` is an origin with no path and no default port: `http://127.0.0.1:80` is refused by the rule `deployment.api-origin`.
- Open `app` at `http://127.0.0.1:<port>`, not at `localhost`. The Firebase project of a local run has `127.0.0.1` among its authorized domains (architecture 3.12 spec), and Firebase matches an IP address only exactly (`app`'s `docs/architecture.md`, «Конфигурация развёртывания»).

### The two containers

The two devcontainers are on separate Docker networks, `novatrail-api` and `novatrail-app`, so neither reaches the other by its name. Your browser reaches a server in a container through a port that VS Code forwards to your machine ([Developing inside a Container](https://code.visualstudio.com/docs/devcontainers/containers#_forwarding-or-publishing-a-port), updated 2026-11-04, read 2026-11-10):

- Open each repository in its own VS Code window. Once a server runs, look for its port in the Ports view of its window. If it is not there, run **Forward a Port** from the Command Palette. Neither `devcontainer.json` names a port to forward.
- "A notification will tell you the localhost port you should use to access the port in the container". It may be another port: "it was mapped to port 4123 on localhost". Use the port your machine has for `app`, in `/deployment.json` and in `API_APP_ORIGIN`.
- A server bound to `127.0.0.1` in its container still answers: "Forwarded ports, on the other hand, actually look like localhost to the application".

The browser talks to `app`'s origin alone, and the request to `api` goes on from `app`'s proxy, inside `app`'s container. Which address of `api` that proxy reaches from there is not settled: the first task of `app`'s code checks it (row Д177 of `spec`'s RUN.md), and this section changes with what it finds.

### A Firebase project

A local run needs one. The format requires `signIn` with the service `firebase`, has no default and no field for an emulator, and `authDomain` is a host name with no port. `api` refuses to start with `FIREBASE_AUTH_EMULATOR_HOST` set, because the emulator verifies no signature (R32 api).

It is `api`'s dev project, on the free Spark plan with sign-in through Google (R03, R39 api): one project for `api` and `app` (architecture 3.12 spec, the row «сервис входа»). For `app`, the author adds to it once, in the Firebase console:

- a Web App, in Project settings → Your apps, whose app ID goes in `signIn`. Its API key is the project's Web API key, which `api`'s `dev.env` already holds as `API_DEV_WEB_API_KEY`;
- `127.0.0.1` in Authentication → Settings → Authorized domains.

Your copy's project is not for this. The module keeps its authorized domains to `<project_id>.firebaseapp.com` and `<project_id>.web.app`, with no loopback host (R16).

### What `infra` does not give, and why

- **A Firebase project for a local run.**
  - The module turns on Identity Platform through OpenTofu, which needs a project with billing, on the Blaze plan. Its budget needs a billing account too. A local run needs neither.
  - The module keeps loopback hosts out of a deployment's domains (R16).
- **A compose file or emulators.**
  - Work runs inside the devcontainers, and neither has Docker: a compose file would run on your machine, beside them.
  - `api` keeps its databases on Neon, not in a container (R05 api).
  - The Hosting emulator was rejected for `app`'s build (R17), and `api` refuses the sign-in emulator.
- **A list, a `/deployment.json` or facts in `deploy/`.** They name releases and a deployment, and a local run has neither.
