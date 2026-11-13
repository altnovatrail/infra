# infra — architecture

> Status: the detailing, epic E1, finished 2026-11-08 — sections 2 and 3; the first code, epic E2, done 2026-11-09 — the module, `bootstrap.sh`, the checks and the deployment —, and the platform's project `novatrail` is up. The first deployment, 2026-11-12, rolled out by the list `api` v0.1.22 and `app` v0.1.0 to `https://novatrail.web.app` (T24, epic E4; R25). The same day the checks after it verified on the project what E1–E4 had left to the first deployment (T42). Self-hosting and the local run, epic E3, done 2026-11-10 — the guide [SELF-HOSTING.md](../SELF-HOSTING.md) and the tests on a copy's values. Epic E4, the first deployment, done 2026-11-12, and within it, on 2026-11-11, the move to `spec` v0.15.0, T40, and on 2026-11-12 to v0.15.1, T41; its outcome, T38, checked sections 3–3.5 against the code. The current epic is E5, the operator's bucket and the procedure for a breach ([RUN.md](../RUN.md)); on 2026-11-13 its T45 decided how the bucket is built and how the upload link is signed (R28; section 3.7); the epics' archives, E4 among them, are `docs/plan/`. Outside an epic, on 2026-11-12, the move to `spec` v0.16.3 and the restructuring of the documents, T52 (R26): the records of sources are in [sources.md](sources.md), and section 4 is a pointer. The frame is from the template of `spec`, 2026-10-19.
>
> What the component does, what it does not do, and what is still to decide about it. This is the detail of its card — architecture 3.11 spec. The card stays the summary: if the detail changes what the card says, the card is changed in `spec` the same way as the questions for its registers (RULES.md, Across repositories).
>
> Why it was decided so and not otherwise is in [decisions.md](decisions.md); the work plan is in [RUN.md](../RUN.md). The concepts are concepts spec. The documents and decisions of `spec` are under `spec/docs/` and are cited with the suffix "spec".

## 1. Purpose and boundaries

**Does:**
- describes in code the platform's shared base: the projects in the cloud, Workload Identity Federation for CI, Artifact Registry, the domains, Secret Manager and the budgets (architecture 3.11 spec). The base is the technology base of MathTrail Canvas: Cloud Run and managed services that scale to zero, Terraform (R11 spec), and the tool is its open fork OpenTofu, at an exact version (the 2026-11-08 amendment to R11 spec; Т-29 closed; section 3.6). The model is `infra/` of canvas-api: `bootstrap.sh` and one root module in HCL (architecture 3.11 spec);
- sets up the platform's logs and traces — Cloud Logging and Trace (architecture 3.12 spec):
  - Cloud Run's request logs are excluded in Cloud Logging. Cloud Run writes them itself, and their field `httpRequest` holds the client's IP address, while COPPA counts an IP address as personal information (architecture 1 spec; privacy 4 spec). All of them are excluded, by a filter in each sink. The traces that Cloud Run writes itself on a part of the requests are possible — Cloud Trace API cannot be turned off while Cloud Scheduler needs it —: they are kept in `us-east4`, and the first trace will check their attributes: since the service started, 2026-11-12, there have been no traces (the third 2026-11-09 amendment and the 2026-11-12 amendment to R07; section 3.4);
  - the logs' region is `us-east4`, and the bucket `_Required` is in `global` while there is no Google Cloud organization (R04; R109 spec);
- chooses and sets up the hosting of the build of `app` — Firebase Hosting, and the first deployment has no domain of its own (R06; section 3.3) —, and by stage 4 the widgets' domain, a separate registrable one (R16 spec), and the hosting of the widgets (architecture 3.12 spec; Т-17). Only a hosting that sends its own response headers — CSP by the build's `csp.json`, and the cache — and serves `/deployment.json` outside the build's archive suits the platform (Т-17; architecture 3.12 spec). The samples page of `canvas` will move to Firebase Hosting as a separate site of the project with its own origin when the author decides so: the analysis is done — Google is a processor for Hosting, and it keeps IP addresses "a few months" (the second 2026-11-08 amendment to R25 spec; R128 spec; П-9 closed);
- keeps the operator's bucket — a private Cloud Storage bucket in `us-east4` for the samples from the samples page, the forms for them and the scans of consents, with a prefix per purpose, with access only for the organizers and the operator, without CI and agents, as R125 spec asks — CI keeps a reading through Firebase Admin (R28) —, and with lifecycle rules; the scan of a consent form from `app` is written there by `api` under its own prefix: the service `api` and the jobs `sweep` and `check` get the bucket and the prefix as the variables `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`, and their service account `api-run` gets the right to create and erase objects on the prefix, without reading (R125, R126 spec; the 2026-11-09 and 2026-11-10 amendments to R116 spec; architecture 3.11 spec; the README of `api` v0.1.21, section 4). How it is built is decided — `bootstrap.sh` makes it, and beside it a bucket of their own for the scans of `api`, and holds their access, with the operator's rights; the upload link is a POST policy signed through IAM, with no key, for at most 12 hours; CI reads both buckets all the same through Firebase Admin, and the author leaves it so (R28; section 3.7) —; `bootstrap.sh` makes the buckets and the module names the scans' bucket and `api`'s prefix to the service, `sweep` and `check` (the 2026-11-13 amendment to R11), but they are not on the project yet: Д11 of table 4 of [DEBT.md](../DEBT.md);
- rolls out the services and the build of `app` by one list of exact versions and digests — R106 spec decided this, and Т-19 is closed. In the dependency diagram `infra` rolls out the releases of `api` and `app` (repositories 3 spec). How the deployment goes (R105 spec, R106 spec; architecture 3.11 spec):
  - a service's image is built by the deployment of `infra`: it takes the binary and the `Dockerfile` from the service's release, checks them with the recipe of `spec` `release-verify` (R77 spec), builds the image on the base `gcr.io/distroless/static-debian13:nonroot` by digest, puts it into the private Artifact Registry of `infra` and rolls out a Cloud Run revision by the image's digest. The image of `api` is built by the contract of its release (the second 2026-11-08 amendment to R106 spec; section 3.2). What a service puts into the image beyond the binary, its own code does at the build stage: for `api` these are the module packages. NovaTrail publishes no images (RULES.md, Production images);
  - the rollout checks the build of `app` by the archive's signature, writes `/deployment.json` from the rollout list, having accepted it by the reading of the deployment configuration of the `spec` of its submodule — the schema and the rules — and by the schema `deployment.schema.json` of this build, and refusing a build of another format version (the 2026-11-08 and 2026-11-09 amendments to R85 spec; R19), builds the CSP header by the build's `csp.json` and releases the build, the file and the header in one release of the hosting (R85 spec). Beside the build's digest the list names the digest of its `/deployment.json` (Т-19);
  - a rollback is a revert of the list. `api`, and while the module format is v0 also a build of `app` that has moved to a new format version, roll back only forward (Т-19);
  - the jobs of `api` at a deployment — the migrations before requests are accepted, the job after the deployment once the revision has taken all the traffic — the deployment runs with the same image, and it hands the revision the deployment facts and the lowest admission rung of `api` from its own repository (the 2026-11-08 amendment to R106 spec): the facts as a file, a secret's volume, the path in `API_ADMISSION_FACTS_FILE`, the rung in `API_ADMISSION_RUNG`, and before the migrations a job calls the command of `api` that checks them (the second 2026-11-08 amendment to R106 spec);
  - the format and place of the list and who edits it, what the rollout checks before the deployment, that a release of `api` lower than the one rolled out is refused, and how the revision of `api` gets the facts and the rung — decided (R05; section 3.2);
- gives self-hosting and a local run of the whole platform (architecture 3.11 spec): the code is open, and an operator can deploy their own copy of the platform themselves (product 3 spec). Self-hosting takes the same list and the same path of deployment: it builds the image on its own side from the same binary and by the same `Dockerfile` (R105 spec, R106 spec). The signed build of `app` is one for everyone: it reads the deployment configuration at run time from `/deployment.json`, and the self-hosting operator writes that file themselves by the same schema (R85 spec; Т-19). Self-hosting declares its own facts for the admission to AI itself (Т-20; R96 spec).

**Does not:**
- stores no learners' data: of the platform's parts only `api` stores it on the server (architecture 1 spec; R15 spec). The operator's bucket that `infra` will set up (Д11) holds not learners' data from `app` but the samples from the samples page, the forms for them and the scans of consents, and the rules for them are R116, R125 and R126 spec. The database and the sign-in service were chosen by `api`: Neon Postgres and Firebase Auth (architecture 3.12 spec);
- keeps no secrets in the repository: the keys of AI providers are in Secret Manager (architecture 3.12 spec), and the service account of `api` reads them (R15 spec). The platform's keys for eval are there too (R24 spec) — `eval-key-anthropic` and `eval-key-openai` —, and CI of `modules` and `tutor` reads them through Workload Identity Federation, with its own pool `github-eval`, only the job of the GitHub environment `eval` (R120 spec; R20). The keys' values are never in the repository's files (RULES.md, Hard rules);
- holds no code of the services and does not publish their releases: the release with a signature is a shared workflow of `.github` that each repository with code takes (architecture 3.11 spec; repositories 2.1 spec);
- sets up no clusters, queues or event bus of its own. Background work is Cloud Run jobs on a schedule (architecture 1 spec; R11 spec); Cloud Scheduler and Cloud Run jobs are chosen by `api` and `infra` together (architecture 3.12 spec);
- does not serve the module packages in the first slice: at stage 2 they are in the image of `api`, and `api` serves the media files (architecture 3.10 spec). The code of `api` itself puts them into the image at the build stage, and the deployment does not repeat the logic of the packages (R106 spec). A store with a CDN in `infra`, by the recommendation of Т-17, comes when there are more modules or third-party authors arrive (repositories 8 spec);
- does not decide the data's region alone: `spec` decided it — the US, one place for all learners (R109 spec; П-11 closed) —, and here is only what follows from it for the resources of `infra` (R04).

