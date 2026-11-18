# infra — architecture

> Status: sections 2 and 3 are decided, and the code they describe — the module, `bootstrap.sh`, the checks and the deployment — runs the platform's project `novatrail`. What it deploys is `deploy/production.json`; the tag of `spec` is the submodule; the work in progress is [RUN.md](../RUN.md); what was done, and when, is in git and the epics' archives `docs/plan/` (R160 spec).
>
> What the component does, what it does not do, and what is still to decide about it. This is the detail of its card — architecture 3.11 spec. The card stays the summary: if the detail changes what the card says, the card is changed in `spec` the same way as the questions for its registers (RULES.md, Across repositories).
>
> Why it was decided so and not otherwise is in [decisions.md](decisions.md); the work plan is in [RUN.md](../RUN.md). The concepts are concepts spec. The documents and decisions of `spec` are under `spec/docs/` and are cited with the suffix "spec".

## 1. Purpose and boundaries

**Does:**
- describes in code the platform's shared base: the projects in the cloud, Workload Identity Federation for CI, Artifact Registry, the domains, Secret Manager and the budgets (architecture 3.11 spec). The base is the technology base of MathTrail Canvas: Cloud Run and managed services that scale to zero, and the tool is OpenTofu, the open fork of Terraform, at an exact version (R11 spec; section 3.6). The model is `infra/` of canvas-api: `bootstrap.sh` and one root module in HCL (architecture 3.11 spec);
- sets up the platform's logs and traces — Cloud Logging and Trace (architecture 3.12 spec):
  - Cloud Run's request logs are excluded in Cloud Logging. Cloud Run writes them itself, and their field `httpRequest` holds the client's IP address, while COPPA counts an IP address as personal information (architecture 1 spec; privacy 4 spec). All of them are excluded, by a filter in each sink. The traces that Cloud Run writes itself on a part of the requests are possible — Cloud Trace API cannot be turned off while Cloud Scheduler needs it —: they are kept in `us-east4`, and the first trace will check their attributes: there has been none (R07; section 3.4; Д17);
  - the logs' region is `us-east4`, and the bucket `_Required` is in `global` while there is no Google Cloud organization (R04; R109 spec);
- chooses and sets up the hosting of the build of `app` — Firebase Hosting, with no domain of its own (R06; section 3.3) —, and by stage 4 the widgets' domain, a separate registrable one (R16 spec), and the hosting of the widgets (architecture 3.12 spec; Т-17). Only a hosting that sends its own response headers — CSP by the build's `csp.json`, and the cache — and serves `/deployment.json` outside the build's archive suits the platform (Т-17; architecture 3.12 spec). The samples page of `canvas` will move to Firebase Hosting as a separate site of the project with its own origin when the author decides so: Google is a processor for Hosting, and it keeps IP addresses "a few months" (R25 spec; R128 spec);
- keeps the operator's two buckets, private Cloud Storage buckets in `us-east4` that `bootstrap.sh` makes and holds with the operator's rights, not the module (R28; section 3.7). The operator's bucket holds the samples from the samples page, the forms for them and the organizers' records, with a prefix per purpose, with access only for the organizers, each to their own, without agents, as R125 spec asks — CI reads it all the same through Firebase Admin, which R125 spec accepts while only adults' files lie there, and before the first child both buckets move to a project of the operator's own (R28; Д23) —, and with lifecycle rules; files come by an upload link, a POST policy signed through IAM, with no key, for at most 12 hours (R125, R126 spec). The bucket of the scans holds the scans of the consent forms from `app`, under `consent-forms/`, which only the operator reads: the service `api` and the jobs `sweep` and `check` get the bucket and the prefix as the variables `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`, and their service account `api-run` gets the right to create and erase objects on the prefix, without reading (R116, R125, R126 spec; architecture 3.11 spec; R11);
- rolls out the services and the build of `app` by one list of exact versions and digests (R106 spec). In the dependency diagram `infra` rolls out the releases of `api` and `app` (repositories 3 spec). How the deployment goes (R105 spec, R106 spec; architecture 3.11 spec):
  - a service's image is built by the deployment of `infra`: it takes the binary and the `Dockerfile` from the service's release, checks them with the recipe of `spec` `release-verify` (R77 spec), builds the image on the base `gcr.io/distroless/static-debian13:nonroot` by digest, puts it into the private Artifact Registry of `infra` and rolls out a Cloud Run revision by the image's digest. The image of `api` is built by the contract of its release (R106 spec; section 3.2). What a service puts into the image beyond the binary, its own code does at the build stage: for `api` these are the module packages. NovaTrail publishes no images (RULES.md, Production images);
  - the rollout checks the build of `app` by the archive's signature, writes `/deployment.json` from the rollout list, having accepted it by the reading of the deployment configuration of the `spec` of its submodule — the schema and the rules — and by the schema `deployment.schema.json` of this build, and refusing a build of another format version (R85 spec; R19), builds the CSP header by the build's `csp.json` and releases the build, the file and the header in one release of the hosting (R85 spec). Beside the build's digest the list names the digest of its `/deployment.json` (Т-19);
  - a rollback is a revert of the list. `api`, and while the module format is v0 also a build of `app` that has moved to a new format version, roll back only forward (Т-19);
  - the jobs of `api` at a deployment — the migrations before requests are accepted, the job after the deployment once the revision has taken all the traffic — the deployment runs with the same image, and it hands the revision the deployment facts and the lowest admission rung of `api` from its own repository: the facts as a file, a secret's volume, the path in `API_ADMISSION_FACTS_FILE`, the rung in `API_ADMISSION_RUNG`, and before the migrations a job calls the command of `api` that checks them (R106 spec);
  - the format and place of the list and who edits it, what the rollout checks before the deployment, that a release of `api` lower than the one rolled out is refused, and how the revision of `api` gets the facts and the rung are R05 (section 3.2);
- gives self-hosting and a local run of the whole platform (architecture 3.11 spec): the code is open, and an operator can deploy their own copy of the platform themselves (product 3 spec). Self-hosting takes the same list and the same path of deployment: it builds the image on its own side from the same binary and by the same `Dockerfile` (R105 spec, R106 spec). The signed build of `app` is one for everyone: it reads the deployment configuration at run time from `/deployment.json`, and the self-hosting operator writes that file themselves by the same schema (R85 spec; Т-19). Self-hosting declares its own facts for the admission to AI itself (Т-20; R96 spec).

**Does not:**
- stores no learners' data: of the platform's parts only `api` stores it on the server (architecture 1 spec; R15 spec). The operator's two buckets (section 3.7) hold not learners' data from `app` but the samples from the samples page, the forms for them and the scans of consents, and the rules for them are R116, R125 and R126 spec. The database and the sign-in service were chosen by `api`: Neon Postgres and Firebase Auth (architecture 3.12 spec);
- keeps no secrets in the repository: the keys of AI providers are in Secret Manager (architecture 3.12 spec), and the service account of `api` reads them (R15 spec). The platform's keys for eval are there too (R24 spec) — `eval-key-anthropic` and `eval-key-openai` —, and CI of `modules` and `tutor` reads them through Workload Identity Federation, with its own pool `github-eval`, only the job of the GitHub environment `eval` (R120 spec; R20). The keys' values are never in the repository's files (RULES.md, Hard rules);
- holds no code of the services and does not publish their releases: the release with a signature is a shared workflow of `.github` that each repository with code takes (architecture 3.11 spec; repositories 2.1 spec);
- sets up no clusters, queues or event bus of its own. Background work is Cloud Run jobs on a schedule (architecture 1 spec; R11 spec); Cloud Scheduler and Cloud Run jobs are chosen by `api` and `infra` together (architecture 3.12 spec);
- does not serve the module packages in the first slice: at stage 2 they are in the image of `api`, and `api` serves the media files (architecture 3.10 spec). The code of `api` itself puts them into the image at the build stage, and the deployment does not repeat the logic of the packages (R106 spec). A store with a CDN in `infra`, by the recommendation of Т-17, comes when there are more modules or third-party authors arrive (repositories 8 spec);
- does not decide the data's region alone: `spec` decided it — the US, one place for all learners (R109 spec) —, and here is only what follows from it for the resources of `infra` (R04).

**Data and links:**
- there are no learners' data and no secrets in the repository, as in no repository of the platform (RULES.md, Hard rules). But what it sets up — the logs, the region, the hosting — touches learners' data, so every proposal here is first read against privacy spec (RULES.md, Hard rules). The hosting and the infrastructure are data processors (privacy 2 spec);
- what the operator does in a breach of learners' data — where the data are and what opens them, how to cut the access, the logs, whom to tell and by when — is the procedure [BREACH.md](../BREACH.md), at the root, in English, for people, as SELF-HOSTING.md is: its part 1 fits any copy, its part 2 is the operator of `novatrail` and the law of Texas (R27);
- the logs hold events, codes, times and versions, without direct identifiers, IP addresses, works, what was read and the text of hints (R09 spec; privacy 4 spec; architecture 5 spec), but for the audit of the reads of the secrets: its entries hold the reader's email or principal and address — a service account's, an eval job's from a GitHub runner or the operator's, never a learner's. The platform's logs are kept 30 days in `us-east4`, that audit among them, and Admin Activity 400 days in `_Required`, in `global` (R07; П-9);
- the hosting of `app` and the sign-in service write the IP address into their own logs themselves (architecture 1 spec; architecture 3.12 spec; privacy 4 spec; П-9). The hosting is Firebase Hosting: it keeps IP addresses a few months, globally, and the period is not configurable, and `infra` does not turn on the export of its logs to Cloud Logging (R06). The sign-in service that `api` chose is Firebase Auth: it keeps IP addresses a few weeks, and it gets them not only at sign-in — on an iPad, in Safari and in mobile browsers its script and iframe load at every start of `app` (privacy 4 spec; architecture 3.12 spec; П-9);
- of NovaTrail's repositories it depends at build time only on `spec`, and while the platform runs it calls no one and no one calls it (repositories 2.1 spec). The table of repositories 2.1 spec is about the links between the repositories and about the platform's work. The tools of `infra` itself are not in it, and they go to the network: to GitHub and Sigstore — the checks and the deployment, to Google — `gcloud` and OpenTofu, to the OpenTofu registry — `tofu init` for the providers, to npm — the packages of `tools/` (sections 3.2 and 3.6). In the dependency diagram its arrows are the deployment of the releases of `api` and `app` (repositories 3 spec);
- it takes the shared checks of CI — secret scanning, DCO, CodeQL, Scorecard and the documents check — from `.github`, at the release its workflows pin, `.github/workflows/*.yml` (R30 spec; architecture 3.11 spec). The shared Documents check and `infra`'s own job `Deploy` take the image of the stage `toolchain-core`, Node, just, Go and buf, from one entry of the cache of GitHub Actions, and the job `OpenTofu` takes the stage `toolchain`, which adds OpenTofu, ShellCheck and actionlint, from an entry of its own. Only a push to `main` saves an entry, and on a miss `infra`'s job `Toolchain image` alone builds both stages for the other two (R32; R34). CodeQL reads the workflows and the code in JavaScript — `tools/` and the tests of `tofu/`, the input `languages: javascript-typescript`. CodeQL does not read HCL and bash: its list of languages is C/C++, C#, GitHub Actions, Go, Java and Kotlin, JavaScript and TypeScript, Python, Ruby, Rust and Swift ([CodeQL, Supported languages and frameworks](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/), read 2026-11-09);
- a file of a NovaTrail release — a service's binary, its `Dockerfile`, the build's archive of `app` — enters the deployment only once the recipe of `spec` `release-verify` has accepted it (RULES.md, Release files are verified; R77 spec);
- its services (architecture 3.12 spec): the hosting of the build of `app`, the widgets' domain and hosting at stage 4, Secret Manager, Artifact Registry, Cloud Logging and Trace, and together with `api` Cloud Scheduler and Cloud Run jobs;
- stage 2, with `tutor`, `canvas`, `api`, `app` and `skill-map` (product 11 spec); its code needed the data's region before the first deployment, which R109 spec decided (architecture 3.11 spec; repositories 2.1, 6 spec; R03). OpenTofu is in the devcontainer's stage `toolchain` (R08; R09; section 3.6).