**Data and links:**
- there are no learners' data and no secrets in the repository, as in no repository of the platform (RULES.md, Hard rules). But what it sets up — the logs, the region, the hosting — touches learners' data, so every proposal here is first read against privacy spec (RULES.md, Hard rules). The hosting and the infrastructure are data processors (privacy 2 spec);
- what the operator does in a breach of learners' data — where the data are and what opens them, how to cut the access, the logs, whom to tell and by when — is the procedure [BREACH.md](../BREACH.md), at the root, in English, for people, as SELF-HOSTING.md is: its part 1 fits any copy, its part 2 is the operator of `novatrail` and the law of Texas (R27);
- the logs hold events, codes, times and versions, without direct identifiers, IP addresses, works, what was read and the text of hints (R09 spec; privacy 4 spec; architecture 5 spec). The platform's logs are kept 30 days in `us-east4`, the audit 400 days in `global` (R07; П-9);
- the hosting of `app` and the sign-in service write the IP address into their own logs themselves (architecture 1 spec; architecture 3.12 spec; privacy 4 spec; П-9). The hosting is Firebase Hosting: it keeps IP addresses a few months, globally, and the period is not configurable, and `infra` does not turn on the export of its logs to Cloud Logging (R06). The sign-in service that `api` chose is Firebase Auth: it keeps IP addresses a few weeks, and it gets them not only at sign-in — on an iPad, in Safari and in mobile browsers its script and iframe load at every start of `app` (privacy 4 spec; architecture 3.12 spec; П-9);
- of NovaTrail's repositories it depends at build time only on `spec`, and while the platform runs it calls no one and no one calls it (repositories 2.1 spec). The table of repositories 2.1 spec is about the links between the repositories and about the platform's work. The tools of `infra` itself are not in it, and they go to the network: to GitHub and Sigstore — the checks and the deployment, to Google — `gcloud` and OpenTofu, to the OpenTofu registry — `tofu init` for the providers, to npm — the packages of `tools/` (sections 3.2 and 3.6). In the dependency diagram its arrows are the deployment of the releases of `api` and `app` (repositories 3 spec);
- it takes the shared checks of CI — secret scanning, DCO, CodeQL, Scorecard and the documents check — from `.github` even before code; T21 of `spec` connected them (R30 spec; architecture 3.11 spec). CodeQL reads the workflows and the code in JavaScript — `tools/` and the tests of `tofu/`, the input `languages: javascript-typescript` (T28). CodeQL does not read HCL and bash: its list of languages is C/C++, C#, GitHub Actions, Go, Java and Kotlin, JavaScript and TypeScript, Python, Ruby, Rust and Swift ([CodeQL, Supported languages and frameworks](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/), read 2026-11-09);
- a file of a NovaTrail release — a service's binary, its `Dockerfile`, the build's archive of `app` — enters the deployment only once the recipe of `spec` `release-verify` has accepted it (RULES.md, Release files are verified; R77 spec). Т-27, the question of what this check verifies, was closed by the same decision;
- its services (architecture 3.12 spec): the hosting of the build of `app`, the widgets' domain and hosting at stage 4, Secret Manager, Artifact Registry, Cloud Logging and Trace, and together with `api` Cloud Scheduler and Cloud Run jobs;
- stage 2, with `tutor`, `canvas`, `api`, `app` and `skill-map` (product 11 spec). The repository was set up before its code for the sake of its documents, and the code waited for П-11 — the data's region, which is needed before the first deployment (architecture 3.11 spec; repositories 2.1, 6 spec). П-11 is closed by the decision R109 spec (R03). The first app is with the author, local and without a deployment, so the author put off the row of `infra` in the cross-repository plan of `spec` until the first deployment (R76 spec). The tool comes into the devcontainer together with the code (T14 of `spec`), and it is OpenTofu: Т-29, which grew out of this repository's question В2, is closed by the 2026-11-08 amendment to R11 spec by row В10 (R08), and it has been in the stage `toolchain` since T11 (R09).

## 2. To decide when detailed

The points of the card's "To decide when detailed" — a subsection for each point, and the two points about the rollout in one, 2.2. A decided point names the entry of the log, and the decision itself has moved to section 3. A question that goes beyond this repository goes «в реестр spec» (RULES.md, Across repositories).

Epic E1 decided everything the card left to the detailing but Т-29, and beyond the card's list it decided one point and put off another — 2.6, which epic E3 decided. `spec` closed Т-29 by row В10, and the card's "To decide when detailed" became empty (R08), and since v0.15.0 it holds one point again — how to sign the upload link to the operator's bucket (R125 spec; R23) —, 2.7:
- 2.1–2.3 — the region, the rollout list and the checks, the hosting and the addresses — decided: R04–R06, sections 3.1–3.3. The region was closed in `spec` by R109 spec. What of 2.2 and 2.3 concerns other repositories and the registers of `spec` went as rows «в реестр spec» В4–В7, and `spec` recorded them all by their recommendations (R08): the variables of the facts and the rung and the check command of `api` — the second 2026-11-08 amendment to R106 spec, the move of the format of `/deployment.json` — the 2026-11-08 amendment to R85 spec, the hosting, the domains and the period of the IP addresses of Firebase Hosting — Т-17, О-16 and П-9;
- 2.4 — the exclusion of the request logs, beyond the card's list — decided: R07, section 3.4. The logs' periods and the clarification of privacy 4 spec were recorded by `spec` by row В8 in П-9 and privacy 4 spec, and it edited the card for it and for what was decided by row В9 (R08);
- 2.5 — Terraform or OpenTofu — put off on purpose and decided first thing in epic E2: OpenTofu, the 2026-11-08 amendment to R11 spec by row В10 (R08), section 3.6;
- 2.6 — self-hosting and the local run of the whole platform, beyond the card's list — decided by epic E3: R21, R22, section 3.5. What this changes in the card went as row «в реестр spec» В21, and `spec` recorded it in the card (R23);
- 2.7 — signing the upload link to the operator's bucket — decided by T45 of epic E5: R28, section 3.7;
- 2.8 — auditing the reads of the secrets, beyond the card's list — open: found by the procedure for a breach, T44 (R27; Д20).

### 2.1. Region (П-11)

Decided: R04, by R109 spec; section 3.1. Tasks — T01, T08.

### 2.2. The list of versions and the checks of the rollout (R106 spec)

Decided: R05; section 3.2. Task — T02.

### 2.3. Hosting of the build of `app` and domains (Т-17)

Decided: R06; section 3.3. Task — T03.

### 2.4. Excluding the request logs

Decided: R07; section 3.4. Task — T04.

### 2.5. Terraform or OpenTofu (Т-29)

Decided: the 2026-11-08 amendment to R11 spec, Т-29 closed, by row В10 (R08); section 3.6. Tasks — T09 and T10, and T11 installs the tool in the devcontainer, and T12 checks the code under `tofu`.

### 2.6. Self-hosting and the local run

Decided by epic E3, 2026-11-10; section 3.5. The card had no point of "To decide when detailed" about them (architecture 3.11 spec):
- **self-hosting** — the operator's guide [SELF-HOSTING.md](../SELF-HOSTING.md): the main path is a fork with GitHub Actions, and without them the same recipes with the operator's rights (R21). Its own region, its own Firebase project and its own environments are the copy's values, and the tests on a copy's values hold them (T29; the 2026-11-10 amendment to R18);
- **the local run of the whole platform** — from source, by the recipes of `api` and `app`, and `infra` gives a description — "Running the whole platform on one machine" [SELF-HOSTING.md](../SELF-HOSTING.md#12-running-the-whole-platform-on-one-machine) (R22). `api` in it is the origin of `app` itself, and the proxy of the server of `app` leads the paths of `api`; the sign-in project is the dev project of `api` (the answers of `spec` to В19 and В20; the 2026-11-11 amendment to R22).

Tasks — T29–T32; what this changes in the card 3.11 spec is row В21, which `spec` recorded (R23). The steps of the guide that nobody has gone through yet are the deployment in E4 and Д9; the local run is checked against the first run of 2026-11-12 (the 2026-11-12 amendment to R22).

### 2.7. Signing the upload link to the operator's bucket (R125 spec)

Decided: R28; section 3.7. Task — T45, 2026-11-13. The link is the option (b) below, signed through IAM: without a key a signature lives at most 12 hours (sources 10.1), not a day, and the difference with R125 spec is row В30 of table 3 of [RUN.md](../RUN.md). Below — the question as it stood before T45.

Open until T45. The card architecture 3.11 spec leaves it to `infra` to decide how to sign the link by which the measurement organizer or the eval-set organizer gets the files of a sample and the scan of a form into the operator's bucket. What is already set (R125, R126 spec; the 2026-11-09 amendment to R116 spec): the organizer gives the link, it is valid for a day from the session, and a file lands under the prefix of its purpose; neither CI nor agents have access. There are no keys of service accounts in files, and there will be none (RULES.md, Hard rules).

Options:
- (a) a Cloud Storage signed URL that the organizer issues with their own sign-in to `gcloud`, through an upload service account with the right only to create objects under the purpose's prefix, with no key — by a signature through IAM;
- (b) a signed POST policy — the same, but with conditions on the object's name and size in the signature itself;
- (c) a service account key held by the organizer — contradicts the rule on secrets and is rejected at once.

Recommendation — decide in the bucket's task, when it is planned, between (a) and (b), having checked in Cloud Storage's documentation the longest validity of a signature, the conditions of a policy and the rights the organizer needs to sign as another service account; these facts are not yet checked here and are not stated. Task — T45 of epic E5 (Д11).

### 2.8. Auditing the reads of the secrets

Open, beyond the card's list; T44 found it while writing the procedure for a breach (R27). Who has read a secret's version — among them the four connection strings to the databases of `api` in Neon, which open learners' data — is `AccessSecretVersion`, a Data Access audit entry (sources 2.6). The project does not turn Data Access on, and every sink excludes it (the 2026-11-09 amendment to R07; section 3.4). So in a breach the logs show who added or disabled a version and who changed a right on a secret — that is Admin Activity —, but not who read the string. The reason R07 gives against Data Access is the `callerIp` in its entries. A read of a secret is made by `api-run`, by the operator in Cloud Shell or by CI: the address is Google's or the operator's, not a learner's. That is an inference from who reads the secrets, not checked on entries.

Options:
- (a) Data Access, `DATA_READ`, for `secretmanager.googleapis.com` alone, and the exclusion `data-access-audit` of each sink lets those entries through: a read of a version is seen 30 days in the bucket of `us-east4`. To check before: what the entry holds besides the caller and the address, how many entries the instances and jobs of `api` write a day, and what they cost;
- (b) as now: the procedure says what the logs do not show.

Recommendation — (a), in a task of its own with code, which checks the entries on the project before it decides; until then (b). Debt — Д20.

## 3. How it is built

Here is what was decided by section 2: which parts the component consists of, its data and how it is linked with other repositories. The decisions are R04–R07 and the 2026-11-08 amendment to R11 spec (section 3.6); the module and the deployment were built by epic E2 «Первый код».

**What the repository consists of:**

| Part | What it does | Decision |
|---|---|---|
| `tofu/bootstrap.sh` | once, with the operator's rights: the project and its billing, the state bucket, the Workload Identity Federation pool for CI, the configuration's service account `infra-config` and its rights, and the custom roles that the module grants — `apiDeployer`, `hostingPublisher` and `signInUsers`; the second pool, `github-eval`, for the eval job of `modules` and `tutor`, with no service accounts; the operator's bucket and the bucket of the scans of consents, with their access and lifecycle rules, and the two upload service accounts (section 3.7); on the model of canvas-api | R13, R20, R28; R11 spec; model — canvas-api |
| the OpenTofu root module, `tofu/` | the project and its services: Artifact Registry, Secret Manager with the secrets of `api` and the keys for eval (R20), the log bucket and the sinks with exclusions, the place of the bucket `_Trace`, Firebase with the Hosting site and the Web App, Identity Platform, the service accounts and their rights, the budget and the alerts, the Cloud Run service and jobs and the jobs' schedule in Cloud Scheduler. The module creates the service and the jobs with the first image, which `api_image` names, and after that the deployment sets the image, the revision and the facts' version in the volume by digest, and the module does not touch them, as `ignore_changes` does at canvas-api (sources 8.1). Everything is in the region of section 3.1 | R04, R05, R06, R07, R10; the 2026-11-08 amendment to R11 spec |
| `deploy/` | the rollout list, the values of `/deployment.json`, the facts file and the list's schema | R05; section 3.2 |
| the checks of a pull request | the schema, `release-verify` and sha256, `deployment.json`, the facts, the rung, the tag of `api` not lower | R05 |
| the deployment | recipes and a workflow: the image, the jobs of `api`, the revision, the release of the build of `app` on Hosting | R05, R06; sections 3.2, 3.3 |

The recipes of the checks and of the deployment run without GitHub Actions too — self-hosting uses the same ones (section 3.5).

**Links with other repositories:**

| Repository | What `infra` takes | What `infra` gives |
|---|---|---|
| `spec` | the rules, `release-verify`, the admission table and the format of `/deployment.json` — the part `deployment/` with its own version, a schema at a permanent path and reading vectors (the 2026-11-08 and 2026-11-09 amendments to R85 spec; R19) | the rows «в реестр spec» of table 3 of [RUN.md](../RUN.md) |
| `api` | the release's binary and `Dockerfile` by the build contract, the commands of the configuration check, of the migrations, of the job after the deployment and of `sweep` (R28 api; the second 2026-11-08 amendment to R106 spec) | the image, the revision and the jobs, the facts file — the path in `API_ADMISSION_FACTS_FILE`, the rung — in `API_ADMISSION_RUNG`, the databases' connection strings from the secrets, `API_APP_ORIGIN`, the scans' bucket and prefix — `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX` — and the right there, the schedule of `sweep`, the address `*.run.app` |
| `app` | the build's archive with `deployment.schema.json`, `csp.json`, `NOTICE` and `LICENSE` (the 2026-11-11 amendment to R85 spec) | `/deployment.json`, the headers, the origin `web.app` and the authorized domain of Firebase |
| `canvas` | — | later, a separate Hosting site for the samples page (R06) |
| `.github` | the shared checks of CI; the release files that `infra` rolls out are signed by the shared `release.yml`, and `release-verify` of `spec` checks the signature (R77 spec) | — |
| `tutor` | the codes of the admission rungs, `author` and `full`, the type of the facts file and its parsing (R57 tutor) | — |
| `modules`, `tutor` | — | the platform's keys for eval `eval-key-anthropic` and `eval-key-openai` in Secret Manager, for the job of the GitHub environment `eval`, through Workload Identity Federation with its own pool `github-eval`, which `bootstrap.sh` makes; the names of the provider and of the secrets are the output `eval_access` (R120 spec; R20) |

### 3.1. Region

The platform's region is the US, one place for all learners (R109 spec; П-11 closed). What this means for the resources of `infra` is R04. Sources: sources 1.1–1.8.

| Resource | Place | Why so, and what does not change after creation |
|---|---|---|
| Cloud Run services and jobs | `us-east4` (Ashburn, Virginia) | near Neon `aws-us-east-1` of the database of `api`; Tier 1 prices |
| the jobs' schedule, Cloud Scheduler | `us-east4` | in the region of the jobs it runs: the module puts it in the module's region, and the first deployment created it so (T24) |
| the Artifact Registry repository | `us-east4`, regional | a repository's place does not change; a multi-region is slower |
| Secret Manager secrets | user-managed replication, place `us-east4` | the replication's places do not change; automatic replication has no constraints, and a regional secret is accessible only from its own region, and CI on GitHub, which reads the keys for eval (R120 spec), could not read it |
| the log bucket | its own, `us-east4`; the sink `_Default` is directed to it | the bucket `_Default` is created in `global`, and a bucket's place does not change — the sink changes. Cloud Run's request logs are excluded (section 3.4) |
| the bucket `_Required` | `global` | the sink `_Required` does not change, and only a setting of an organization or a folder made before the project is created gives the bucket a region; an organization is tied to a domain, and there is none until О-16 — Д3 in table 4 of [DEBT.md](../DEBT.md) |
| the trace bucket `_Trace` | `us-east4`: the default place for Observability buckets is set before the first trace, and the system creates the bucket with the first trace (the 2026-11-09 amendment to R04) | otherwise the default settings or the system itself would choose the place, and only a reprovision, which erases the traces, can change it |

Not `infra`: `api` keeps the Neon database `aws-us-east-1`; Firebase Auth processes data only in the US whatever the region; the hosting of the build of `app` is Firebase Hosting (R06), a global service; R109 spec does not decide the region of AI calls (R96 spec).

### 3.2. The rollout list and the deployment

`infra` rolls out the services and the build of `app`, by one list of exact versions and digests, and the deployment builds a service's image from the files of its release (R105, R106 spec). A component's repository rolls out nothing itself and has no access to production: the projects and Workload Identity Federation for CI are with `infra` (R106 spec). How the list and the deployment are built is R05.

**The directory `deploy/`:**
- `production.json` — the rollout list;
- `production/deployment.json` — the values of `/deployment.json` of the build of `app`, format 1 (R09 app); `api` in it is the deterministic address of the service, the module's output `api_origin`, `https://<service>-<project number>.<region>.run.app`: it is known before the service exists (the second 2026-11-10 amendment to R05);
- `production/facts.json` — the file of deployment facts for the admission function, in the form `facts` of the admission table ([the admission table's text](../spec/admission/README.md), section 5);
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

The name of the binary of `api` is by the contract of its release, `api_<tag>_linux_amd64` (R28 api; the second 2026-11-08 amendment to R106 spec); beside the binary the release carries the `Dockerfile` and `SHA256SUMS`, each file with a signature (sources 3.3; T18). The platform's list is `deploy/production.json`: the first deployment, 2026-11-12, took `api` v0.1.22 — the commands `serve`, `check`, `migrate`, `after`, `sweep`, `invite`, `countries` and `version` — and `app` v0.1.0, the build's first release (R25). The configuration check command came in `api` v0.1.16, the job after the deployment in v0.1.20 (sources 3.10, 3.11).

**A pull request with the list** — CI without access to production:
1. the list — by its schema;
2. the binary, the `Dockerfile` and the archive — `release-verify` with the repository and the tag from the list, and the sha256 of each as in the list, and the binary's name by the release's contract. If Sigstore or GitHub does not answer, the file is refused (R77 spec);
3. `deployment.json` — by the reading of the deployment configuration of the submodule's `spec`, as `app` reads it: the schema `deployment/schemas/deployment.schema.json`, then the rules `deployment.api-origin` and `deployment.loopback` —, and by `deployment.schema.json` from the archive, and the build must read the same format version as the submodule's `spec`, or it is refused, with both named (the 2026-11-08 and 2026-11-09 amendments to R85 spec; R19); the file is no more than 16 KiB, and its sha256 as in the list; `api` in it is the address of the service `api`, the output `api_origin`, by the project number from `tofu/ci.env` and the values of `tofu/production.auto.tfvars`, and without `ci.env` or outside a git repository it is not compared (the second 2026-11-12 amendment to R14);
4. `facts.json` — by the facts' vocabulary of the admission table of the submodule's tag of `spec`: this is an early sign, and the image of the new release of `api` checks the file finally (step 4 below);
5. the rung — `full` (R25 api);
6. the tag of `api` — not lower than in the list on `main`.

**The checks in code** (R14; T18) — `tools/deploy-check/` on Node and ajv 8.20.0, the recipe `just deploy-check`. The CI job `Deploy` runs their tests in every pull request — the synthetic ones and the real release `api` v0.1.5 against GitHub and Sigstore —, and the list itself when the pull request changes what it is checked by: `deploy/`, `tools/deploy-check/` and `tools/deploy/`, their packages, the `justfile`, the tag of `spec` or `tofu/variables.tf`, whose default names the service `api`. An edit of `tofu/ci.env` and `tofu/production.auto.tfvars` alone does not check the list: a fork's first pull request changes only them, and its list is still the platform's, with the platform's address of `api` (the second 2026-11-12 amendment to R14). The same job runs the tests of the deployment and of the tools' installation, and the license check. The platform's `deploy/production.json`, `production/deployment.json` and `production/facts.json` were written by the first deployment (T24).

**The deployment** — after the merge, from the list's commit. The first job checks that `main` is at this commit, and each next one checks it on a retry (R45 canvas-api). The deployment does only what changed against the commit of the last run that deployed — the job `target` below (R18).

A new release of `api`:
1. the cloud's configuration — `tofu apply` from the same commit (section 3.6); this step runs at every deployment;
2. the tag of `api` — not lower than that of the revision that takes the traffic now: `main` may be ahead of production if the last deployment did not get through. Traffic split between revisions is a refusal: that rollout is first finished or undone by hand. Then `release-verify` and the sha256 of each file again — only a checked file gets into the job that reaches production. If the registry already holds an image under the release's tag, the deployment takes it by digest, without the second check and without step 3;
3. the image — by the contract of the release of `api`: the binary as the file `api` in the build context `binary`, the image by `docker build --target release --build-context binary=<folder>` by the `Dockerfile` from the release, on the base by digest that the `Dockerfile` names; the stage does not read the main context (R105 spec; R28 api; the second 2026-11-08 amendment to R106 spec). The build stage puts the module packages into the image with a command of the binary, and it needs the network (architecture 3.3 api). The image goes to Artifact Registry `us-east4` (R04), its digest from the push;
4. the configuration check — by a Cloud Run job with the same image, with the facts file and the rung of the new list: the module gives the job of the part `check` the facts' volume, `API_ADMISSION_FACTS_FILE` and `API_ADMISSION_RUNG`, and the deployment gives the exact version of the facts, the one that will go to the revision (the third 2026-11-10 amendment to R11; the 2026-11-10 amendment to R15). The job is `api check` of the release `api` v0.1.16 (the fourth 2026-11-10 amendment to R11): a fact unknown to this release's table stops the deployment before the migrations. The command comes from the binary `api`: it checks the facts file against the release's admission table, and the rung, and serves no requests (the second 2026-11-08 amendment to R106 spec);
5. the migrations job of both databases, `api` and `openfga` (R05 api), with the same image by digest, by the command that the release of `api` names. If it fails, the deployment stops, and there is no new revision;
6. the Cloud Run revision by the image's digest — with the facts file as a volume on an exact version of the secret (R05; the second 2026-11-08 amendment to R106 spec): the module sets the path to it in `API_ADMISSION_FACTS_FILE` and the rung `full` in `API_ADMISSION_RUNG` (the 2026-11-09 amendment to R05; R11) — at first with no traffic; when its own condition `Ready` is `True`, all the traffic goes to it (the 2026-11-12 amendment to R15);
7. the job after the deployment — with the same image, once the new revision has taken all the traffic (the 2026-11-08 amendment to R106 spec): `api after` of the release `api` v0.1.20, with the pooler's string of the database `api`, closes as "unchecked" what is open on packages the image no longer gives (the 2026-11-11 amendment to R11). Its failure stops the deployment already on the new revision, and what it did not close the next `sweep` will close.

Facts only: a new version of the facts' secret, its check — step 4 on the image already rolled out —, and a new revision on this image, by its digest — step 6; there are no steps 2, 3, 5 and 7 (the 2026-11-10 amendment to R05). There is no path "rung only": the deployment's rung is always `full` (the 2026-11-09 amendment to R05). There is no build, no migrations and no `release-verify`: the release's files did not change, and the removal of a fact does not wait for Sigstore.

A new release of `app` — only when the service `api` exists: while the commit's `production.auto.tfvars` does not set `api_serving = true`, a run does not roll out `app`, and the run that set it rolls out `app` even if it did not change (the second 2026-11-10 amendment to R05):
1. `release-verify` of the archive and the sha256 — as in step 2;
2. the archive is laid out on the hosting, `/deployment.json` is written from `deploy/production/deployment.json`, the CSP header is built by the archive's `csp.json`, and everything goes out in one release of the hosting (R85 spec; R09 app). On Firebase Hosting — section 3.3 (R06);
3. the domain of `app` is in the authorized domains of the Firebase project (Т-19): the module sets them, by the cloud's configuration of the same deployment (R16).

**The deployment of `api` in code** (R15; T19) — `tools/deploy/api.sh`, the recipes `just deploy-api-image`, `deploy-api` and `deploy-api-facts`, on the module's outputs after `apply`:
- `image` — the release's files again through `release-verify` and sha256, the image `<registry>/api:<tag>`, the digest after the push — or the image that the registry already holds under the release's tag;
- `release` — the steps above: a refusal of a release lower than the one whose tag the image of the revision with traffic carries in the registry, the image — or the one the registry already holds under the release's tag —, a new version of the facts, the image to the jobs `check` and `migrate` — to the jobs `check` with the exact version of the facts, the one it has just added — and their run, a revision without traffic, all the traffic to it by name, the image to the other jobs, and the jobs `after`. Without the service, only the jobs;
- `facts` — the path "facts only": a version of the facts, the jobs `check` with it on the image that takes the traffic, and a revision.

Which jobs to run when is said by the field `deploy` of the module's entry `api_jobs` (the second 2026-11-09 amendment to R11). By default these are `check` — the configuration check before the migrations, `migrate`, `after` — after the revision has taken all the traffic —, and `sweep` on a schedule: the commands of the release `api` v0.1.22, which is rolled out (the 2026-11-10 and 2026-11-11 amendments to R11).

**The release of `app` in code** (R17; T20) — `tools/deploy/app.mjs`, the recipes `just deploy-app` and `deploy-app-check`, on the module's outputs after `apply`, `hosting_site` and `hosting_url`, through the REST API of Hosting:
- `release` — the steps of section 3.3: `deployment.json` of the sha256 that is in the list; the archive of the new build and that of the released one — `release-verify` and sha256 again; the service `api` in the module's outputs and the file's `api` equal to `api_origin` — otherwise a refusal before Hosting (the 2026-11-10 amendment to R17); one version with the configuration, a release with a message that names the build, and the check of the responses;
- `check` — only the check of the site's responses, by the build from the list.

The release signs in with an access token of `hosting-publish` from `gcloud`, and it needs no rights but `hostingPublisher` (the third 2026-11-09 amendment to R12). The check of a pull request looks at the same layout and the same `csp.json` of the build as the release does (the 2026-11-09 amendment to R14).

**The deploy workflow** (R18; T21) — `.github/workflows/deploy.yml`, after a push to `main` by the paths of what it deploys, or by hand with a choice of parts:

| Job | Environment and service account | What it does |
|---|---|---|
| `target` | none, without sign-in | is `main` at the commit? is the project up? which parts of the list changed against the last run that deployed; without `api_image`, only the image of `api` |
| `config` | `production-config`, `infra-config` | `just ci-tf-apply`; the module's outputs as an artifact; all three environments exist and run only from `main` — `just ci-deploy-environments` |
| `api` | the output `deploy_environment`, by default `production`; `api-deploy` | `just deploy-api`, `deploy-api-facts` or `deploy-api-image` — while there is no `api_image`, or by hand |
| `app` | the output `hosting_environment`, by default `production-hosting`; `hosting-publish` | `just deploy-app`, after `api` if it ran and passed |

Each job after `target` asks on a retry whether `main` is at the commit. `.github/actions/tools` installs the tools at exact versions and sums: OpenTofu, `just` and Node by the `ARG` of the Dockerfile, the Google Cloud CLI, `jq` and `buildx` by `tools/ci/versions.env`, and the runner's Docker engine is checked against the recorded version.

**The operator's step before the first deployment** (T23), after `bootstrap.sh`:
1. `tofu/ci.env` — the two lines that `bootstrap.sh` printed, `GCP_WORKLOAD_IDENTITY_PROVIDER=…` and `GCP_CONFIG_SERVICE_ACCOUNT=…`, and nothing else; the file is committed and goes through review (the third 2026-11-09 amendment to R13);
2. the GitHub environments `production-config`, `production` and `production-hosting`: Settings → Environments → New environment, in each "Deployment branches and tags" → "Selected branches and tags" → the rule `main`. No reviewers and no wait timer: the approval is the review of the pull request (R05). An environment that does not exist GitHub creates itself at the first job — with no rule, and then `ci-deploy-environments` of the job `config` stops the run before the jobs `api` and `app` (R18);
3. in `production-config`, the environment's secrets `TF_VAR_billing_account` and `TF_VAR_operator_email`; the other environments have no secrets.

While `tofu/ci.env`, `tofu/production.auto.tfvars` and `tofu/backend.hcl` were not in `main`, a run of the deployment was green and did nothing. Since T23 they are there, and every merge that changes the deployment's paths applies the configuration in the project `novatrail`.

**Rollback:**
- `api` — only forward: a new release of `api` and a new pull request, and neither CI nor the deployment lets a lower tag through;
- the build of `app` — a pull request that returns the list's block `app` to its former values: the former build with its own file, in one release. A revert of a whole commit that also raised `api` would be refused. A build that has moved to a new module format version goes only forward, and the author checks this in review;
- the facts — a pull request with the former file: a new revision on the same image. The rung is always `full`, and there is nowhere to roll it back to. To close the platform AI urgently, remove a fact (R96 spec).

A deployment that did not get through is repeated by rerunning its jobs, or fixed forward by a new pull request.

**The registry and the facts' secret in the module** (T14):
- `tofu/registry.tf` — the Docker repository `images` in the region. The cleanup keeps the 5 latest versions in any state, and deletes only untagged versions older than 30 days; a version that fits both keeping and deletion is kept (sources 5.4). The deployment pushes the image with the release's tag (T19), so the image rolled out keeps its tag however many pushes come after it, and the path "facts only" will stand on it by digest; the tag is lost only by a push of the same release by hand: the deployment takes the image the registry already holds under the tag. The module does not delete the repository: `deletion_policy = "PREVENT"`. The module gives no reading of it outside the project, and the right to push is with `api-deploy` (`tofu/identities.tf`);
- `tofu/secrets.tf` — the secret `api-admission-facts` with a replica only in the region and with no value: the deployment adds each version. The module does not delete it: `deletion_protection = true`, since the revision mounts one of its versions. Reading is for the service account `api-run`.

**The service, the jobs and the service accounts in the module** (R11; T15):
- `tofu/api.tf` — the jobs `api-<name>` by the list `api_jobs`, now `check`, `migrate`, `after` and `sweep`, and the service `api`. The container of the service and of each job is named `api`: `gcloud` takes an unnamed one for someone else's, and `--update-secrets` sets up a facts volume of its own in place of the module's (the 2026-11-12 amendment to R11). The jobs appear when `api_image` names the first image from `images`, and the service after them, when `api_serving = true` as well: the first deployment runs the check and the migrations as jobs before the service takes its first request. The deployment changes their image, and for the service and the jobs of the part `check` also the version of the facts' secret in the volume; the rest is the module's. The service gets the pooler's strings of both databases as variables from their secrets, `API_DATABASE_URL` and `API_OPENFGA_DATABASE_URL`, and `API_APP_ORIGIN` — the origin of the default Hosting site; the service has one volume, the facts' (the 2026-11-10 amendment to R11). The service, the jobs of the part `check` and those with `consent_forms`, by default `sweep`, get `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`, `consent-forms/`. Since a deployment has given the traffic to a revision by name, a change of the service's template by an `apply` makes a revision with no traffic, and reaches the traffic with the next deployment of `api` (the 2026-11-13 amendment to R11). The jobs with `schedule` run through Cloud Scheduler and the service account `api-scheduler`, and only when the service exists: `sweep` every day at 09:00 UTC (the second 2026-11-10 amendment to R11);
- `tofu/identities.tf` — `api-run`, which reads the facts' secret, the service's secrets and the jobs' secrets, and `api-deploy`: a push to `images`, a new version of the facts' secret, the role `apiDeployer` on the service and the jobs — `bootstrap.sh` holds its rights (the 2026-11-09 amendment to R11) — and the right to run them as `api-run`. The Workload Identity Federation pool lets the deployment in only from the GitHub environment that the output `deploy_environment` names, by default `production` (the 2026-11-10 amendment to R18);
- `tofu/secrets.tf` — the service's secrets, the pooler's strings `api-database-url` and `api-openfga-database-url` — at once, before the service, and the module does not delete them; the secrets that the jobs name: for `migrate`, the direct connection strings to both databases. All of them have no values, and a job that names a secret of the service reads that same secret.

**The first deployment** (R25; T24), 2026-11-12 — by the steps of R11 and SELF-HOSTING.md, "Deploying":
1. pull request 54 with the list — the image `api` v0.1.22 in `images`. The runs of the merges 54 and 56 failed (43159740759, 43161291785), the run of the merge 57 built it (43164987259): a registry without the package `api`, and the runner's `just` in another place (the 2026-11-12 amendments to R15 and R14);
2. four connection strings of the Neon databases — as secret versions, by the operator's hand in Cloud Shell; pull request 58 with `api_image` — the jobs (run 43259718293);
3. `Deploy` with **api** — `check` and `migrate` (run 43264054707). Before it two runs failed: the service did not exist yet, and `api-deploy` does not read it (43260063441, the 2026-11-12 amendment to R15), and the strings were without `sslmode=verify-full`, without which `api` v0.1.22 does not take them (43262097982);
4. pull request 60 with `api_serving = true` — the service, the schedule of `sweep` and the release of `app` (run 43265402009);
5. `Deploy` with **api** — the revision, all the traffic to it, and `after` (run 43274407909), after pull request 61: the previous run stopped at the revision without traffic (43265811304; the 2026-11-12 amendments to R11 and R15);
6. the operator in Cloud Shell, with the binary of the release of `api` and the pooler's string from the secret — `api countries allow US` and `api invite` for each learner (R25 with its 2026-11-12 amendment).

**The checks after it** (T42), 2026-11-12:
- the service and the job `api-check` have one facts volume, the module's `admission-facts`, with the version `5` that the deployment added, and the `apply` of the next merge says "No changes" (the second 2026-11-12 amendment to R11);
- on the project `api-run` has one role, `signInUsers`, and `api-deploy` none: the deployment has enough rights on its own resources (ibid.);
- a failure of the job `after` in a run is like the failure of any job of the deployment, only the deployment already stands on the new revision with traffic, and this run's `app` does not run (the second 2026-11-12 amendment to R15);
- the cost of Cloud Run and Neon — after T42: the debt Д16 of table 4 of [DEBT.md](../DEBT.md);
- the first scheduled run of `sweep`, 2026-11-13 at 09:00 UTC: `api-scheduler` called it on time, and the pass was clean (the 2026-11-13 amendment to R07; T43).

**Self-hosting** — the same directory `deploy/` with its own `deployment.json` and facts, the same checks and steps in its own project and its own private registry. The signed release files are the same for everyone (R105, R106 spec; Т-20).

### 3.3. Hosting of the build of `app` and domains

Firebase Hosting serves the build of `app` — the project's default site, the Blaze plan; the project's budget with an alert is `tofu/budget.tf` (R06; T14): only this project, by its number, per month, emails at 50, 90 and 100 % of the amount — to the billing account's administrators and users, as a budget sends them by default, and to the operator's channel if it is named (sources 5.4). The amount and the currency are values of the deployment, and the billing account comes from the environment, `TF_VAR_billing_account`: it names who pays.

**The release** — the step of the deployment of `app` in section 3.2:
1. the release's folder — the new build's archive, the `assets/` of the build that is now released on Hosting, and `/deployment.json` from `deploy/production/deployment.json`. The rollout learns the released build from the Hosting release, not from the list on `main`: by the message of the live channel's release, `app <tag> <archive> <sha256>`, and after `keeping` the build whose `assets/` this release kept (the second 2026-11-09 amendment to R06). If the list names the very build that is released, the previous one is the one after `keeping`. The rollout checks its archive as it checks a new one: `release-verify` and sha256. No release — no previous build; another message — a refusal. A Hosting version is a full set of files, and without the previous build's `assets/` it would remove them. A file of the same path comes from the new build;
2. the rollout writes the version's configuration (R17):
   - `headers` — two sets of paths that do not overlap: outside `/assets/**`, `!/@(assets)/**` — `X-Content-Type-Options: nosniff`, HSTS, CSP by the archive's `csp.json` with `{api}` and `{authDomain}` from `deployment.json` and with `frame-ancestors 'none'`, and `Cache-Control: no-cache`; under `/assets/**` — `nosniff`, HSTS and `public, max-age=31536000, immutable`. Hosting matches headers against the request's path before rewrites, so they are not set by the path `index.html`. On `*.web.app` Hosting sets its own HSTS (sources 4.5);
   - `csp.json` — a table "directive → string of sources" with the places `{api}` and `{authDomain}`; the rollout refuses another form (R17; row В14 of table 3 of [RUN.md](../RUN.md));
   - the SPA rewrite to `index.html` — only outside `/assets/**`; `/deployment.json` is in every version, and Hosting rewrites only a path where there is no file;
   - without `Cross-Origin-Opener-Policy: same-origin`;
3. the release — one version: the files and the configuration together;
4. the check after the release — the bytes of `index.html`, the headers at `/`, at an SPA path and at a file in `/assets/`, `404` for an unknown file in `/assets/`, `/deployment.json` as `app` reads it, the bytes of `/NOTICE` and `/LICENSE` against the build's files (the 2026-11-11 amendment to R17), and `Cross-Origin-Opener-Policy: same-origin` nowhere.

Rollback — by R05, a pull request with the former block `app`; a rollback by a version in the Firebase console is not used.

**Logs:**

| Log | IP address | Where and how long |
|---|---|---|
| the logs of Firebase Hosting itself | yes | at Firebase, globally: "a few months", not configurable (П-9; privacy 4 spec) |
| the export of Hosting's logs to Cloud Logging | yes, `remoteIp` | not turned on: only a button in the Firebase console can turn it on, and if it is pressed, each sink excludes `resource.type="firebase_domain"` (the second 2026-11-09 amendment to R07) |

**Addresses and domains:**

| What | Address | When it changes |
|---|---|---|
| `app` | `<project>.web.app` | its own domain on Hosting — when one is bought |
| `api` | `*.run.app` of its service, CORS to the exact origin of `app` | when there is a domain of its own; how is to be decided then, Cloud Run's domain mapping is in Preview |
| `authDomain` of Firebase Auth | `<project>.firebaseapp.com` | does not change: `app` signs in with a window (R09 app) |
| the main domain and the widgets' domain | none | bought together after О-16, before the public launch (О-16, Т-17); the widgets are stage 4, the hosting of the bundles is Т-17 |

The default site answers at two addresses, `web.app` and `firebaseapp.com`, with the same content. The origin of `app` is only `web.app`: the CORS of `api` and `/deployment.json` name it. The authorized domains of the Firebase project (Т-19) are it and `firebaseapp.com`, as the module's full list (R16).

**The samples page of `canvas`** does not move to the hosting yet. It will move as a separate site of the project with its own origin when the author decides so — the analysis is done, Google is a processor for Hosting (R128 spec; П-9 closed): the sign-out of `app` erases the storage of its origin, and Firebase's logs would then also get the IP addresses of the devices on which children's samples are made (the second 2026-11-08 amendment to R25 spec).

**In the module** (R12; T16):
- `tofu/firebase.tf` — Firebase in the project and the Hosting site with the project's ID, `deletion_policy = "PREVENT"`; the Web App `app`, also `PREVENT`, and the output `app_sign_in` — the block `signIn` for `/deployment.json`: `service`, `apiKey`, `authDomain`, `projectId`, `appId` (R17). The author writes the file, and the review of the pull request sees it (R05);
- `tofu/identities.tf` — `hosting-publish`: the GitHub environment that the output `hosting_environment` names, by default `production-hosting`; on the project the role `hostingPublisher`, Firebase Hosting Admin without creating and deleting sites and without `resourcemanager.projects.list`, which a project's role does not hold — `bootstrap.sh` creates and holds it (the 2026-11-09 amendment and fourth amendment to R12) —, and nothing more: the release reads no API keys (the third 2026-11-09 amendment to R12). This service account does not reach `api`, the configuration or the sign-in settings;
- `tofu/sign_in.tf` — sign-in in production (R16; T27): Identity Platform, `google_identity_platform_config`, and its API, `identitytoolkit.googleapis.com`. The authorized domains are exactly `<project>.firebaseapp.com` and `<project>.web.app`, without `localhost`. Sign-in by email, sign-in by phone and anonymous sign-in are turned off, the activity log is turned off, there are no tenants and no second factor, and only `api` deletes a user, `disabled_user_deletion = true`. The move to Identity Platform cannot be undone, and `destroy` only forgets the resource;
- `tofu/identities.tf` — `api-run` has on the project the role `signInUsers` from `bootstrap.sh`: `firebaseauth.users.get`, `.update` and `.delete`, without the right to change the sign-in settings; `tofu/api.tf` — `API_FIREBASE_PROJECT_ID` on the service and on each job.

**Sign-in** — Firebase Auth with Identity Platform, only through the Google window (R03 api; R09 app; R16):

| What | Who sets it | Where it is kept |
|---|---|---|
| Identity Platform and its settings, the authorized domains | the module, by the configuration's service account | `tofu/sign_in.tf` |
| sign-in through Google, the OAuth client, the consent screen | the operator, once, after the first `apply` | in the project; the client's secret is only with Google |
| the rights of `api` on the sign-in users | `bootstrap.sh` creates the role, the module grants it | `tofu/bootstrap.sh`, `tofu/identities.tf` |

The price is by monthly active users: sign-in through Google is free up to 50,000, then $0.0055 for each (sources 4.7).

**The operator's step: sign-in through Google.** It cannot be done by a program: the API no longer sets up an OAuth client and a consent screen, and the Google provider in the module would keep the client's secret in the state (R16). After the first `apply`, once the module has moved the project to Identity Platform (T23):
1. the project's Firebase console → Authentication → Sign-in method → Add new provider → Google → Enable;
2. the project's public name — "NovaTrail"; the support email — the one users will see on the consent screen, the operator's address. If the console asks for a Web client ID and a Web client secret, create a client `Web application` in Google Cloud → APIs & Services → Credentials, with the Authorized redirect URI `https://<project>.firebaseapp.com/__/auth/handler` — the sign-in handler on `authDomain` (sources 4.7) —, and paste the secret only into this form: it goes neither into the repository, nor into variables, nor into GitHub's secrets;
3. Google Auth Platform: Audience — External and In production: in the mode Testing only the named test users sign in, no more than 100 (sources 4.7). Scopes — only the default ones, email, profile and openid; they need no app verification. The user will see the name and the logo after brand verification, and before it the address `<project>.firebaseapp.com`; brand verification comes with a domain of its own, after О-16;
4. do not touch the authorized domains in the console: the module holds them, and the next `apply` removes one added by hand;
5. `tofu plan` after the step shows no changes: the step changes the sign-in provider, not the settings the module holds.

On the project `novatrail` (T23) the console at step 1 created the OAuth client itself, "auto created by Google Service", and asked for no ID or secret; the second run of `Deploy` after the provider was turned on says "No changes" (the 2026-11-09 amendment to R16). The API does not read the Audience of step 3: the author confirmed External and In production with a screenshot of the console.

Self-hosting does the same step in its own project.

**The first release**, 2026-11-12, went through as `hosting-publish` with its custom role `hostingPublisher`, though Firebase writes that custom roles do not work for Hosting (sources 4.5), and the check after the release accepted the site's responses, `/NOTICE` and `/LICENSE` among them (T24). The checks after the release (T42; the second 2026-11-12 amendment to R17):
- production accepts `!/@(assets)/**`, and no explicit list of SPA paths is needed;
- an unknown file under `/assets/` gives 404 with Hosting's own page and the headers of the paths outside `/assets/**`;
- Hosting sets its own HSTS — `max-age=31556926; includeSubDomains; preload`;
- beyond the version Hosting sends `etag`, `last-modified`, `vary`, `alt-svc` and cache headers, and `Cross-Origin-Opener-Policy` nowhere;
- Hosting serves the reserved paths `/__/auth/*` — Firebase's sign-in pages — without the version's headers: without CSP and without `nosniff`;
- the sign-in window opens under another Google account too: that is how the second learner signed in (the 2026-11-12 amendment to R16).

### 3.4. Logs and traces

The platform's logs are without direct identifiers and IP addresses (privacy 4 spec). How `infra` holds to this is R07.

**Sinks and filters:**

| Sink | Where to | Exclusion filter |
|---|---|---|
| `_Default` | its own log bucket in `us-east4`, 30 days (R04) | `LOG_ID("run.googleapis.com/requests")` — Cloud Run's request logs; and also Data Access, the requests of Identity Platform and the requests of Hosting — the rows below |
| `_Required` | the bucket `_Required` in `global`, 400 days | does not change; gets no request logs |
| any sink the project sets up | — | the same as `_Default`'s |

The filter applies to an entry that the Logging API or the Telemetry API has already accepted: the IP address reaches Google as a processor, but is not stored in the bucket. T42 checked the log's name in the filter: with 135 requests to `api` since the service started, 2026-11-12, the bucket has not one entry with `httpRequest` — only Cloud Run's `stdout`, `stderr` and `varlog/system` (the 2026-11-12 amendment to R07).

**The inventory of logs and traces:**

| What | What is in it | Where and how long |
|---|---|---|
| Cloud Run's request logs, of the service `api` | `httpRequest`: the client's IP address, user agent | excluded — not stored |
| the logs of the container `api` and of its jobs | events of `api` without identifiers and addresses; for the jobs, counters (R26 api; T28 api) | the bucket in `us-east4`, 30 days |
| Cloud Run's system logs | platform events about revisions and jobs | the bucket in `us-east4`, 30 days |
| Cloud Scheduler's log of its attempts, `cloudscheduler.googleapis.com/executions` | for each call of a job by the clock, `AttemptStarted` and `AttemptFinished`: the job, the address of its run, the target type, the scheduled time, Google's text `debugInfo` and the HTTP status; no address or identifier of a person (the 2026-11-13 amendment to R07) | the bucket in `us-east4`, 30 days |
| Admin Activity | `callerIp` and the caller's email — of the operator and of CI when they edit resources. There are no Identity Platform entries from learners: nobody calls `SignUp` in the project, and the sign-in through the Google window, which creates a user, leaves no entry; T42 did not go through the entries of other services (T42) | `_Required`, `global`, 400 days (Д3); cannot be excluded |
| System Event | Google's own actions with the project's resources; among them each run of a job, `/Jobs.RunJob`, which names no service account of the project (T43) | `_Required`, `global`, 400 days |
| Policy Denied | `callerIp` and the email of whoever a policy refused | the bucket in `us-east4`, 30 days |
| Data Access audit | would hold `callerIp` | not turned on, and excluded in each sink (the 2026-11-09 amendment to R07) |
| the activity log of Identity Platform | would hold every sign-in request | turned off by the module, `monitoring.request_logging` (R16), and excluded in each sink (the 2026-11-09 amendment to R07) |
| the export of Firebase Hosting's logs | would hold `remoteIp` | not turned on (R06), and excluded in each sink (the second 2026-11-09 amendment to R07) |
| the logs of Firebase Auth and Firebase Hosting at Firebase itself | IP addresses | at Firebase: Auth "a few weeks", Hosting "a few months" (П-9) |
| traces | Cloud Run itself, on a part of the requests | `_Trace` in `us-east4`; Cloud Trace API cannot be turned off while Cloud Scheduler needs it (the third 2026-11-09 amendment to R07); the attributes with the first trace: from the service's start, 2026-11-12, to 2026-11-13 there have been no traces (T42, T43; Д17) |

Cloud Run jobs have no request logs: only services write them.

**For investigating failures:**
- the log of `api` — the method, the code, the cause of a refusal and the time of each call, without the body, the headers and the address (architecture 3.9 api);
- Cloud Run's built-in metrics in Cloud Monitoring — the number of requests, latencies, instances;
- Error Reporting — by the logs of `api` that are stored.

The project sets up no log-based metrics of its own, where the address would become a label: they are counted on excluded entries too. The alerts are on built-in metrics, `tofu/alerts.tf` (T14): load — requests to `api` per minute above `load_alert_per_minute`, 300 by default —, and errors — responses of class 5xx per minute above `error_alert_per_minute`, 1 by default —, both averaged over five minutes, by `run.googleapis.com/request_count`; the third — a scheduled run of a job that failed, by `run.googleapis.com/job/completed_execution_count` with `result` not `succeeded` (the 2026-11-10 amendment to R07); it exists only while there are the service and jobs with `schedule`; the fourth — a job by the clock with no completed execution in the last 25 hours, by the same metric with any `result`, summed over 90 000 seconds, the longest window a condition may roll, each job in a condition of its own, with no data taken as the condition met: a day with no run writes no point (the third 2026-11-13 amendment to R07; sources 3.14). It sees a run that did not start, whatever the cause — the rights of `api-scheduler`, the job's address, a paused schedule, Cloud Scheduler itself —, and it holds only while a job by the clock runs every day and within the hour: `api_jobs` refuses a schedule whose day of the month, month and day of the week are not all `*`, and a timeout over 3000s. A job made, renamed or added has no data before its first run, and the fourth may mail before it. The email goes to the operator, whose address comes from the environment, `TF_VAR_operator_email`; without an address there is neither a channel nor alerts. The first two write when the condition began and when it ended, the third and the fourth only when it began: Cloud Monitoring also closes an incident with no data, and a mail of that would read as a run. The email's text leads to Cloud Run's metrics, for the third to the job's runs, for the fourth to Cloud Scheduler's log of its attempts and to the job's runs, and to the log of `api`, not to the request logs: there are none. Cloud Run's metrics are free, and Google charges for the alerts themselves from September 1, 2027: $0.35 a month for each metric in a condition — here one in each of the first three and one for each job by the clock in the fourth — and $0.50 per million points that a condition's query returns (sources 5.4).

**Traces:** the platform has none of its own, and Cloud Run traces a part of the requests itself. Cloud Trace API is enabled: Google enables it in a new project, and Cloud Scheduler, which depends on it, does not let it be turned off (the third 2026-11-09 amendment to R07; T23). The place of `_Trace` — `us-east4` — is set before any trace (R04 with its 2026-11-09 amendment).

**In the module** — `tofu/logging.tf` (T13):
- the bucket `default-<region>`, `log_retention_days` — 30 by default, from 1 to 3650; `deletion_policy = "PREVENT"`: the module does not delete the bucket — neither by `destroy` nor by a change of region —, or else `_Default`, which `destroy` does not touch, would write to a bucket being deleted;
- the module takes over the sink `_Default`: the provider updates a sink that already exists, and on deletion does not touch `_Default`. The former filter word for word, the destination the region's bucket, and the exclusions as blocks `exclusions` of the sink itself: `cloud-run-request-logs`, `data-access-audit`, `identity-platform-requests` and `firebase-hosting-requests`;
- the project's sinks are listed in one list, `local.sinks`, and each gets the same exclusions; a test holds each sink of this list, and `tf-check` lets no sink or exclusion declared outside it through;
- the place of `_Trace` — `google_observability_project_settings` with the region's `default_storage_location`: the provider sets the setting through PATCH, and a second `apply` repeats it harmlessly, while the bucket `_Trace` it creates through POST, which refuses if the bucket already exists, and it cannot delete it (the 2026-11-09 amendment to R04; sources 2.2);
- Data Access audit and the activity log of Identity Platform are off by Google's default, the module does not turn them on, and the sink excludes them (the 2026-11-09 amendment to R07). The activity log is besides turned off explicitly in `tofu/sign_in.tf` (R16).

**Checked after the first deployment (T42):**
- the name of the request log in the filter;
- that nobody calls `SignUp` in the project, and that Admin Activity has no Identity Platform entries from learners;
- the values of the label `result` — `succeeded` and `failed`, as the alert expects (the 2026-11-12 amendment to R07).

**Checked on the first scheduled run (T43)**, 2026-11-13:
- `api-scheduler` called `sweep` at 09:00 UTC, the execution passed, and `completed_execution_count` wrote `succeeded`;
- Cloud Scheduler's log of its attempts — its name and fields, in the inventory above; Cloud Scheduler has no metric of its own, and a failed call is not retried: `retryConfig` is empty (the 2026-11-13 amendment to R07).

**Not checked:**
- the attributes of the traces Cloud Run writes itself: there are no traces yet (Д17);
- what Cloud Scheduler writes for a failed attempt: none has failed yet; the alert on a run that did not happen does not read it (the third 2026-11-13 amendment to R07);
- that the window of 25 hours does not open the alert on a run that did not happen each day, and that a missed day does: the project, after T49.

### 3.5. Self-hosting and the local run

Self-hosting is a copy of the platform that an operator deploys on their own side (product 3 spec; architecture 3.11 spec). From the decisions of E1 and E3 it follows for it:
- **the same release files:** the operator builds a service's image on their own side from the same binary and by the same `Dockerfile`, after `release-verify`, and keeps it in their own private registry (R105, R106 spec);
- **the same directory `deploy/`** — its own list, its own values of `/deployment.json` and its own facts file; the rung `full` (R05; R25 api);
- **the same checks and steps of the deployment** — the fork's workflow, and without GitHub Actions the same recipes by hand, in its own project (R05; R21);
- **the hosting of the build of `app`** — in code, Firebase Hosting on the copy's project. Another hosting is outside the code and the guide: with its own headers it suits, and without them the protection is weaker (R06; Т-17);
- **the logs** — the same exclusion of the request logs and the same rules for metrics and traces (R07);
- **sign-in** — the same module and the same operator's step "Sign-in through Google" (R16; section 3.3);
- **the region** — the copy has its own: R109 spec and R04 are about the platform.

There is no cloud in the code other than Google Cloud. `bootstrap.sh` and the root module's variables already take the copy's values from its `production.auto.tfvars` and `backend.hcl`, and the module puts the copy's own Firebase project on the copy's project. The operator's guide is [SELF-HOSTING.md](../SELF-HOSTING.md), in English: the main path is a fork with GitHub Actions, and without them the same recipes with the operator's rights, without the constraints of `infra-config` (R21).

**The local run** (R22; T31) — the platform from source on one machine: `api` and `app` each run in their own devcontainer and by their own recipes, and `infra` gives only a description — "Running the whole platform on one machine" [SELF-HOSTING.md](../SELF-HOSTING.md#12-running-the-whole-platform-on-one-machine). `infra` gives it no Firebase project, compose, emulators or list; why is R22. `api` in its `/deployment.json` is the origin of `app` itself on loopback, `http://127.0.0.1:<app port>`, by the rule `deployment.loopback` (R85 spec), and the proxy of the server of `app` leads the paths of `api`: the lower layer of the build's CSP does not let in another origin over `http` (the 2026-11-11 amendment to R22; row Д177 of RUN.md of `spec`). A Firebase project is needed — the format requires `signIn` and does not know an emulator's fields —, and it is the dev project of `api` (the row "sign-in service" of table 3.12 spec). The container of `app` is also on the network `novatrail-api`, and the proxy goes to the address of the container `api` in it, `NOVATRAIL_API=http://<address>:8080`, which `hostname -i` gives in the container `api`: it has no name on the network until T115 of `spec` (row Д195 of RUN.md of `spec`). The port of `app` is 5173, fixed for both servers, and VS Code forwards it to the same 5173 of the host. The description is checked against the first build of `app` with `api` that the author ran from source on 2026-11-12 by their recipes — T30 of `app` and T42 of `api` —, and against the code of `app` on `main` 55ab358 and `api` v0.1.27 (the 2026-11-12 amendment to R22). The README of `api` sets `API_APP_ORIGIN`, and architecture 3.7 app does not; both work — the row «в реестр spec» В27 of RUN.md.

**What a copy sets itself, and what is shared** (T29). The inventory is by the code of the module, `bootstrap.sh`, the checks and the deployment as of 2026-11-12. The tests on a copy's values are `tofu/tests/copy.tftest.hcl`, the copy test in `tofu/tests/bootstrap.test.mjs`, `tools/deploy/test/api.test.mjs` and `app.test.mjs`. They also hold that neither the project ID `novatrail`, nor the region `us-east4`, nor the numbers of `altnovatrail` reach a copy's resources and calls. The name "NovaTrail" reaches it on purpose: it names the project that `bootstrap.sh` makes, and the label of Hosting's versions, `novatrail-infra` — the row "names" of the table.

| What | Where a copy gets it | Own or shared |
|---|---|---|
| the project, the region, the budget and the currency | `production.auto.tfvars` | own |
| the state bucket and the prefix | `backend.hcl` | own |
| the CI service account and the pool's provider for the workflow | `tofu/ci.env`, the two lines that `bootstrap.sh` prints | own |
| the billing account, the operator's address | `TF_VAR_billing_account`, `TF_VAR_operator_email` | own |
| the CI pool, the repository and its numbers | `workload_identity_pool_id`, `github_oidc_subject_prefix` | own |
| the GitHub environments of the deployment and of the publishing | `deploy_environment`, `hosting_environment`, and the workflow takes them from the module's outputs; `production-config` is a constant | own (the 2026-11-10 amendment to R18) |
| the Hosting site and the sign-in domains | the project ID: `<project>.web.app`, `<project>.firebaseapp.com`; `web.app` is also the origin of `app` in the service's `API_APP_ORIGIN` | own |
| the image of `api` and the service | `api_image` — an image from the copy's registry, `api_serving` | own |
| the databases `api` and `openfga` | its own Neon project; four connection strings as versions of the secrets `api-migrate-database-url`, `api-migrate-openfga-database-url`, `api-database-url` and `api-openfga-database-url`, by the operator's hand | own |
| the countries and the invite codes | `api countries allow` and `api invite` — by the operator's hand, with the release's binary (R25) | own |
| the settings with defaults | `api_service_name` and `api_jobs` — the names of the service, its service accounts, the jobs and their secrets come from them; the periods of the logs and the images, the alerts' thresholds, the service's size and limits — `tofu/variables.tf` | own, and the defaults shared |
| `api` and `signIn` in `/deployment.json` | the outputs `api_origin` — the address of the copy's service — and `app_sign_in` of the copy's module | own |
| eval | `eval_github_subject_prefixes`, empty by default: no secrets, no pool | the platform's only |
| the operator's bucket and the bucket of the scans, and who holds them | `operator_bucket` and `consent_forms_bucket` in `production.auto.tfvars`; the addresses of the organizers and of the operator in `BOOTSTRAP_MEASURE_ORGANIZER`, `BOOTSTRAP_EVAL_SET_ORGANIZER` and `BOOTSTRAP_OPERATOR`, each `none` for no one (R28) | own |
| the list, `/deployment.json`, the facts | the copy's directory `deploy/` | own (Т-20; R96 spec) |
| the release files of `api` and `app` | the releases of `altnovatrail`, `release-verify` | shared (R105, R106 spec) |
| the format of `/deployment.json` | the submodule's `spec/deployment/` | shared (R85 spec) |
| names | the constants of the module and of `bootstrap.sh`: `infra-config`, `hosting-publish`, `upload-measure`, `upload-eval-set`, the prefixes of the buckets, the secrets `api-admission-facts`, `api-database-url` and `api-openfga-database-url`, the registry `images`, the container `api` and the facts volume `admission-facts` at the path `/etc/api/admission`, the custom roles; the project's name "NovaTrail" and the label `novatrail-infra`. | shared: they are inside the copy's project |
| CI's sign-in | GitHub's Workload Identity Federation; without GitHub Actions, the same recipes by hand (T30) | shared |

### 3.6. The tool: OpenTofu

OpenTofu, the open fork of Terraform, at an exact version, describes the infrastructure: the code is in HCL on the model of `infra/` of canvas-api, and the tool and the commands are `tofu` (the 2026-11-08 amendment to R11 spec; Т-29 closed). Sources: sources 5.1 and 5.2.

- **Why not Terraform:** since version 1.6.0 it comes out under BUSL 1.1, and the 2026-10-22 amendment to R12 spec admits free terms only for a tool without which the platform can be deployed. Terraform 1.5.7, the last under MPL 2.0, has no generally available `terraform test` and no `mock_provider`, and is no longer developed.
- **What is known as of 2026-11-08 (T09):** OpenTofu v1.13.9 of 2026-11-05 is the latest release, under MPL 2.0; the sha256 sums of the archives `linux_amd64` and `linux_arm64` and the signature of the sums file are checked; the providers `hashicorp/google` and `hashicorp/google-beta` are in the OpenTofu registry, up to 8.10.0, under MPL 2.0; `tofu test` supports `mock_provider`, `override_resource` and `command = plan`, on which the tests of canvas-api stand.
- **What changes against canvas-api:** `tofu` and `tofu test` instead of `terraform`; the providers come from the OpenTofu registry, and the sums of `.terraform.lock.hcl` are its; the tool is in the devcontainer's stage `toolchain` by the version's `ARG` and the sha256 sums (R34 spec; R09), not on the runner, and CI calls it through `spec/tools/toolchain/toolchain.sh` (R30 spec). The module's HCL code and the tests carry over.
- **Installation** (R09): v1.13.9 in the stage `toolchain`; the archive is checked against its sum before unpacking, and the signature of the sums file is checked with `gpg` by hand at each raise of the version. The CI job `OpenTofu` checks `tofu version -json` against the `ARG`.
- **The root module** (R10): `tofu/` — `required_version = "1.13.9"`, the providers `google` and `google-beta` 8.10.0, a lock file with the hashes of all platforms of their release, a partial backend `gcs`, the platform's values in `tofu/production.auto.tfvars` (T23), the APIs by R04–R07; the module does not enable Cloud Trace, but Google enables it, and it stays (the third 2026-11-09 amendment to R07). The tests are `tofu test` on `mock_provider` with `command = plan`, as at canvas-api, and they run under `tofu`. Dependabot raises the providers, the ecosystem `opentofu`, in one group; OpenTofu is raised by hand, by R09.
- **The one-time step** (R13): `tofu/bootstrap.sh` creates what the configuration signs in through — the project, the state bucket, the pool and the provider `github`, which admits only the tokens of `infra` by numeric IDs, the service account `infra-config` for the jobs of the environment `production-config`, and the module's custom roles. If `production.auto.tfvars` names eval repositories, the script also makes the pool `github-eval` with a provider by the condition of R120 spec — the job of the environment `eval` of these repositories, not Dependabot; `infra-config` has no rights on pools, because IAM conditions do not narrow pools (R20). It reads the values from `production.auto.tfvars` and `backend.hcl` in `tofu/`, and the author runs it (T23). The tests are on a stub `gcloud`, the check of its condition against the module's roles in `tofu test`, and `_tf-roles` in `tf-check`.
- **ShellCheck** (the 2026-11-09 amendment to R09): v0.11.0 in the stage `toolchain`, by an `ARG` and sha256 sums; the job `OpenTofu` runs it on `bootstrap.sh`, `tools/deploy/*.sh` and `tools/ci/*.sh`.
- **actionlint** (the second 2026-11-09 amendment to R09): v1.7.12 in the stage `toolchain`, by an `ARG` and sha256 sums; the job `OpenTofu` runs it on `.github/workflows` with the stage's ShellCheck.
- **License:** OpenTofu and both providers — MPL 2.0, the named exceptions of R09 and R10, ShellCheck — GPL-3.0, the named exception of the 2026-11-09 amendment to R09 (R12 spec), and actionlint — MIT.
- **Not checked:** the first pull request of Dependabot `opentofu` — whether it rebuilds the lock file for all platforms, as its code promises. The first `apply` created the resources of the parts T13–T16 without a single refusal (T23), except the Cloud Run service and jobs of T15: they do not exist while `api_image` names no image, and the service also while `api_serving` is not set. Under `tofu` they first went through on 2026-11-12, without a refusal: the jobs with `api_image`, the service with `api_serving` (T24).
- **Tasks:** T11 — the tool in the devcontainer and its own check in CI; T12 — the root module; T13–T16 — its parts; T17 — `bootstrap.sh`; T23 — its run and the first `apply`.

### 3.7. The operator's bucket

The private Cloud Storage bucket of R125 spec: the measurement organizer and the eval-set organizer get the files of the samples page and the scans of their forms into it by an upload link. Beside it is a bucket of its own for the scans of the parents' consent forms that `api` puts there from `app` (R116, R124–R126, R136 spec). What was decided and why is R28, with the 2026-11-13 amendment to R13; the sources are sources 7.2 and 10.1–10.8. `tofu/bootstrap.sh` makes the buckets and their access (T46), the module names the scans' bucket and `api`'s prefix to `api` (T47), `tools/organizer/organizer.mjs` is the organizer's tool (T54), and T49 makes them on the project and checks them there (Д11).

**Who makes them.** `tofu/bootstrap.sh`, with the operator's rights, as the pools and the custom roles (R13): the two buckets and their settings, the lifecycle rules, the custom roles, the upload service accounts and the whole IAM policy of each bucket. The module grants nothing in them and only names the scans' bucket and the prefix `consent-forms/` to the service `api`, to `sweep` and to `check`, as `API_CONSENT_FORMS_BUCKET` and `API_CONSENT_FORMS_PREFIX`; a test holds the prefix to the one of the script's condition (the 2026-11-13 amendment to R11; the second 2026-11-13 amendment to R28). A rerun of the script brings the settings, the rules and the policies back where they have drifted, as for `infra-config`.

**What CI can do all the same** (R28; row В33):
- `roles/firebase.admin` of `infra-config` holds `storage.buckets.*` and `storage.objects.*` on the project (sources 10.6): CI reads, writes and erases any object of either bucket, and can change its settings, rules and policy;
- through `roles/run.admin` and `roles/iam.serviceAccountUser` CI can run a Cloud Run job as any service account of the project — `api-run`, an upload service account;
- a change of a bucket's settings or policy is Admin Activity in `_Required`; a read of an object is Data Access, which is off, so no log shows it.

"Without CI" of R125 spec therefore does not hold. CI's door is the environment `production-config`, where only `main` runs, after a review (R13, R18).

**The values.**
- the buckets' names — `operator_bucket` and `consent_forms_bucket` in `tofu/production.auto.tfvars`, `<project>-operator` and `<project>-consent-forms` for `novatrail`: the script and the module read them from the same place. The module takes both as variables, required, of the form the script takes and different, so that a plan reads the file without a warning; it uses only the scans' bucket, which it names to `api`;
- the addresses of the people — from the environment, never from a file, each from a variable of its own: the measurement organizer `BOOTSTRAP_MEASURE_ORGANIZER`, the eval-set organizer `BOOTSTRAP_EVAL_SET_ORGANIZER`, the operator `BOOTSTRAP_OPERATOR`. A variable that is not set is a refusal before the first call of `gcloud`: a rerun from a shell that lacks one would otherwise take a person's access away. The value `none` means no binding for that person. The alerts' `TF_VAR_operator_email` is not reused: it may be a list, not a Google account. Today all three are the author (R139 spec).

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

The owners' binding is one of those Cloud Storage gives a new bucket, and the only one the script keeps: the role Owner holds no `storage.buckets.get`, `update`, `getIamPolicy` or `setIamPolicy` of its own, only through it (sources 10.9), so a policy without it shuts out the operator who runs the script — the first run on the project did so (T49). The owners may grant themselves any read through it, as they may anything on the project. The other bindings of a new bucket — `legacyBucketOwner` and `legacyObjectOwner` of the project's editors, `legacyObjectOwner` of its owners, `legacyBucketReader` and `legacyObjectReader` of its viewers — the script takes back (the fourth 2026-11-13 amendment to R28).

Beyond the buckets: the measurement organizer holds `roles/iam.serviceAccountTokenCreator` on `upload-measure` alone, the eval-set organizer on `upload-eval-set` alone. The policy of each upload service account and of each bucket holds only what the script names: anything else it takes back at each run. The binding of `api-run` exists only once the module has made `api-run`; without it the script makes the rest and says so, and the operator runs it again after the first `apply` of a new copy. `api` needs no more: it puts each scan under a new name and erases by a name from its database, and an insert that overwrites nothing needs no `storage.objects.delete` (sources 10.2, 10.5).

**The upload link** (sources 10.1). A V4 POST policy, signed by IAM's `signBlob` as the organizer's upload service account, with no key: without a key of the service account a signature is valid at most 12 hours, so the policy expires no later than 12 hours from the session, not a day as R125 and R126 spec say — row В30 of table 3 of [RUN.md](../RUN.md). The organizer's tool, `tools/organizer/organizer.mjs` (T54; the third 2026-11-13 amendment to R28; sources 10.8):
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

The organizer gives the page to the adult, who opens it in a browser and sends the files. Since an upload service account cannot overwrite, a second sending of the same form fails instead of replacing the file. A screen of the samples page of `canvas` that takes the policy from the fragment of a link would replace the page — row В30.

**The lifecycle** of `<project>-operator` (sources 10.3). Two years are at least 730 days and five years at most 1827; the link adds up to half a day to the session; Google bounds no lag of a rule's action. An `age` counts from the object's creation, and a rewrite creates the object anew, so what the organizer may rewrite is erased by its Custom-Time:

| Prefixes | Rule | Custom-Time set by the organizer | Period it keeps |
|---|---|---|---|
| `measure/samples/`, `child/samples/` | `age` 728 | — | 2 years from the session (R124, R125 spec); nobody rewrites a sample |
| `measure/records/`, `child/records/`, `measure/reports/`, `child/reports/` | `daysSinceCustomTime` 728 | the session of the record, or of the earliest sample the report names | erased with the samples (R124 spec) |
| `measure/forms/`, `child/forms/` | `daysSinceCustomTime` 1827 | the session plus 730 days, of the last session under the form; moved forward by a new session; on a withdrawal the form is rewritten with the day of the erasure | 5 years after its samples are erased (R124, R125 spec) |
| `eval-set/forms/` | `age` 364, and `daysSinceCustomTime` 364: two rules, and either erases | the signature, on the record beside the form | 12 months from the signature, when no sample was contributed (R126 spec) |
| `eval-set/contributed-forms/` | none | — | as long as a sample is published (R126 spec) |
| `eval-set/samples/` | none | — | not set by R126 spec — row В32 |

A Custom-Time cannot decrease, but a rewrite of the object resets it. A form without one is never erased by the rule, so the tool sets it and lists the forms without it. `<project>-consent-forms` has no rule: the period of a scan is the consent and 5 years, and `sweep` erases it (R116, R136 spec).

**Logs.** Data Access audit of Cloud Storage is off and every sink excludes it (R07): an upload's entry would hold the address of the adult who sends. So no log shows who read, wrote or erased an object, and the lifecycle's erasures are not logged at all (sources 10.4). The buckets' settings and policies are Admin Activity, in `_Required`. BREACH.md, part 1, gets the buckets' rows from T46 (R27).

**The price** (sources 7.2). Standard in `us-east4` — $0.023 per GiB a month, class A operations $0.005 per thousand, class B $0.0004; `us-east4` has no free tier. Scans and sample files weigh megabytes: cents a month.

**What T49 checks on the project**, since the documentation does not say:
- the policy is refused after 12 hours, and serves several uploads within them;
- a Custom-Time in the future is accepted;
- `DELETE` of an absent object without `storage.objects.get` answers 404, which `sweep` takes for "erased already" (Д29 `api`);
- `api-run` and an upload service account cannot read an object, nor an organizer another's prefix or the scans;
- that a page of the tool uploads: Cloud Storage takes the expiration in the extended format and the credential's location `auto`, and the fields `name`, `customTime`, `timeCreated` and `metadata` of `gcloud storage objects list` and `describe` with `--raw` are the ones the tool reads; that `withdraw` sets a Custom-Time earlier than the form had (sources 10.8);
- that `gcloud storage buckets get-iam-policy` reads a policy in version 3, with its conditions, so that a run again of the script grants nothing anew, that `gcloud storage buckets describe --format='value(location)'` prints the place the script compares with the region, and `gcloud storage buckets list --format='value(name)'` the names it finds its buckets by among the project's (sources 10.7).

## 4. Sources

The records of external facts are in [sources.md](sources.md), a record per source, and a claim of this file cites its record: `sources 1.1` (RULES.md, The bar; R26). The section stays a pointer: the decision log and the archives `docs/plan/` cite it, and they are not rewritten. An item of this section that they name is the record of [sources.md](sources.md) with the same heading at commit a2db250, where the headings are still in Russian, and the record's number is the same.