## 2. To decide when detailed

The points of the card's "To decide when detailed", and those this repository added beyond the card's list — a subsection for each, the two points about the rollout in one, 2.2. All are decided: each names its entry of the log, and the design is in section 3. A new open point becomes a subsection here, with its options and a recommendation; a question that goes beyond this repository goes «в реестр spec» (RULES.md, Across repositories).

### 2.1. Region (П-11)

Decided: R04, by R109 spec; section 3.1.

### 2.2. The list of versions and the checks of the rollout (R106 spec)

Decided: R05; section 3.2.

### 2.3. Hosting of the build of `app` and domains (Т-17)

Decided: R06; section 3.3.

### 2.4. Excluding the request logs

Beyond the card's list. Decided: R07; section 3.4.

### 2.5. Terraform or OpenTofu (Т-29)

Decided: OpenTofu, R11 spec (R08); section 3.6.

### 2.6. Self-hosting and the local run

Beyond the card's list (architecture 3.11 spec). Decided: R21, R22, R23; section 3.5:
- **self-hosting** — the operator's guide [SELF-HOSTING.md](../SELF-HOSTING.md): the main path is a fork with GitHub Actions, and without them the same recipes with the operator's rights (R21). Its own region, its own Firebase project and its own environments are the copy's values, and the tests on a copy's values hold them (R18);
- **the local run of the whole platform** — from source, by the recipes of `api` and `app`, and `infra` gives a description — "Running the whole platform on one machine" [SELF-HOSTING.md](../SELF-HOSTING.md#12-running-the-whole-platform-on-one-machine) (R22). `api` in it is the origin of `app` itself, and the proxy of the server of `app` leads the paths of `api`; the sign-in project is the dev project of `api` (R22).

What this changes in the card 3.11 spec is R23. The steps of the guide that nobody has walked are Д9.

### 2.7. Signing the upload link to the operator's bucket (R125 spec)

Decided: R28; section 3.7. The link is a V4 POST policy, with conditions on the object's name and size in the signature itself, signed through IAM as an upload service account, with no key: without a key a signature lives at most 12 hours (sources 10.1; R125, R126 spec). There are no keys of service accounts in files, and there will be none (RULES.md, Hard rules).

### 2.8. Auditing the reads of the secrets

Beyond the card's list; found by the procedure for a breach (R27). Decided: R07, option (a); section 3.4. The options: (a) Data Access, `DATA_READ`, for `secretmanager.googleapis.com` alone, which the exclusion `data-access-audit` of each sink lets through; (b) none, and the procedure says what the logs do not show. An entry holds the reader's email or principal and `callerIp`, and the readers are `api-run`, CI and the operator, never a learner. The module turns on `DATA_READ` of Secret Manager, and each sink keeps its version reads 30 days in the bucket of `us-east4`: in a breach the logs show who read a version — among them the four connection strings to the databases of `api` in Neon, which open learners' data —, not only who added or disabled one and who changed a right on a secret, which is Admin Activity (sources 2.6).

## 3. How it is built

Here is what was decided by section 2: which parts the component consists of, its data and how it is linked with other repositories. The decisions are R04–R07 and R11 spec (section 3.6).

**What the repository consists of:**

| Part | What it does | Decision |
|---|---|---|
| `tofu/bootstrap.sh` | once, with the operator's rights: the project and its billing, the state bucket, the Workload Identity Federation pool for CI, the configuration's service account `infra-config` and its rights, and the custom roles that the module grants — `apiDeployer`, `hostingPublisher` and `signInUsers`; the second pool, `github-eval`, for the eval job of `modules` and `tutor`, with no service accounts; the operator's bucket and the bucket of the scans of consents, with their access and lifecycle rules, and the two upload service accounts (section 3.7); on the model of canvas-api | R13, R20, R28; R11 spec; model — canvas-api |
| the OpenTofu root module, `tofu/` | the project and its services: Artifact Registry, Secret Manager with the secrets of `api` and the keys for eval (R20), the log bucket and the sinks with exclusions, the place of the bucket `_Trace`, Firebase with the Hosting site and the Web App, Identity Platform, the service accounts and their rights, the audit of the reads of Secret Manager's versions, the project's contact for Google's security notifications, the budget and the alerts, the Cloud Run service and jobs and the jobs' schedule in Cloud Scheduler. The module creates the service and the jobs with the first image, which `api_image` names, and after that the deployment sets the image, the revision and the facts' version in the volume by digest, and the module does not touch them, as `ignore_changes` does at canvas-api (sources 8.1). Everything is in the region of section 3.1 | R04, R05, R06, R07, R10, R27; R11 spec |
| `deploy/` | the rollout list, the values of `/deployment.json`, the facts file and the list's schema | R05; section 3.2 |
| the checks of a pull request | the schema, `release-verify` and sha256, `deployment.json`, the facts, the rung, the tag of `api` not lower | R05 |
| the deployment | recipes and a workflow: the image, the jobs of `api`, the revision, the release of the build of `app` on Hosting | R05, R06; sections 3.2, 3.3 |

The recipes of the checks and of the deployment run without GitHub Actions too — self-hosting uses the same ones (section 3.5).

**Links with other repositories:**

| Repository | What `infra` takes | What `infra` gives |
|---|---|---|
| `spec` | the rules, `release-verify`, the admission table and the format of `/deployment.json` — the part `deployment/` with its own version, a schema at a permanent path and reading vectors (R85 spec; R19) | the rows «в реестр spec» of table 3, [run/QUESTIONS.md](../run/QUESTIONS.md) |
| `api` | the release's binary and `Dockerfile` by the build contract, the commands of the configuration check, of the migrations, of the job after the deployment and of `sweep` (R28 api; R106 spec) | the image, the revision and the jobs, the facts file — the path in `API_ADMISSION_FACTS_FILE`, the rung — in `API_ADMISSION_RUNG`, the mode of reading — in `API_READING_MODE`, the catalog's list — in `API_CATALOG_MODULES`, the platform's key of Anthropic — the path in `API_ANTHROPIC_KEY_FILE` (section 3.8), the databases' connection strings from the secrets, `API_APP_ORIGIN`, the scans' bucket and prefix — `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX` — and the right there, the schedule of `sweep`, the address `*.run.app` |
| `app` | the build's archive with `deployment.schema.json`, `csp.json`, `NOTICE` and `LICENSE` (R85 spec) | `/deployment.json`, the headers, the origin `web.app` and the authorized domain of Firebase |
| `canvas` | — | later, a separate Hosting site for the samples page (R06) |
| `.github` | the shared checks of CI; the release files that `infra` rolls out are signed by the shared `release.yml`, and `release-verify` of `spec` checks the signature (R77 spec) | — |
| `tutor` | the codes of the admission rungs, `author` and `full`, the type of the facts file and its parsing (R57 tutor) | — |
| `modules`, `tutor` | — | the platform's keys for eval `eval-key-anthropic` and `eval-key-openai` in Secret Manager, for the job of the GitHub environment `eval`, through Workload Identity Federation with its own pool `github-eval`, which `bootstrap.sh` makes; the names of the provider and of the secrets are the output `eval_access` (R120 spec; R20) |

### 3.1. Region

The platform's region is the US, one place for all learners (R109 spec). What this means for the resources of `infra` is R04. Sources: sources 1.1–1.8.

| Resource | Place | Why so, and what does not change after creation |
|---|---|---|
| Cloud Run services and jobs | `us-east4` (Ashburn, Virginia) | near Neon `aws-us-east-1` of the database of `api`; Tier 1 prices |
| the jobs' schedule, Cloud Scheduler | `us-east4` | in the region of the jobs it runs: the module puts it in the module's region |
| the Artifact Registry repository | `us-east4`, regional | a repository's place does not change; a multi-region is slower |
| Secret Manager secrets | user-managed replication, place `us-east4` | the replication's places do not change; automatic replication has no constraints, and a regional secret is accessible only from its own region, and CI on GitHub, which reads the keys for eval (R120 spec), could not read it |
| the log bucket | its own, `us-east4`; the sink `_Default` is directed to it | the bucket `_Default` is created in `global`, and a bucket's place does not change — the sink changes. Cloud Run's request logs are excluded (section 3.4) |
| the bucket `_Required` | `global` | the sink `_Required` does not change, and only a setting of an organization or a folder made before the project is created gives the bucket a region; an organization is tied to a domain, and there is none until О-16 — Д3 in table 4 of [run/DEBT.md](../run/DEBT.md) |
| the trace bucket `_Trace` | `us-east4`: the default place for Observability buckets is set before the first trace, and the system creates the bucket with the first trace (R04) | otherwise the default settings or the system itself would choose the place, and only a reprovision, which erases the traces, can change it |
| the state bucket and the operator's two buckets, Cloud Storage | `us-east4`: `bootstrap.sh` makes each in the region of `production.auto.tfvars` (R13, R28) | a bucket's place does not change: the script stops on a bucket of the operator's that stands elsewhere, and its files go by hand to a bucket made anew (section 3.7) |

Not `infra`: `api` keeps the Neon database `aws-us-east-1`; Firebase Auth processes data only in the US whatever the region; the hosting of the build of `app` is Firebase Hosting (R06), a global service; R109 spec does not decide the region of AI calls (R96 spec).

### 3.2. The rollout list and the deployment

`infra` rolls out the services and the build of `app`, by one list of exact versions and digests, and the deployment builds a service's image from the files of its release (R105, R106 spec). A component's repository rolls out nothing itself and has no access to production: the projects and Workload Identity Federation for CI are with `infra` (R106 spec). How the list and the deployment are built is R05.

**The directory `deploy/`:**
- `production.json` — the rollout list;
- `production/deployment.json` — the values of `/deployment.json` of the build of `app`, format 1 (R09 app); `api` in it is the deterministic address of the service, the module's output `api_origin`, `https://<service>-<project number>.<region>.run.app`: it is known before the service exists (R05);
- `production/facts.json` — the file of deployment facts for the admission function, in the form `facts` of the admission table ([the admission table's text](../spec/admission/README.md), section 5);
- `production/legal/` — a self-hosted copy's own legal texts, if it has them: `VERSION`, `legal.yaml` and `texts/` alone, in the layout of [the part `legal/`](../spec/legal/README.md) of `spec`; the deployment lays the folder over the image of `api`, and the platform has none (R33);
- `schema/production.schema.json` — the list's JSON schema, JSON Schema 2020-12 (R14).

**An example of the list** — synthetic: the versions and digests are made up.

```json
{
  "format": 1,
  "api": {
    "release": "v0.4.2",
    "binary": {
      "name": "api_v0.4.2_linux_amd64",
      "sha256": "1111111111111111111111111111111111111111111111111111111111111111"
    },
    "dockerfile": {
      "sha256": "2222222222222222222222222222222222222222222222222222222222222222"
    }
  },
  "app": {
    "release": "v0.3.0",
    "archive": {
      "name": "app_v0.3.0.tar.gz",
      "sha256": "3333333333333333333333333333333333333333333333333333333333333333"
    },
    "deployment": {
      "sha256": "4444444444444444444444444444444444444444444444444444444444444444"
    }
  },
  "admission": {
    "rung": "full"
  }
}
```

The name of the binary of `api` is by the contract of its release, `api_<tag>_linux_amd64` (R28 api; R106 spec); beside the binary the release carries the `Dockerfile` and `SHA256SUMS`, each file with a signature (sources 3.3). The platform's list is `deploy/production.json`, and a release is raised in it by a task of R29. The deployment runs the binary's commands `check`, `migrate`, `after` and `sweep` as jobs, and the operator runs `countries` and `invite` by hand (R25; sources 3.10, 3.11).

**A pull request with the list** — CI without access to production:
1. the list — by its schema;
2. the binary, the `Dockerfile` and the archive — `release-verify` with the repository and the tag from the list, and the sha256 of each as in the list, and the binary's name by the release's contract. If Sigstore or GitHub does not answer, the file is refused (R77 spec);
3. `deployment.json` — by the reading of the deployment configuration of the submodule's `spec`, as `app` reads it: the schema `deployment/schemas/deployment.schema.json`, then the rules `deployment.api-origin` and `deployment.loopback` —, and by `deployment.schema.json` from the archive, and the build must read the same format version as the submodule's `spec`, or it is refused, with both named (R85 spec; R19); the file is no more than 16 KiB, and its sha256 as in the list; `api` in it is the address of the service `api`, the output `api_origin`, by the project number from `tofu/ci.env` and the values of `tofu/production.auto.tfvars`, and without `ci.env` or outside a git repository it is not compared (R14);
4. `facts.json` — by the facts' vocabulary of the admission table of the submodule's tag of `spec`: this is an early sign, and the image of the new release of `api` checks the file finally (step 4 below);
5. the rung — the one `api_admission_rung` of the configuration names, by default `full` (R05; section 3.8) —, and `full` wherever `facts.json` names a category under 18, `under_13`, `from_13_to_consent` or `from_consent_to_18` (R149 spec; R05);
6. the tag of `api` — not lower than in the list on `main`;
7. a copy's `production/legal/`, if there is one — nothing but files and folders in it, and the recipe `legal-check-dir` of the submodule's `spec`; the image of `api` checks it finally, in the job `check` (R33).

**The checks in code** (R14) — `tools/deploy-check/` on Node and ajv, at the version of `tools/package.json`, the recipe `just deploy-check`. The CI job `Deploy` runs their tests in every pull request — the synthetic ones and a real release of `api` against GitHub and Sigstore —, and the list itself when the pull request changes what it is checked by: `deploy/`, `tools/deploy-check/` and `tools/deploy/`, their packages, the `justfile`, the tag of `spec` or `tofu/variables.tf`, whose default names the service `api`. An edit of `tofu/ci.env` and `tofu/production.auto.tfvars` alone does not check the list, but for the line `api_admission_rung` (section 3.8): a fork's first pull request changes only them, and its list is still the platform's, with the platform's address of `api` (R14). The same job runs the tests of the deployment, of the tools' installation and of the organizer's tool (section 3.7), and the license check.

**The deployment** — after the merge, from the list's commit. The first job checks that `main` is at this commit, and each next one checks it on a retry (R45 canvas-api). The deployment does only what changed against the commit of the last run that deployed — the job `target` below (R18).

A new release of `api`:
1. the cloud's configuration — `tofu apply` from the same commit (section 3.6); this step runs at every deployment;
2. the tag of `api` — not lower than that of the revision that takes the traffic now: `main` may be ahead of production if the last deployment did not get through. Traffic split between revisions is a refusal: that rollout is first finished or undone by hand. Then `release-verify` and the sha256 of each file again — only a checked file gets into the job that reaches production. If the registry already holds an image under the release's tag, the deployment takes it by digest, without the second check and without step 3;
3. the image — by the contract of the release of `api`: the binary as the file `api` in the build context `binary`, the image by `docker build --target release --build-context binary=<folder>` by the `Dockerfile` from the release, on the base by digest that the `Dockerfile` names; the stage does not read the main context (R105 spec; R28 api; R106 spec). The build stage puts the module packages into the image with a command of the binary, and it needs the network (architecture 3.3 api). The image goes to Artifact Registry `us-east4` (R04), its digest from the push. A copy with `production/legal/` runs this image with the folder laid over it: an image `FROM` it by its digest, the folder at `/etc/api/legal`, owned by root and read by all, and `ENV API_LEGAL_DIR=/etc/api/legal`, under the tag `<release>-legal-<sha256 of the folder>`, which the registry may hold already; the steps below run that image (R33);
4. the configuration check — by a Cloud Run job with the same image, with the facts file and the rung of the new list: the module gives the job of the part `check` the facts' volume, `API_ADMISSION_FACTS_FILE`, `API_ADMISSION_RUNG`, `API_READING_MODE` and, when the configuration names modules, `API_CATALOG_MODULES`, and the deployment gives the exact version of the facts, the one that will go to the revision (R11; R15). The job is `api check` (R11): a fact unknown to this release's table stops the deployment before the migrations. The command comes from the binary `api`: it checks the facts file against the release's admission table, and the rung, and serves no requests (R106 spec);
5. the migrations job of both databases, `api` and `openfga` (R05 api), with the same image by digest, by the command that the release of `api` names. If it fails, the deployment stops, and there is no new revision;
6. the Cloud Run revision by the image's digest — with the facts file as a volume on an exact version of the secret (R05; R106 spec): the module sets the path to it in `API_ADMISSION_FACTS_FILE`, the rung in `API_ADMISSION_RUNG` and the mode of reading in `API_READING_MODE` (R05; R11) — at first with no traffic; when its own condition `Ready` is `True`, all the traffic goes to it (R15);
7. the job after the deployment — with the same image, once the new revision has taken all the traffic (R106 spec): `api after`, with the pooler's string of the database `api`, closes as "unchecked" what is open on packages the image no longer gives (R11). Its failure stops the deployment already on the new revision, and this run's `app` does not run; what it did not close the next `sweep` will close (R15).

Facts only: a new version of the facts' secret, its check — step 4 on the image already rolled out —, and a new revision on this image, by its digest — step 6; there are no steps 2, 3, 5 and 7 (R05). A copy's `production/legal/` that changed or went goes the same way: the image is the release's own that takes the traffic — its digest, or, when it carries texts, the image of its release's tag — with the folder as it now is laid over it, or with none, and the other jobs then take that image too (R33). A change of the rung, the mode of reading, the catalog's list or the key's version goes the same way (R05). There is no build, no migrations and no `release-verify`: the release's files did not change, and the removal of a fact does not wait for Sigstore.

A new release of `app` — only when the service `api` exists: while the commit's `production.auto.tfvars` does not set `api_serving = true`, a run does not roll out `app`, and the run that set it rolls out `app` even if it did not change (R05):
1. `release-verify` of the archive and the sha256 — as in step 2;
2. the archive is laid out on the hosting, `/deployment.json` is written from `deploy/production/deployment.json`, the CSP header is built by the archive's `csp.json`, and everything goes out in one release of the hosting (R85 spec; R09 app). On Firebase Hosting — section 3.3 (R06);
3. the domain of `app` is in the authorized domains of the Firebase project (Т-19): the module sets them, by the cloud's configuration of the same deployment (R16).

**The deployment of `api` in code** (R15) — `tools/deploy/api.sh`, the recipes `just deploy-api-image`, `deploy-api` and `deploy-api-facts`, on the module's outputs after `apply`:
- `image` — the release's files again through `release-verify` and sha256, the image `<registry>/api:<tag>`, the digest after the push — or the image that the registry already holds under the release's tag —, and for a copy with texts the image laid over it (R33);
- `release` — the steps above: a refusal of a release lower than the one whose tag the image of the revision with traffic carries in the registry, the image — or the one the registry already holds under the release's tag —, a new version of the facts, the image to the jobs `check` and `migrate` — to the jobs `check` with the exact version of the facts, the one it has just added — and their run, a revision without traffic, all the traffic to it by name, the image to the other jobs, and the jobs `after`. Without the service, only the jobs;
- `facts` — the path "facts only": a version of the facts, the jobs `check` with it on the image that takes the traffic, and a revision; with a copy's texts that changed, on the image of the same release with the texts laid over it anew (R33).

Which jobs to run when is said by the field `deploy` of the module's entry `api_jobs` (R11). By default these are `check` — the configuration check before the migrations, `migrate`, `after` — after the revision has taken all the traffic —, and `sweep` on a schedule (R11).

**The release of `app` in code** (R17) — `tools/deploy/app.mjs`, the recipes `just deploy-app` and `deploy-app-check`, on the module's outputs after `apply`, `hosting_site` and `hosting_url`, through the REST API of Hosting:
- `release` — the steps of section 3.3: `deployment.json` of the sha256 that is in the list; the archive of the new build and that of the released one — `release-verify` and sha256 again; the service `api` in the module's outputs and the file's `api` equal to `api_origin` — otherwise a refusal before Hosting (R17); one version with the configuration, a release with a message that names the build, and the check of the responses;
- `check` — only the check of the site's responses, by the build from the list.

The release signs in with an access token of `hosting-publish` from `gcloud`, and it needs no rights but `hostingPublisher` (R12). The check of a pull request looks at the same layout and the same `csp.json` of the build as the release does (R14).

**The deploy workflow** (R18) — `.github/workflows/deploy.yml`, after a push to `main` by the paths of what it deploys, or by hand with a choice of parts:

| Job | Environment and service account | What it does |
|---|---|---|
| `target` | none, without sign-in | is `main` at the commit? is the project up? which parts of the list changed against the last run that deployed; without `api_image`, only the image of `api` |
| `config` | `production-config`, `infra-config` | `just ci-tf-apply`; the module's outputs as an artifact; all three environments exist and run only from `main` — `just ci-deploy-environments` |
| `api` | the output `deploy_environment`, by default `production`; `api-deploy` | `just deploy-api`, `deploy-api-facts` or `deploy-api-image` — while there is no `api_image`, or by hand |
| `app` | the output `hosting_environment`, by default `production-hosting`; `hosting-publish` | `just deploy-app`, after `api` if it ran and passed |

Each job after `target` asks on a retry whether `main` is at the commit. `.github/actions/tools` installs the tools at exact versions and sums: OpenTofu, `just` and Node by the `ARG` of the Dockerfile, the Google Cloud CLI, `jq` and `buildx` by `tools/ci/versions.env`, and the runner's Docker engine is checked against the recorded version.

**The operator's step before the first deployment**, after `bootstrap.sh`:
1. `tofu/ci.env` — the two lines that `bootstrap.sh` printed, `GCP_WORKLOAD_IDENTITY_PROVIDER=…` and `GCP_CONFIG_SERVICE_ACCOUNT=…`, and nothing else; the file is committed and goes through review (R13);
2. the GitHub environments `production-config`, `production` and `production-hosting`: Settings → Environments → New environment, in each "Deployment branches and tags" → "Selected branches and tags" → the rule `main`. No reviewers and no wait timer: the approval is the review of the pull request (R05). An environment that does not exist GitHub creates itself at the first job — with no rule, and then `ci-deploy-environments` of the job `config` stops the run before the jobs `api` and `app` (R18);
3. in `production-config`, the environment's secrets `TF_VAR_billing_account` and `TF_VAR_operator_email`; the other environments have no secrets.

While `tofu/ci.env`, `tofu/production.auto.tfvars` and `tofu/backend.hcl` are not in `main`, a run of the deployment is green and does nothing; once they are, every merge that changes the deployment's paths applies the configuration in the project they name.

**Rollback:**
- `api` — only forward: a new release of `api` and a new pull request, and neither CI nor the deployment lets a lower tag through;
- the build of `app` — a pull request that returns the list's block `app` to its former values: the former build with its own file, in one release. A revert of a whole commit that also raised `api` would be refused. A build that has moved to a new module format version goes only forward, and the author checks this in review;
- the facts — a pull request with the former file: a new revision on the same image. The rung, the mode of reading, the catalog and the key's version go back the same way. To close the platform AI urgently, remove a fact (R96 spec).

A deployment that did not get through is repeated by rerunning its jobs, or fixed forward by a new pull request.

**The registry and the facts' secret in the module:**
- `tofu/registry.tf` — the Docker repository `images` in the region. The cleanup keeps the 5 latest versions in any state, and deletes only untagged versions older than 30 days; a version that fits both keeping and deletion is kept (sources 5.4). The deployment pushes the image with the release's tag, so the image rolled out keeps its tag however many pushes come after it, and the path "facts only" stands on it by digest; the tag is lost only by a push of the same release by hand: the deployment takes the image the registry already holds under the tag. The module does not delete the repository: `deletion_policy = "PREVENT"`. The module gives no reading of it outside the project, and the right to push is with `api-deploy` (`tofu/identities.tf`);
- `tofu/secrets.tf` — the secret `api-admission-facts` with a replica only in the region and with no value: the deployment adds each version. The module does not delete it: `deletion_protection = true`, since the revision mounts one of its versions. Reading is for the service account `api-run`.

**The service, the jobs and the service accounts in the module** (R11):
- `tofu/api.tf` — the jobs `api-<name>` by the list `api_jobs`, `check`, `migrate`, `after` and `sweep` by default, and the service `api`. The container of the service and of each job is named `api`: `gcloud` takes an unnamed one for someone else's, and `--update-secrets` sets up a facts volume of its own in place of the module's (R11). The jobs appear when `api_image` names the first image from `images`, and the service after them, when `api_serving = true` as well: the first deployment runs the check and the migrations as jobs before the service takes its first request. The deployment changes their image, and for the service and the jobs of the part `check` also the version of the facts' secret in the volume; the rest is the module's. The service gets the pooler's strings of both databases as variables from their secrets, `API_DATABASE_URL` and `API_OPENFGA_DATABASE_URL`, and `API_APP_ORIGIN` — the origin of the default Hosting site; the service and the jobs of the part `check` have one facts volume, the module's `admission-facts`, and an `apply` after a deployment changes nothing (R11). The service, the jobs of the part `check` and those with `consent_forms`, by default `sweep`, get `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`, `consent-forms/`. Since a deployment has given the traffic to a revision by name, a change of the service's template by an `apply` makes a revision with no traffic, and reaches the traffic with the next deployment of `api` (R11). The jobs with `schedule` run through Cloud Scheduler and the service account `api-scheduler`, and only when the service exists: `sweep` every day at 09:00 UTC (R11);
- `tofu/identities.tf` — `api-run`, which reads the facts' secret, the service's secrets and the jobs' secrets, and `api-deploy`: a push to `images`, a new version of the facts' secret, the role `apiDeployer` on the service and the jobs — `bootstrap.sh` holds its rights (R11) — and the right to run them as `api-run`. On the project `api-run` has one role, `signInUsers` (section 3.3), and `api-deploy` none: its rights are on its own resources (R11). The Workload Identity Federation pool lets the deployment in only from the GitHub environment that the output `deploy_environment` names, by default `production` (R18);
- `tofu/secrets.tf` — the service's secrets, the pooler's strings `api-database-url` and `api-openfga-database-url` — at once, before the service, and the module does not delete them; the secrets that the jobs name: for `migrate`, the direct connection strings to both databases. All of them have no values, and a job that names a secret of the service reads that same secret.

**The first deployment of a copy** — by the order of R11 and SELF-HOSTING.md, "Deploying" (R25):
1. a pull request with the list — the image of `api` in `images`;
2. the four connection strings of the Neon databases — as secret versions, by the operator's hand in Cloud Shell, each with `sslmode=verify-full`, which `api` asks for, in place of Neon's `sslmode=require` (SELF-HOSTING.md, «Deploying»); a pull request with `api_image` — the jobs;
3. `Deploy` with **api** — `check` and `migrate`;
4. a pull request with `api_serving = true` — the service, the schedule of `sweep` and the release of `app`;
5. `Deploy` with **api** — the revision, all the traffic to it, and `after`;
6. the operator in Cloud Shell, with the binary of the release of `api` and the pooler's string from the secret — `api countries allow <country>` and `api invite` for each learner (R25).

What the platform's deployment costs to run is R25.

**Self-hosting** — the same directory `deploy/` with its own `deployment.json` and facts, the same checks and steps in its own project and its own private registry. The signed release files are the same for everyone (R105, R106 spec; Т-20).

### 3.3. Hosting of the build of `app` and domains

Firebase Hosting serves the build of `app` — the project's default site, the Blaze plan; the project's budget with an alert is `tofu/budget.tf` (R06): only this project, by its number, per month, with the free tier's credit taken off and no other, not the Free Trial's (R06; sources 7.3), emails at 50, 90 and 100 % of the amount — to the billing account's administrators and users, as a budget sends them by default, and to the operator's channel if it is named (sources 5.4). The amount and the currency are values of the deployment, and the billing account comes from the environment, `TF_VAR_billing_account`: it names who pays.

**The release** — the step of the deployment of `app` in section 3.2:
1. the release's folder — the new build's archive, the `assets/` of the build that is now released on Hosting, and `/deployment.json` from `deploy/production/deployment.json`. The rollout learns the released build from the Hosting release, not from the list on `main`: by the message of the live channel's release, `app <tag> <archive> <sha256>`, and after `keeping` the build whose `assets/` this release kept (R06). If the list names the very build that is released, the previous one is the one after `keeping`. The rollout checks its archive as it checks a new one: `release-verify` and sha256. No release — no previous build; another message — a refusal. A Hosting version is a full set of files, and without the previous build's `assets/` it would remove them. A file of the same path comes from the new build;
2. the rollout writes the version's configuration (R17):
   - `headers` — two sets of paths that do not overlap: outside `/assets/**`, `!/@(assets)/**` — `X-Content-Type-Options: nosniff`, HSTS, CSP by the archive's `csp.json` with `{api}` and `{authDomain}` from `deployment.json` and with `frame-ancestors 'none'`, and `Cache-Control: no-cache`; under `/assets/**` — `nosniff`, HSTS and `public, max-age=31536000, immutable`. Hosting matches headers against the request's path before rewrites, so they are not set by the path `index.html`. On `*.web.app` Hosting sets its own HSTS (sources 4.5);
   - `csp.json` — a table "directive → string of sources" with the places `{api}` and `{authDomain}`; the rollout refuses another form (R17);
   - the SPA rewrite to `index.html` — only outside `/assets/**`; `/deployment.json` is in every version, and Hosting rewrites only a path where there is no file;
   - without `Cross-Origin-Opener-Policy: same-origin`;
3. the release — one version: the files and the configuration together;
4. the check after the release — the bytes of `index.html`, the headers at `/`, at an SPA path and at a file in `/assets/`, `404` for an unknown file in `/assets/`, `/deployment.json` as `app` reads it, the bytes of `/NOTICE` and `/LICENSE` against the build's files, and `Cross-Origin-Opener-Policy: same-origin` nowhere (R17). It reads the site in rounds, 10 s apart for 120 s of waits, each read within 10 s, while Hosting's CDN still serves the build before, logs each round still wrong, and fails only when the last is (R17); `just deploy-app-check` reads it once.

Rollback — by R05, a pull request with the former block `app`; a rollback by a version in the Firebase console is not used.

**What Hosting does beyond its documentation**, seen on the project (R17):
- the release goes through as `hosting-publish` with its custom role `hostingPublisher`, though Firebase writes that custom roles do not work for Hosting (sources 4.5);
- production accepts `!/@(assets)/**`, and no explicit list of SPA paths is needed;
- an unknown file under `/assets/` gives 404 with Hosting's own page and the headers of the paths outside `/assets/**`;
- Hosting sets its own HSTS — `max-age=31556926; includeSubDomains; preload`;
- beyond the version Hosting sends `etag`, `last-modified`, `vary`, `alt-svc` and cache headers, and `Cross-Origin-Opener-Policy` nowhere;
- Hosting serves the reserved paths `/__/auth/*` — Firebase's sign-in pages — without the version's headers: without CSP and without `nosniff`.

**Logs:**

| Log | IP address | Where and how long |
|---|---|---|
| the logs of Firebase Hosting itself | yes | at Firebase, globally: "a few months", not configurable (П-9; privacy 4 spec) |
| the export of Hosting's logs to Cloud Logging | yes, `remoteIp` | not turned on: only a button in the Firebase console can turn it on, and if it is pressed, each sink excludes `resource.type="firebase_domain"` (R07) |

**Addresses and domains:**

| What | Address | When it changes |
|---|---|---|
| `app` | `<project>.web.app` | its own domain on Hosting — when one is bought |
| `api` | `*.run.app` of its service, CORS to the exact origin of `app` | when there is a domain of its own; how is to be decided then, Cloud Run's domain mapping is in Preview |
| `authDomain` of Firebase Auth | `<project>.firebaseapp.com` | does not change: `app` signs in with a window (R09 app) |
| the main domain and the widgets' domain | none | bought together after О-16, before the public launch (О-16, Т-17); the widgets are stage 4, the hosting of the bundles is Т-17 |

The default site answers at two addresses, `web.app` and `firebaseapp.com`, with the same content. The origin of `app` is only `web.app`: the CORS of `api` and `/deployment.json` name it. The authorized domains of the Firebase project (Т-19) are it and `firebaseapp.com`, as the module's full list (R16).

**The samples page of `canvas`** does not move to the hosting yet. It will move as a separate site of the project with its own origin when the author decides so — Google is a processor for Hosting (R128 spec): the sign-out of `app` erases the storage of its origin, and Firebase's logs would then also get the IP addresses of the devices on which children's samples are made (R25 spec).

**In the module** (R12):
- `tofu/firebase.tf` — Firebase in the project and the Hosting site with the project's ID, `deletion_policy = "PREVENT"`; the Web App `app`, also `PREVENT`, and the output `app_sign_in` — the block `signIn` for `/deployment.json`: `service`, `apiKey`, `authDomain`, `projectId`, `appId` (R17). The author writes the file, and the review of the pull request sees it (R05);
- `tofu/identities.tf` — `hosting-publish`: the GitHub environment that the output `hosting_environment` names, by default `production-hosting`; on the project the role `hostingPublisher`, Firebase Hosting Admin without creating and deleting sites and without `resourcemanager.projects.list`, which a project's role does not hold — `bootstrap.sh` creates and holds it (R12) —, and nothing more: the release reads no API keys (R12). This service account does not reach `api`, the configuration or the sign-in settings;
- `tofu/sign_in.tf` — sign-in in production (R16): Identity Platform, `google_identity_platform_config`, and its API, `identitytoolkit.googleapis.com`. The authorized domains are exactly `<project>.firebaseapp.com` and `<project>.web.app`, without `localhost`. Sign-in by email, sign-in by phone and anonymous sign-in are turned off, the activity log is turned off, there are no tenants and no second factor, and only `api` deletes a user, `disabled_user_deletion = true`. The move to Identity Platform cannot be undone, and `destroy` only forgets the resource;
- `tofu/identities.tf` — `api-run` has on the project the role `signInUsers` from `bootstrap.sh`: `firebaseauth.users.get`, `.update` and `.delete`, without the right to change the sign-in settings; `tofu/api.tf` — `API_FIREBASE_PROJECT_ID` on the service and on each job.

**Sign-in** — Firebase Auth with Identity Platform, only through the Google window (R03 api; R09 app; R16):

| What | Who sets it | Where it is kept |
|---|---|---|
| Identity Platform and its settings, the authorized domains | the module, by the configuration's service account | `tofu/sign_in.tf` |
| sign-in through Google, the OAuth client, the consent screen | the operator, once, after the first `apply` | in the project; the client's secret is only with Google |
| the rights of `api` on the sign-in users | `bootstrap.sh` creates the role, the module grants it | `tofu/bootstrap.sh`, `tofu/identities.tf` |

The price is by monthly active users: sign-in through Google is free up to 50,000, then $0.0055 for each (sources 4.7).

**The operator's step: sign-in through Google.** It cannot be done by a program: the API no longer sets up an OAuth client and a consent screen, and the Google provider in the module would keep the client's secret in the state (R16). After the first `apply`, once the module has moved the project to Identity Platform:
1. the project's Firebase console → Authentication → Sign-in method → Add new provider → Google → Enable. The console may create the OAuth client itself, "auto created by Google Service", and ask for no ID or secret (R16);
2. the project's public name — "NovaTrail"; the support email — the one users will see on the consent screen, the operator's address. If the console asks for a Web client ID and a Web client secret, create a client `Web application` in Google Cloud → APIs & Services → Credentials, with the Authorized redirect URI `https://<project>.firebaseapp.com/__/auth/handler` — the sign-in handler on `authDomain` (sources 4.7) —, and paste the secret only into this form: it goes neither into the repository, nor into variables, nor into GitHub's secrets;
3. Google Auth Platform: Audience — External and In production: in the mode Testing only the named test users sign in, no more than 100 (sources 4.7). Scopes — only the default ones, email, profile and openid; they need no app verification. The user will see the name and the logo after brand verification, and before it the address `<project>.firebaseapp.com`; brand verification comes with a domain of its own, after О-16. The API does not read the Audience: the operator checks it in the console;
4. do not touch the authorized domains in the console: the module holds them, and the next `apply` removes one added by hand;
5. `tofu plan` after the step shows no changes: the step changes the sign-in provider, not the settings the module holds.

A learner signs in through the window with their own Google account, not only with the operator's (R16). Self-hosting does the same step in its own project.

### 3.4. Logs and traces

The platform's logs are without direct identifiers and IP addresses (privacy 4 spec). How `infra` holds to this is R07.

**Sinks and filters:**

| Sink | Where to | Exclusion filter |
|---|---|---|
| `_Default` | its own log bucket in `us-east4`, 30 days (R04) | `LOG_ID("run.googleapis.com/requests")` — Cloud Run's request logs; and also Data Access but the reads of Secret Manager, the requests of Identity Platform and the requests of Hosting — the rows below |
| `_Required` | the bucket `_Required` in `global`, 400 days | does not change; gets no request logs |
| any sink the project sets up | — | the same as `_Default`'s |

The filter applies to an entry that the Logging API or the Telemetry API has already accepted: the IP address reaches Google as a processor, but is not stored in the bucket. The log's name in the filter is checked on the project: the bucket holds not one entry with `httpRequest` — only Cloud Run's `stdout`, `stderr` and `varlog/system` (R07).

**The inventory of logs and traces:**

| What | What is in it | Where and how long |
|---|---|---|
| Cloud Run's request logs, of the service `api` | `httpRequest`: the client's IP address, user agent | excluded — not stored |
| the logs of the container `api` and of its jobs | events of `api` without identifiers and addresses; for the jobs, counters (R26 api) | the bucket in `us-east4`, 30 days |
| Cloud Run's system logs | platform events about revisions and jobs | the bucket in `us-east4`, 30 days |
| Cloud Scheduler's log of its attempts, `cloudscheduler.googleapis.com/executions` | for each call of a job by the clock, `AttemptStarted` and `AttemptFinished`: the job, the address of its run, the target type, the scheduled time, Google's text `debugInfo` and the HTTP status; no address or identifier of a person (R07) | the bucket in `us-east4`, 30 days |
| Admin Activity | `callerIp` and the caller's email — of the operator and of CI when they edit resources. There are no Identity Platform entries from learners: nobody calls `SignUp` in the project, and the sign-in through the Google window, which creates a user, leaves no entry; the entries of other services are not gone through (R128 spec) | `_Required`, `global`, 400 days (Д3); cannot be excluded |
| System Event | Google's own actions with the project's resources; among them each run of a job, `/Jobs.RunJob`, which names no service account of the project | `_Required`, `global`, 400 days |
| Policy Denied | `callerIp` and the email of whoever a policy refused | the bucket in `us-east4`, 30 days |
| Data Access audit | holds `callerIp` and the caller's email | on for Secret Manager's reads alone, `DATA_READ` — `AccessSecretVersion` and `GetSecretVersion` —, which the sinks let through: the bucket in `us-east4`, 30 days; the rest not turned on, and excluded in each sink (R07) |
| the activity log of Identity Platform | would hold every sign-in request | turned off by the module, `monitoring.request_logging` (R16), and excluded in each sink (R07) |
| the export of Firebase Hosting's logs | would hold `remoteIp` | not turned on (R06), and excluded in each sink (R07) |
| the logs of Firebase Auth and Firebase Hosting at Firebase itself | IP addresses | at Firebase: Auth "a few weeks", Hosting "a few months" (П-9) |
| traces | Cloud Run itself, on a part of the requests | `_Trace` in `us-east4`; Cloud Trace API cannot be turned off while Cloud Scheduler needs it (R07); the attributes with the first trace: there has been none (Д17) |

Cloud Run jobs have no request logs: only services write them.

**For investigating failures:**
- the log of `api` — the method, the code, the cause of a refusal and the time of each call, without the body, the headers and the address (architecture 3.9 api);
- Cloud Run's built-in metrics in Cloud Monitoring — the number of requests, latencies, instances;
- Error Reporting — by the logs of `api` that are stored.

The project sets up no log-based metrics of its own, where the address would become a label: they are counted on excluded entries too. The alerts are on built-in metrics, `tofu/alerts.tf`: load — requests to `api` per minute above `load_alert_per_minute`, 300 by default —, and errors — responses of class 5xx per minute above `error_alert_per_minute`, 1 by default —, both averaged over five minutes, by `run.googleapis.com/request_count`; the third — a scheduled run of a job that failed, by `run.googleapis.com/job/completed_execution_count` with `result` not `succeeded` (R07); the fourth — a job by the clock with no completed execution in the last 25 hours, by the same metric with any `result`, summed over 90 000 seconds, the longest window a condition may roll, each job in a condition of its own, with no data taken as the condition met: a day with no run writes no point (R07; sources 3.14). The third and the fourth exist only while there are the service and jobs with `schedule`. The fourth sees a run that did not start, whatever the cause — the rights of `api-scheduler`, the job's address, a paused schedule, Cloud Scheduler itself —, and it holds only while a job by the clock runs every day and within the hour: `api_jobs` refuses a schedule whose day of the month, month and day of the week are not all `*`, and a timeout over 3000s. A job made, renamed or added has no data before its first run, and the fourth may mail before it. The email goes to the operator, whose address comes from the environment, `TF_VAR_operator_email`; without an address there is neither a channel nor alerts. The same address is the project's Essential Contact for the category Security, `tofu/contacts.tf`: the fallback of Security is the Organization Administrator, whom a project with no organization lacks, so the documentation names no recipient there, and the other categories fall back to the owners and the billing account's administrators, whom it has (R27; sources 5.7). The first two write when the condition began and when it ended, the third and the fourth only when it began: Cloud Monitoring also closes an incident with no data, and a mail of that would read as a run. The email's text leads to Cloud Run's metrics, and never to the request logs: there are none. For the first two it leads to the log of `api`, for the third to the job's runs and the log of `api`, and for the fourth to Cloud Scheduler's log of its attempts, to `gcloud scheduler jobs describe`, which shows whether the schedule is enabled, and to the job's runs. Cloud Run's metrics are free, and Google charges for the alerts themselves from September 1, 2027: $0.35 a month for each metric in a condition — here one in each of the first three and one for each job by the clock in the fourth — and $0.50 per million points that a condition's query returns (sources 5.4).

**Traces:** the platform has none of its own, and Cloud Run traces a part of the requests itself. Cloud Trace API is enabled: Google enables it in a new project, and Cloud Scheduler, which depends on it, does not let it be turned off (R07). The place of `_Trace` — `us-east4` — is set before any trace (R04).

**In the module** — `tofu/logging.tf`:
- the bucket `default-<region>`, `log_retention_days` — 30 by default, from 1 to 3650; `deletion_policy = "PREVENT"`: the module does not delete the bucket — neither by `destroy` nor by a change of region —, or else `_Default`, which `destroy` does not touch, would write to a bucket being deleted;
- the module takes over the sink `_Default`: the provider updates a sink that already exists, and on deletion does not touch `_Default`. The former filter word for word, the destination the region's bucket, and the exclusions as blocks `exclusions` of the sink itself: `cloud-run-request-logs`, `data-access-audit`, `identity-platform-requests` and `firebase-hosting-requests`;
- the project's sinks are listed in one list, `local.sinks`, and each gets the same exclusions; a test holds each sink of this list, and `tf-check` lets no sink or exclusion declared outside it through;
- the place of `_Trace` — `google_observability_project_settings` with the region's `default_storage_location`: the provider sets the setting through PATCH, and a second `apply` repeats it harmlessly, while the bucket `_Trace` it creates through POST, which refuses if the bucket already exists, and it cannot delete it (R04; sources 2.2);
- Data Access audit and the activity log of Identity Platform are off by Google's default, the module does not turn them on, and the sink excludes them (R07). The activity log is besides turned off explicitly in `tofu/sign_in.tf` (R16). The one exception is Secret Manager's reads: `google_project_iam_audit_config.secret_reads` turns on `DATA_READ` for `secretmanager.googleapis.com`, authoritative for that service alone, and the exclusion `data-access-audit` lets through only those reads of that service, by their method names, `AccessSecretVersion` and `GetSecretVersion` — a list or a policy read, which a copy's organization may turn on beside them, stays excluded; a test holds both to `local.audited_reads` (R07; sources 2.6).

**Checked on the project:**
- that nobody calls `SignUp` in the project, and that Admin Activity has no Identity Platform entries from learners: it is checked again when `api` brings a new call of Identity Toolkit (R128 spec; privacy 4 spec);
- the values of the label `result` — `succeeded` and `failed`, as the alert expects (R07);
- a run by the clock: `api-scheduler` calls `sweep` at 09:00 UTC, the execution passes, and `completed_execution_count` writes `succeeded`; Cloud Scheduler's log of its attempts is as in the inventory above; Cloud Scheduler has no metric of its own, and a failed call is not retried: `retryConfig` is empty (R07);
- the window of 25 hours does not open the alert between two runs on time, through a morning when the last point is nearly 24 hours old (sources 3.14; R07);
- the reads of the secrets: the `apply` writes the audit config under the condition of `infra-config`'s `projectIamAdmin`, and the bucket of `us-east4` holds entries of `AccessSecretVersion` of `api-run`, of the service's secrets, `api-anthropic-key` among them, each with `callerIp` `private` and about 1.8 KB (sources 7.1 for the price of logs); no entry of another service passes `data-access-audit`, and no entry of `api-deploy` or `infra-config` was among them, though they deployed and applied (R07; Д29).

**Not checked:**
- the attributes of the traces Cloud Run writes itself, until the first trace (Д17);
- what Cloud Scheduler writes for a failed attempt: none has failed yet; the alert on a run that did not happen does not read it (R07);
- that a missed day opens the alert on a run that did not happen: no run was missed, and the schedule was not paused, since a day's pause would hold back the deletions `sweep` finishes (R07; Д21);
- what an entry of a read by the operator, by CI or by an eval job holds, until one is in the bucket (R07; Д29).

### 3.5. Self-hosting and the local run

Self-hosting is a copy of the platform that an operator deploys on their own side (product 3 spec; architecture 3.11 spec). For it:
- **the same release files:** the operator builds a service's image on their own side from the same binary and by the same `Dockerfile`, after `release-verify`, and keeps it in their own private registry (R105, R106 spec);
- **the same directory `deploy/`** — its own list, its own values of `/deployment.json` and its own facts file; the rung, by default `full` (R05; section 3.8);
- **the same checks and steps of the deployment** — the fork's workflow, and without GitHub Actions the same recipes by hand, in its own project (R05; R21);
- **the hosting of the build of `app`** — in code, Firebase Hosting on the copy's project. Another hosting is outside the code and the guide: with its own headers it suits, and without them the protection is weaker (R06; Т-17);
- **the logs** — the same exclusion of the request logs and the same rules for metrics and traces (R07);
- **sign-in** — the same module and the same operator's step "Sign-in through Google" (R16; section 3.3);
- **the region** — the copy has its own: R109 spec and R04 are about the platform.

There is no cloud in the code other than Google Cloud. `bootstrap.sh` and the root module's variables take the copy's values from its `production.auto.tfvars` and `backend.hcl`, and the module puts the copy's own Firebase project on the copy's project. The operator's guide is [SELF-HOSTING.md](../SELF-HOSTING.md), in English: the main path is a fork with GitHub Actions, and without them the same recipes with the operator's rights, without the constraints of `infra-config` (R21).

**The local run** (R22) — the platform from source on one machine: `api` and `app` each run in their own devcontainer and by their own recipes, and `infra` gives only a description — "Running the whole platform on one machine" [SELF-HOSTING.md](../SELF-HOSTING.md#12-running-the-whole-platform-on-one-machine). `infra` gives it no Firebase project, compose, emulators or list; why is R22. `api` in its `/deployment.json` is the origin of `app` itself on loopback, `http://127.0.0.1:<app port>`, by the rule `deployment.loopback` (R85 spec), and the proxy of the server of `app` leads the paths of `api`: the lower layer of the build's CSP does not let in another origin over `http` (R22). A Firebase project is needed — the format requires `signIn` and does not know an emulator's fields —, and it is the dev project of `api` (the row "sign-in service" of table 3.12 spec). The container of `app` is also on the network `novatrail-api`, and the proxy goes to the container `api` in it by its name there, `http://api:8080`, the alias every devcontainer takes from the template of `spec` (R21 spec; R30). The port of `app` is 5173, fixed for both servers, and VS Code forwards it to the same 5173 of the host. `API_APP_ORIGIN` of `api` is the same origin, `http://127.0.0.1:5173`, as `docs/build.md` of `api` and architecture 3.7 app have it (R22).

**What a copy sets itself, and what is shared.** The inventory is by the code of the module, `bootstrap.sh`, the checks and the deployment. The tests on a copy's values are `tofu/tests/copy.tftest.hcl`, the copy test in `tofu/tests/bootstrap.test.mjs`, `tools/deploy/test/api.test.mjs` and `app.test.mjs`. They also hold that neither the project ID `novatrail`, nor the region `us-east4`, nor the numbers of `altnovatrail` reach a copy's resources and calls. The name "NovaTrail" reaches it on purpose: it names the project that `bootstrap.sh` makes, and the label of Hosting's versions, `novatrail-infra` — the row "names" of the table.

| What | Where a copy gets it | Own or shared |
|---|---|---|
| the project, the region, the budget and the currency | `production.auto.tfvars` | own |
| the state bucket and the prefix | `backend.hcl` | own |
| the CI service account and the pool's provider for the workflow | `tofu/ci.env`, the two lines that `bootstrap.sh` prints | own |
| the billing account, the operator's address | `TF_VAR_billing_account`, `TF_VAR_operator_email` | own |
| the CI pool, the repository and its numbers | `workload_identity_pool_id`, `github_oidc_subject_prefix` | own |
| the GitHub environments of the deployment and of the publishing | `deploy_environment`, `hosting_environment`, and the workflow takes them from the module's outputs; `production-config` is a constant | own (R18) |
| the Hosting site and the sign-in domains | the project ID: `<project>.web.app`, `<project>.firebaseapp.com`; `web.app` is also the origin of `app` in the service's `API_APP_ORIGIN` | own |
| the image of `api` and the service | `api_image` — an image from the copy's registry, `api_serving` | own |
| the databases `api` and `openfga` | its own Neon project; four connection strings as versions of the secrets `api-migrate-database-url`, `api-migrate-openfga-database-url`, `api-database-url` and `api-openfga-database-url`, by the operator's hand | own |
| the countries and the invite codes | `api countries allow` and `api invite` — by the operator's hand, with the release's binary (R25) | own |
| the settings with defaults | `api_service_name` and `api_jobs` — the names of the service, its service accounts, the jobs and their secrets come from them; the periods of the logs and the images, the alerts' thresholds, the service's size and limits — `tofu/variables.tf` | own, and the defaults shared |
| `api` and `signIn` in `/deployment.json` | the outputs `api_origin` — the address of the copy's service — and `app_sign_in` of the copy's module | own |
| eval | `eval_github_subject_prefixes`, empty by default: no secrets, no pool | the platform's only |
| the operator's bucket and the bucket of the scans, and who holds them | `operator_bucket` and `consent_forms_bucket` in `production.auto.tfvars`; the addresses of the organizers and of the operator in `BOOTSTRAP_MEASURE_ORGANIZER`, `BOOTSTRAP_EVAL_SET_ORGANIZER` and `BOOTSTRAP_OPERATOR`, each `none` for no one (R28) | own |
| the list, `/deployment.json`, the facts, the copy's legal texts | the copy's directory `deploy/`; the texts in `deploy/production/legal/`, laid over the image of `api` (R33) | own (Т-20; R96 spec) |
| the release files of `api` and `app` | the releases of `altnovatrail`, `release-verify` | shared (R105, R106 spec) |
| the format of `/deployment.json` | the submodule's `spec/deployment/` | shared (R85 spec) |
| names | the constants of the module and of `bootstrap.sh`: `infra-config`, `hosting-publish`, `upload-measure`, `upload-eval-set`, the prefixes of the buckets, the secrets `api-admission-facts`, `api-database-url` and `api-openfga-database-url`, the registry `images`, the container `api` and the facts volume `admission-facts` at the path `/etc/api/admission`, the path of a copy's texts in its image `/etc/api/legal`, the custom roles; the project's name "NovaTrail" and the label `novatrail-infra`. | shared: they are inside the copy's project |
| CI's sign-in | GitHub's Workload Identity Federation; without GitHub Actions, the same recipes by hand | shared |

### 3.6. The tool: OpenTofu

OpenTofu, the open fork of Terraform, at an exact version, describes the infrastructure: the code is in HCL on the model of `infra/` of canvas-api, and the tool and the commands are `tofu` (R11 spec). Sources: sources 5.1 and 5.2.

- **Why not Terraform:** since version 1.6.0 it comes out under BUSL 1.1, and R12 spec admits free terms only for a tool without which the platform can be deployed. Terraform 1.5.7, the last under MPL 2.0, has no generally available `terraform test` and no `mock_provider`, and is no longer developed.
- **What it rests on:** OpenTofu is under MPL 2.0, and the sha256 sums of its archives `linux_amd64` and `linux_arm64` and the signature of the sums file are published; the providers `hashicorp/google` and `hashicorp/google-beta` are in the OpenTofu registry, under MPL 2.0; `tofu test` supports `mock_provider`, `override_resource` and `command = plan`, on which the tests of canvas-api stand (sources 5.1, 5.2).
- **What changes against canvas-api:** `tofu` and `tofu test` instead of `terraform`; the providers come from the OpenTofu registry, and the sums of `.terraform.lock.hcl` are its; the tool is in the devcontainer's stage `toolchain` by the version's `ARG` and the sha256 sums (R34 spec; R09), not on the runner, and CI calls it through `spec/tools/toolchain/toolchain.sh` (R30 spec). The module's HCL code and the tests carry over.
- **Installation** (R09): the stage `toolchain`, at the version of the `ARG` `OPENTOFU_VERSION` of `.devcontainer/Dockerfile`; the archive is checked against its sum before unpacking, and the signature of the sums file is checked with `gpg` by hand at each raise of the version. The CI job `OpenTofu` checks `tofu version -json` against the `ARG`.
- **The root module** (R10): `tofu/` — `required_version` and the providers `google` and `google-beta` at exact versions in `tofu/versions.tf`, a lock file with the hashes of all platforms of their release, a partial backend `gcs`, the platform's values in `tofu/production.auto.tfvars`, the APIs by R04–R07 and R27; the module does not enable Cloud Trace, but Google enables it, and it stays (R07). The tests are `tofu test` on `mock_provider` with `command = plan`, as at canvas-api, but for the runs of `copy.tftest.hcl`, `firebase.tftest.hcl` and `eval.tftest.hcl` that read what only an apply of the mock makes, with `command = apply`; they run under `tofu`. Dependabot raises the providers, the ecosystem `opentofu`, in one group; OpenTofu is raised by hand, by R09.
- **The one-time step** (R13): `tofu/bootstrap.sh` creates what the configuration signs in through — the project, the state bucket, the pool and the provider `github`, which admits only the tokens of `infra` by numeric IDs, the service account `infra-config` for the jobs of the environment `production-config`, and the module's custom roles; and, with the operator's rights and outside the module, the operator's two buckets with their custom roles, their upload service accounts and each one's whole policy (R28; section 3.7). If `production.auto.tfvars` names eval repositories, the script also makes the pool `github-eval` with a provider by the condition of R120 spec — the job of the environment `eval` of these repositories, not Dependabot; `infra-config` has no rights on pools, because IAM conditions do not narrow pools (R20). It reads the values from `production.auto.tfvars` and `backend.hcl` in `tofu/`, and the operator runs it. The tests are on a stub `gcloud`, the check of its condition against the module's roles in `tofu test`, and `_tf-roles` in `tf-check`.
- **ShellCheck** (R09): in the stage `toolchain`, by the `ARG` `SHELLCHECK_VERSION` and sha256 sums; the job `OpenTofu` runs it on `bootstrap.sh`, `tools/deploy/*.sh` and `tools/ci/*.sh`.
- **actionlint** (R09): in the stage `toolchain`, by the `ARG` `ACTIONLINT_VERSION` and sha256 sums; the job `OpenTofu` runs it on `.github/workflows` with the stage's ShellCheck.
- **License:** OpenTofu and both providers — MPL 2.0, the named exceptions of R09 and R10, ShellCheck — GPL-3.0, the named exception of R09 (R12 spec), and actionlint — MIT.
- **Not checked:** whether a pull request of Dependabot `opentofu` rebuilds the lock file for all platforms, as its code promises.

### 3.7. The operator's bucket

The private Cloud Storage bucket of R125 spec: the measurement organizer and the eval-set organizer get the files of the samples page and the scans of their forms into it by an upload link. Beside it is a bucket of its own for the scans of the parents' consent forms that `api` puts there from `app` (R116, R124–R126, R136 spec). What was decided and why is R28, with R13; the sources are sources 7.2 and 10.1–10.9. `tofu/bootstrap.sh` makes the buckets and their access, the module names the scans' bucket and `api`'s prefix to `api`, and `tools/organizer/organizer.mjs` is the organizer's tool.

**Who makes them.** `tofu/bootstrap.sh`, with the operator's rights, as the pools and the custom roles (R13): the two buckets and their settings, the lifecycle rules, the custom roles, the upload service accounts and the whole IAM policy of each bucket. The module grants nothing in them and only names the scans' bucket and the prefix `consent-forms/` to the service `api`, to `sweep` and to `check`, as `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`; a test holds the prefix to the one of the script's condition (R11; R28). A rerun of the script brings the settings, the rules and the policies back where they have drifted, as for `infra-config`.

**What CI can do all the same** (R28; R125 spec):
- `roles/firebase.admin` of `infra-config` holds `storage.buckets.*` and `storage.objects.*` on the project (sources 10.6): CI reads, writes and erases any object of either bucket, and can change its settings, rules and policy;
- through `roles/run.admin` and `roles/iam.serviceAccountUser` CI can run a Cloud Run job as any service account of the project — `api-run`, an upload service account;
- a change of a bucket's settings or policy is Admin Activity in `_Required`; a read of an object is Data Access, which is off, so no log shows it.

"Without CI" of R125 spec therefore holds for the agents, not for CI, and R125 spec accepts it while only adults' files lie there: before the first child both buckets move to a project of the operator's own, where CI holds nothing, and `api` writes the scans there by its variables (Д23). Until then CI's door is the environment `production-config`, where only `main` runs, after a review (R13, R18).

**The values.**
- the buckets' names — `operator_bucket` and `consent_forms_bucket` in `tofu/production.auto.tfvars`, `<project>-operator` and `<project>-consent-forms` for `novatrail`: the script and the module read them from the same place. The module takes both as variables, required, of the form the script takes and different, so that a plan reads the file without a warning; it uses only the scans' bucket, which it names to `api`;
- the addresses of the people — from the environment, never from a file, each from a variable of its own: the measurement organizer `BOOTSTRAP_MEASURE_ORGANIZER`, the eval-set organizer `BOOTSTRAP_EVAL_SET_ORGANIZER`, the operator `BOOTSTRAP_OPERATOR`. A variable that is not set is a refusal before the first call of `gcloud`: a rerun from a shell that lacks one would otherwise take a person's access away. The value `none` means no binding for that person. The alerts' `TF_VAR_operator_email` is not reused: it may be a list, not a Google account. On `novatrail` all three are the author (R139 spec).

**The settings** of both buckets (sources 10.2, 10.3):

| Setting | Value | Why |
|---|---|---|
| place | `us-east4`, a region, class Standard | R04; R125 spec |
| access | uniform bucket-level access | IAM conditions on names require it; no ACLs |
| public access prevention | `enforced` | nobody makes an object public, by mistake or otherwise |
| soft delete | off, duration 0 | an erased file is gone at once, as R126 spec says of a file that failed the check, and the periods are not a week longer |
| object versions | off | an old version would be a copy outside every period |
| CORS | none | the upload is an HTML form, a navigation, not a script's request |

**The prefixes.** In `<project>-operator`, a prefix per purpose, and in it a prefix per kind; an upload lands under a folder of the session, a random ID that the organizer's tool gives, and each file under a random name that the page fixes — the name of the adult's file is not used, as it may hold a name. Each organizer lists the whole bucket (sources 10.2), so no name holds a person's name or a writer code.

| Prefix | What lies there | Whose |
|---|---|---|
| `measure/samples/<session>/` | the files of a measurement session (R124 spec) | measurement organizer |
| `measure/forms/<session>/` | the scan of the measurement form | measurement organizer |
| `measure/records/` | the organizer's record of a session | measurement organizer |
| `measure/reports/` | the runner's reports that name the samples (R95 spec) | measurement organizer |
| `child/samples/<session>/`, `child/forms/<session>/`, `child/records/`, `child/reports/` | the same for children's samples, with the parent's form and the band of grades in the record (R124, R125 spec) | measurement organizer |
| `eval-set/samples/<session>/` | the volunteer's files before they enter `modules` (R126 spec) | eval-set organizer |
| `eval-set/forms/<session>/` | the scan of the volunteer's form and, beside it, the record of the form | eval-set organizer |
| `eval-set/contributed-forms/<session>/` | a form by which a sample was contributed, moved here with its record | eval-set organizer |

`<project>-consent-forms` has one prefix, `consent-forms/`: the scans, `<consent ID>-<random suffix>` (sources 10.5), which only the operator lists.

**Who has access** — each binding on its bucket, under an IAM condition `resource.name.startsWith('projects/_/buckets/<bucket>/objects/<prefix>')` where it has one:

| Bucket | Who | Role | Condition |
|---|---|---|---|
| operator | measurement organizer | `roles/storage.objectUser` — read, create, erase, update, rewrite | `measure/` or `child/` |
| operator | eval-set organizer | `roles/storage.objectUser` | `eval-set/` |
| operator | both organizers | the custom role `operatorBucketLister` — `storage.objects.list` | none: listing has no condition by name |
| operator | `upload-measure` | the custom role `bucketUploader` — `storage.objects.create` | `measure/samples/`, `measure/forms/`, `child/samples/` or `child/forms/` |
| operator | `upload-eval-set` | `bucketUploader` | `eval-set/samples/` or `eval-set/forms/` |
| consent forms | operator | `roles/storage.objectViewer` — read and list | none |
| consent forms | `api-run` | the custom role `consentFormsWriter` — `storage.objects.create` and `storage.objects.delete` | `consent-forms/` |
| both | the project's owners, `projectOwner:<project>` | `roles/storage.legacyBucketOwner` — the bucket, its settings and policy; list, create and erase objects; no read | none |

The owners' binding is one of those Cloud Storage gives a new bucket, and the only one the script keeps: the role Owner holds no `storage.buckets.get`, `update`, `getIamPolicy` or `setIamPolicy` of its own, only through it (sources 10.9), so a policy without it shuts out the operator who runs the script. The owners may grant themselves any read through it, as they may anything on the project. The other bindings of a new bucket — `legacyBucketOwner` and `legacyObjectOwner` of the project's editors, `legacyObjectOwner` of its owners, `legacyBucketReader` and `legacyObjectReader` of its viewers — the script takes back (R28).

Beyond the buckets: the measurement organizer holds `roles/iam.serviceAccountTokenCreator` on `upload-measure` alone, the eval-set organizer on `upload-eval-set` alone. The policy of each upload service account and of each bucket holds only what the script names: anything else it takes back at each run, and with it any role an upload service account holds on the project, since whoever signs as it may act as it in full. A bucket of the name that stands outside the project, or in the project but outside its region, stops the script: names are global, and a bucket's place does not change, so its files move by hand to one made anew. The binding of `api-run` exists only once the module has made `api-run`; without it the script makes the rest and says so, and the operator runs it again after the first `apply` of a new copy. `api` needs no more: it puts each scan under a new name and erases by a name from its database, and an insert that overwrites nothing needs no `storage.objects.delete` (sources 10.2, 10.5).

**The upload link** (sources 10.1). A V4 POST policy, signed by IAM's `signBlob` as the organizer's upload service account, with no key: without a key of the service account a signature is valid at most 12 hours, so the policy expires no later than 12 hours from the session (R125, R126 spec). The organizer's tool, `tools/organizer/organizer.mjs` (R28; sources 10.8):
- runs where `gcloud` is signed in as the organizer — Cloud Shell or their own machine with Linux or macOS: the devcontainer has no `gcloud`, and on Windows `gcloud` is `gcloud.cmd`, which Node does not run without a shell. It runs `gcloud` by an absolute path, as the checks run `git`: `ORGANIZER_GCLOUD`, or the first there of the places the CLI installs it, never by `PATH`. It is Node.js alone, with no package of `tools/package.json`, and reads the project and the operator's bucket from `tofu/production.auto.tfvars` by `tfvarsValue` of `tools/deploy-check/setup.mjs`, which imports nothing;
- `link <purpose>` gives the session its random ID, 16 hex characters, or takes one already given with `--session`, for a page that expired, and makes one self-contained HTML page with a form per file: `--samples` forms for the sample files under `<purpose>/samples/<session>/`, and three for the scan of the form under `<purpose>/forms/<session>/`, one a type, since a policy carries one condition per field. Each form has its random object name with the type's extension, its `content-length-range` from 1 byte and its `Content-Type` by an exact condition, and its policy names the folder by `starts-with $key`:

  | File | `Content-Type` | Up to | Why |
  |---|---|---|---|
  | a sample | `application/json` | 16 MiB | the samples page saves `<id>.json` and bounds no size; its synthetic samples weigh up to 0.9 MB |
  | the scan of the form | `application/pdf`, `image/jpeg` or `image/png` | 10 MiB | as `api` takes a scan (sources 10.5) |
- the policy is valid `--hours`, 12 if not given and never more; it carries a condition for each field the form sends — the bucket, `success_action_status` 201, so that the answer names the object, the algorithm `GOOG4-RSA-SHA256`, the credential `<upload service account>/<date>/auto/storage/goog4_request` and the date — and its expiration in the extended format, as Google's library writes them;
- signs the base64 of each policy with `gcloud iam service-accounts sign-blob --iam-account=<upload service account>`, which writes the signature's raw bytes; the form carries it in hex. `measure` and `child` are signed as `upload-measure`, `eval-set` as `upload-eval-set`;
- the page holds no script and loads nothing; its Content-Security-Policy lets its forms post to `https://storage.googleapis.com` alone, each into a new tab. The tool writes it where it runs, and `.gitignore` keeps `upload-*.html` out of a commit: whoever holds a page may upload by it until it expires;
- `time <object> --date=<day>` sets the Custom-Time of the lifecycle table below by the object's prefix: of a form of `measure/` or `child/` the day plus 730 days, of a record, a report or what lies in `eval-set/forms/` the day. It reads every object before it changes any, and refuses — so that nothing changes — an object whose rule reads none, a Custom-Time earlier than the one there, one its rule has reached already, which a year mistyped would give and the rule would erase for good, and a form whose samples were withdrawn: a new session takes a new form (R125 spec);
- `withdraw <form> --erased=<day>` rewrites a form of `measure/` or `child/` with the day: `gcloud` rewrites an object only by a copy, which takes `--custom-time` in place of the source's, and copies none onto itself, so the form moves to `<name>.rewrite` and back, each with `--custom-time` and the metadata `withdrawn` with the day, by which `time` knows it. It refuses a day before the form arrived;
- `contribute <session>` moves `eval-set/forms/<session>/`, the form and its record, to `eval-set/contributed-forms/<session>/`, each object to its own name;
- `untimed` lists the forms, records and reports of `measure/` and `child/` that have no Custom-Time, prefix by prefix, not the samples; in `eval-set/forms/` the rule by `age` erases them anyway.

The organizer gives the page to the adult, who opens it in a browser and sends the files. Since an upload service account cannot overwrite, a second sending of the same form fails instead of replacing the file. A screen of the samples page of `canvas` that takes the policy from the fragment of a link would replace the page; it waits for the samples page to move to Hosting, since a page opened from a file goes to no network (R125 spec; R128 spec).

**The lifecycle** of `<project>-operator` (sources 10.3). Two years are at least 730 days and five years at most 1827; the link adds up to half a day to the session; Google bounds no lag of a rule's action. An `age` counts from the object's creation, and a rewrite creates the object anew, so what the organizer may rewrite is erased by its Custom-Time:

| Prefixes | Rule | Custom-Time set by the organizer | Period it keeps |
|---|---|---|---|
| `measure/samples/`, `child/samples/` | `age` 728 | — | 2 years from the session (R124, R125 spec); nobody rewrites a sample |
| `measure/records/`, `child/records/`, `measure/reports/`, `child/reports/` | `daysSinceCustomTime` 728 | the session of the record, or of the earliest sample the report names | erased with the samples (R124 spec) |
| `measure/forms/`, `child/forms/` | `daysSinceCustomTime` 1827 | the session plus 730 days, of the last session under the form; moved forward by a new session; on a withdrawal the form is rewritten with the day of the erasure | 5 years after its samples are erased (R124, R125 spec) |
| `eval-set/forms/` | `age` 364, and `daysSinceCustomTime` 364: two rules, and either erases | the signature, on the record beside the form | 12 months from the signature, when no sample was contributed (R126 spec) |
| `eval-set/contributed-forms/` | none | — | as long as a sample is published (R126 spec) |
| `eval-set/samples/` | `age` 364 | — | until the organizer enters it into `modules` and erases its copy, or erases it at once when it fails the check; one not entered — with its form or 12 months from the upload, whichever comes first (R126 spec); the organizer enters a file or erases it, never rewrites or moves it, which would restart its `age` |

A Custom-Time cannot decrease, but a rewrite of the object resets it. A form without one is never erased by the rule, so the tool sets it and lists the forms without it. `<project>-consent-forms` has no rule: the period of a scan is the consent and 5 years, and `sweep` erases it (R116, R136 spec).

**Logs.** Data Access audit of Cloud Storage is off and every sink excludes it (R07): an upload's entry would hold the address of the adult who sends. So no log shows who read, wrote or erased an object, and the lifecycle's erasures are not logged at all (sources 10.4). The buckets' settings and policies are Admin Activity, in `_Required`. BREACH.md, part 1, names the buckets (R27).

**The price** (sources 7.2). Standard in `us-east4` — $0.023 per GiB a month, class A operations $0.005 per thousand, class B $0.0004; `us-east4` has no free tier. Scans and sample files weigh megabytes: cents a month.

**Checked on the project**, what the documentation does not say:
- the buckets' settings, rules and policies are those of the tables above, and those of the upload service accounts hold the organizer's `roles/iam.serviceAccountTokenCreator` alone; the service `api`, `sweep` and `check` have `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`, and `sweep` runs with them;
- a policy serves several uploads until its expiration and is refused after it, `Form expired` (sources 10.1);
- a page of the tool uploads: Cloud Storage takes the expiration in the extended format and the credential's location `auto`; `--raw` gives the fields the tool reads; `withdraw` rewrites a form with an earlier Custom-Time (sources 10.8);
- a Custom-Time in the future is accepted (sources 10.3);
- `DELETE` of an absent object as `api-run`, without `storage.objects.get`, answers 404, which `sweep` takes for "erased already" (sources 10.5; Д29 `api`);
- `api-run` and the upload service accounts read no object and list no bucket, write only under their prefixes, and an upload service account overwrites nothing (sources 10.2);
- `gcloud storage buckets get-iam-policy` reads a policy in version 3, with its conditions, `describe` prints the place as `US-EAST4`, and `buckets list` the names alone (sources 10.7, 10.9);
- taking `bucketUploader` from an upload service account stops a page already signed as it at once — its next form is refused, `403 AccessDenied` —, and `bootstrap.sh`, which grants the role back, opens the same page again. So a page is stopped only while the role is off, and the script runs again only once the page has expired (BREACH.md, part 1; R28).

**Not checked on the project:** that an organizer sees neither the other's prefixes nor the scans, as a person: on `novatrail` the two organizers and the operator are one Google account (R139 spec; Д21). The policy holds it — each organizer's `roles/storage.objectUser` is under their prefixes, the reading of the scans is the operator's —, and the conditions on the same prefixes held the upload service accounts.

### 3.8. Platform AI on `novatrail`

`api` calls a provider of AI by the platform's key only where the admission table admits it, by the deployment's facts and the lowest rung (R11 spec; [the admission table](../spec/admission/README.md), sections 5 and 6). On `novatrail` it is open by R149 and R150 spec — for the author, and from 2026-11-28 for the other adults the operator lets in, once the entries of the author's word below have passed an eval or have a new word (R25):

| What | On `novatrail` | Where it is set |
|---|---|---|
| the rung | `author`; the default `full` | `admission.rung` of `deploy/production.json` and `api_admission_rung` of `tofu/production.auto.tfvars`, held equal by the list's check (R05) |
| the facts | what holds for `novatrail` alone: Anthropic's data processing agreement, for adults (R25; R149 spec) | `deploy/production/facts.json` (section 3.2) |
| the key | the secret `api-anthropic-key`, one exact version, mounted in the service alone as `/etc/api/anthropic/key`, its path in `API_ANTHROPIC_KEY_FILE` (R46 api) | `api_anthropic_key_version`; the value — the operator, by hand (R11) |
| the catalog | the modules `tofu/production.auto.tfvars` names, `novatrail/english-essays` among them (R150 spec; R25) | `api_catalog_modules`, `API_CATALOG_MODULES` of the service and of the jobs `check` (R150 spec; R79 api) |
| the mode of reading | `single`, one reading by one model for everyone, in place of the pair of R68 spec; the default `pair` (R25) | `api_reading_mode`, `API_READING_MODE` of the service and of the jobs `check` (R88 api) |

**The order of opening it:**
1. the author sets the spend limit of the Anthropic workspace whose key it will be (Д11 `api`);
2. a merge makes the secret `api-anthropic-key` with no value, with the rung `full` and the variables at their defaults, and deploys an `api` that takes the rung `author` on a deployment (R25; R45 api): an older `api` refuses it, and the apply makes a revision of the template on the image that serves;
3. the author adds the key as the secret's first version, typed and never shown, and checks that the database `api` holds no account but the author's — any other is the author's to decide, none deleted (R149 spec);
4. a merge sets `api_anthropic_key_version`, `api_admission_rung = "author"`, `api_catalog_modules`, the list's rung and the facts: its apply makes a revision with no traffic, and the path of the facts checks them by the jobs `check` and brings a new revision to the traffic (R05). The version must exist before this merge, or the apply's revision does not start.

**A new key** is a new version of the secret and a pull request that names it in `api_anthropic_key_version`: the same path of the facts. When the platform's key expires is Д28, and its workspace's spend limit is $5 a month. **To close platform AI at once**, withdraw a fact (R96 spec; section 3.2, «Rollback»); a leaked key — [BREACH.md](../BREACH.md), section 3. A code of `api invite` goes to another adult from 2026-11-28, when version 4 of the privacy policy is in force, and not before, and only once each entry the author's word admits has passed an eval or the author has given a new word: the operator's step, as in R25 (R149 spec; Д30).

**The author's word.** The rung `author` also admits reading a workbook page, reading an essay and assessing it by the rubric by the author's word, with no run of eval, until 2027-01-17 (R07 spec; R25; R29). Of the catalog, `novatrail/english-essays` reaches reading an essay and assessing it (R150 spec; R25); the workbook is for a child under 13, whom `novatrail` does not let in. The word holds on `novatrail` alone (R07 spec), and only while the author alone learns: before the first code of `api invite` to another adult, each entry has passed an eval or the author has given a new word, and before 2027-01-17 a release of `api` whose `tutor` no longer rests on the word goes out ([DEBT.md](../run/DEBT.md), Д30).

**A copy** keeps the defaults — the rung `full`, the mode `pair`, the whole pinned index, no key — or names its own values, and declares only facts that hold for it ([SELF-HOSTING.md](../SELF-HOSTING.md#8-your-list), «Your list»).

## 4. Sources

The records of external facts are in [sources.md](sources.md), a record per source, and a claim of this file cites its record: `sources 1.1` (RULES.md, The bar; R26). The section stays a pointer: the decision log and the archives `docs/plan/` cite it, and they are not rewritten. An item of this section that they name is the record of [sources.md](sources.md) with the same number.
