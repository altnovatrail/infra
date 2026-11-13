# What to do in a data breach

This is the operator's written procedure for a breach of learners' data. It says what counts as a breach, how to cut the access, where to look, whom to tell and by when, and what to write down. Why it is built this way is [R27](docs/decisions.md), and every fact about a law or a provider below cites its record in [docs/sources.md](docs/sources.md).

It has two parts:

- **Part 1** fits any copy of the platform, the platform's own project `novatrail` among them: the platform's data, its access and its logs are the same in every copy. If you run a copy ([SELF-HOSTING.md](SELF-HOSTING.md)), read your own project, region and Neon project wherever this part names the platform's.
- **Part 2** is the operator of `novatrail`, ALT EdTech LLC, a Texas company (privacy 3.4 spec): the laws that bind it and their deadlines. The operator of a copy writes their own part 2, from the laws that bind them. Part 2 here is no legal advice to anyone else.

**Who keeps it.** The operator keeps it and decides by it. The operator reviews it:

- in the closing task of every epic of `infra` (RUN.md);
- after every breach;
- before a new group of learners: the first child, a new country (`api countries allow`), the first learner from the EU, the EEA or the United Kingdom;
- before the platform has 250 learners, since the attorney general's threshold counts Texas residents and the platform does not know a learner's state (section 9);
- when spec has read the breach laws of the other states (section 10).

A task of `infra` that changes what part 1 names keeps part 1 true in the same change: a place of learners' data, a secret, a right, a log.

> **Status, 2026-11-13.** Nobody has gone through it in a real breach. The adults the operator let in by a code of `api invite` learn on the platform, and no children do (R25). The operator's bucket and the bucket of the scans are in `tofu/bootstrap.sh`, but not made on the project yet (Д11 of [DEBT.md](DEBT.md)).

## Part 1. Any copy

### 1. What counts as a breach

A breach is when anyone without the right has read, copied, changed or erased a learner's data, or could have. A secret that opens the data counts too, if it has been where it should not be: a connection string or a key in a chat, a commit, a screenshot, a log or on a lost device. When in doubt, treat it as a breach and open a record (section 7). A record may end with "not a breach".

You learn of it from:

- a letter from Google about the project's security. Google sends these to the project's Essential Contacts, category Security, and without a contact to a fallback contact chosen by IAM role (sources 5.7). This repository sets no contact (R27), and nobody has checked who on the project gets that letter;
- a letter from Neon, from Firebase or from GitHub, about your account or the repository;
- entries of Admin Activity that neither you nor CI made (section 4);
- the alert emails of `tofu/alerts.tf`. A burst of requests or of errors is not a breach in itself, but it is a reason to look;
- a learner, a researcher or anyone else who writes to you.

### 2. Where learners' data is and what opens it

| Where | What of learners | What opens it |
|---|---|---|
| Neon, the project's branch `production`: the database `api` and the store of OpenFGA, the database `openfga`, with Neon's history window, which keeps earlier states for restores | the account — its ID, the sign-in service's UID, the owner's statement that they are an adult, the PIN's hash —, the consents, the profiles, the attempts, the learner model (sources 3.12) | the passwords of the Neon roles, inside four connection strings; the operator's Neon account |
| Secret Manager: `api-database-url` and `api-openfga-database-url`, the pooler's strings, and `api-migrate-database-url` and `api-migrate-openfga-database-url`, the direct ones | the four connection strings | `api-run`, the account the service and every job of `api` run as; `api-deploy`, which may run the jobs as `api-run`, from the GitHub environment `production` alone (`tofu/identities.tf`); the operator's own Google account, in Cloud Shell; `infra-config`, which CI applies the configuration as, administers Secret Manager (`tofu/bootstrap.sh`) |
| Firebase Authentication, in the same project | the email of each owner's Google account, by UID | `api-run`, by the role `signInUsers`: it reads, updates and deletes users; the operator, in the Firebase console |
| the operator's bucket, `operator_bucket` of `tofu/production.auto.tfvars` (`novatrail-operator` on the platform), in the project's region ([architecture 3.7](docs/architecture.md#37-the-operators-bucket)) | the files of the samples page — samples of handwriting of adults and children —, the scans of their forms, which carry names and signatures, the organizers' records and the runner's reports | the measurement organizer, who reads, writes and erases under `measure/` and `child/`, and the eval-set organizer, under `eval-set/`, each by their Google account; both list the names in the whole bucket; `upload-measure` and `upload-eval-set`, which only create objects under the upload prefixes: an upload page signed as one of them lets whoever holds it upload, not read, for at most 12 hours; `infra-config`, which reads, writes and erases every object and may change the bucket's policy through `roles/firebase.admin`, and may run a Cloud Run job as any service account of the project (R28); the project's owners |
| the bucket of the scans, `consent_forms_bucket` (`novatrail-consent-forms`), beside it | the scans of the parents' consent forms that `api` takes from `app`, under `consent-forms/` | `api-run`, which creates and erases them and reads none; the operator, who reads and lists them by their Google account; `infra-config`, as for the operator's bucket; the project's owners |
| the platform's logs | no identifiers, no IP addresses and no content: the request logs are excluded, and the log of `api` holds neither email nor UID (R07; sources 3.12) | — |
| Firebase's own logs | IP addresses: Firebase Auth keeps them a few weeks, Firebase Hosting a few months (П-9) | Google |

A learner's work on their own device is the device's, not the platform's.

### 3. Cut the access

Do only the steps that match what leaked, and write each into the record with its time.

**A connection string leaked, or you cannot rule it out.** All four strings carry a password of a Neon role, and the steps go in this order:

1. In the Neon console, reset the password of the role the string names: on the branch `production`, and on every other branch where the role is. A reset takes effect at once, it is per branch, and the old password stops working "on the next connection" (sources 3.12). From now on `api` cannot open a new connection until step 4.
2. End the sessions already open. A reset does not end them, and a restart of the compute does: "Restarting a compute interrupts any connections currently using the compute" — the console's Postgres database → Computes → Restart compute (sources 3.12). Restart the compute of each branch from step 1.
3. Put the new string into each secret whose string names this role, as a new version, typed and never shown, as at the first deployment (R25). A role is in two secrets — the pooler's string and the direct one, `api-migrate-…` —, and each gets its own string from the Neon console's Connect window:

   ```bash
   read -rs CONN && printf '%s' "$CONN" | gcloud secrets versions add <secret> --data-file=- && unset CONN
   ```

   The string keeps `sslmode=verify-full`.
4. Roll out a new revision of `api` on the same image. The service reads its secrets as environment variables, and those are resolved when an instance starts (sources 3.12). `just deploy-api-facts` with the configuration's outputs does it: a new version of the facts and a revision on the image that takes the traffic (R15; SELF-HOSTING.md, [section 10](SELF-HOSTING.md#10-without-github-actions)). A job reads its secrets anew at each run.
5. Disable the old versions: `gcloud secrets versions disable <version> --secret=<secret>`. A disabled version cannot be read, and it can be enabled again (sources 3.12).

**A right was abused, or an account of the platform acted where it should not.** Read every policy, not only the grant you noticed: the module adds its grants one member at a time (`*_iam_member` in `tofu/`), so an apply leaves alone a grant it does not name. Read them:

```bash
gcloud projects get-iam-policy <project>
gcloud secrets get-iam-policy <secret>                      # each secret of section 2
gcloud iam service-accounts get-iam-policy <account>        # api-run, api-deploy, infra-config
```

Remove what is not in `tofu/` by hand at once — `gcloud projects remove-iam-policy-binding`, or the console. If the grant is in `tofu/`, remove it there too, or the next apply puts it back. Admin Activity shows who made each grant (section 4). To stop CI from deploying meanwhile, `gh workflow disable deploy.yml`.

**A person's access to a bucket of section 2 must end** — an organizer's or the operator's account was taken, or a person no longer has the role. `tofu/bootstrap.sh` holds each bucket's whole policy and the policy of each upload service account, so run it, as in [SELF-HOSTING.md, section 4](SELF-HOSTING.md#4-bootstrap), with that person's variable set to `none`: `BOOTSTRAP_MEASURE_ORGANIZER`, `BOOTSTRAP_EVAL_SET_ORGANIZER` or `BOOTSTRAP_OPERATOR`. It takes back their bindings in the buckets and their right to sign as their upload service account, and whatever else the policies hold that the script does not name. Read the policies after it:

```bash
gcloud storage buckets get-iam-policy gs://<operator_bucket>
gcloud storage buckets get-iam-policy gs://<consent_forms_bucket>
gcloud iam service-accounts get-iam-policy upload-measure@<project>.iam.gserviceaccount.com
gcloud iam service-accounts get-iam-policy upload-eval-set@<project>.iam.gserviceaccount.com
```

An upload page that reached the wrong person can only add files, and its policy expires at most 12 hours after it was signed (R28). To stop it sooner, take the upload role from its upload service account by hand — `gcloud storage buckets remove-iam-policy-binding gs://<operator_bucket> --member=serviceAccount:upload-measure@<project>.iam.gserviceaccount.com --role=projects/<project>/roles/bucketUploader --all`, or `upload-eval-set` —, and run the script again only once the page has expired, since it grants the role back. That this stops a page already signed, nobody has checked yet. Erase what the page uploaded. Through `roles/firebase.admin` CI reads every object of both buckets: to stop CI meanwhile, `gh workflow disable deploy.yml`.

**Your own Google, Neon or GitHub account was taken.** Change its password, sign out every session, check its second factor, and then go through the rows of section 2 that this account opens.

**Last resort.** `api_serving = false` in `tofu/production.auto.tfvars` and an apply remove the service of `api` (R11): the platform stops for everyone until it comes back. To bring it back, set it to `true`, apply and then run `just deploy-api` at once. The apply makes the service from `api_image`, the image of the first deployment, and `just deploy-api` moves it to the release of the list (R11, R15).

### 4. Find out what happened

- **Admin Activity** — `_Required`, 400 days (architecture 3.4). It shows who changed IAM, who added or disabled a secret's version (sources 2.6), who made a key of a service account, and who changed the pool or its provider, each with the caller's email and IP address:

  ```bash
  gcloud logging read 'logName="projects/<project>/logs/cloudaudit.googleapis.com%2Factivity"' --project=<project> --freshness=400d
  ```

- **What the logs do not show.** Who read a secret's version is Data Access audit, `AccessSecretVersion` (sources 2.6), and the platform neither turns it on nor stores it (R07). Whether to log the reads of the secrets is open, [architecture 2.8](docs/architecture.md#28-auditing-the-reads-of-the-secrets). Nor does any log show who read, wrote or erased an object of the operator's buckets: that is Data Access audit of Cloud Storage, which is off, and every sink excludes it, since an upload's entry would hold the address of the adult who sends it (R07, R28; sources 10.4). The erasures of the lifecycle rules are not logged at all. A change of a bucket's settings or policy is Admin Activity.
- **The log of `api`** — 30 days in the project's region: the method, the code, the cause of a refusal and the time of each call, without the body, the address or the UID (architecture 3.4). Look for bursts and for refusals.
- **Policy Denied** — 30 days: who a policy refused, with their email.
- **GitHub**: `gh run list --workflow deploy.yml` and the deployments of the environment `production`.
- **Neon**: the console's roles and its monitoring. What Neon records about who connected, on its Free plan, nobody has checked yet.
- **Firebase Authentication**: the console's users, with the time each was created and last signed in (sources 4.8). An account nobody let in, or a sign-in at a strange time, is a sign.

### 5. Decide what was reached

Write down which rows of section 2 were reached, over which period, and which accounts. When nothing narrows it, every account was reached. Write down the date on which you determined that the breach occurred: the deadlines of part 2 run from it.

### 6. Reach the learners

There are no names on the server (privacy 3.4 spec), and `api` keeps no email (sources 3.12). The account row in the database `api` holds the sign-in service's UID. The user with that UID in Firebase Authentication holds the email: the console's list of users, or `firebase auth:export` (sources 4.8). The operator has let in each learner so far with a code of their own and knows them.

The addresses never go into this repository, into the record or into a conversation with an AI assistant.

Every learner whose data was reached, or may have been, hears of it by email (section 8). The letter says:

- what happened and when;
- what data of theirs was reached;
- what the operator has done;
- what the learner can do;
- how to reach the operator.

### 7. The record of a case

The operator keeps one record per case, in a closed place of their own, never in this repository, for 5 years after the case is closed (R27). The record holds no name and no address. Its fields:

- the case's number, and when it was opened;
- how you learned of it, and when;
- what happened, as far as you know: the rows of section 2, the period, the accounts as a count;
- the date you determined that the breach occurred;
- each step of section 3, with its time;
- the number of learners reached, and of them how many are Texas residents, as far as you know without asking (section 9);
- the notices: to the learners — the date, the channel and how many; to the attorney general, to another state, to a processor or to the police — the date and what was sent;
- a request of the police to delay the notice, if there was one, with its date;
- what changed so that it does not happen again, and the tasks of `infra` that did it;
- when the case was closed.

## Part 2. The operator of `novatrail`

### 8. Texas: Business and Commerce Code §521.053

The law binds "a person who conducts business in this state" who holds "sensitive personal information" (sources 9.1). That is:

- a name, or a first initial and a last name, together with a social security number, a driver's license or government ID number, or a financial account's number with its code;
- or information that identifies a person and relates to their physical or mental health or condition, or to their health care or its payment.

The platform's server holds no names, so a breach of the database alone rarely meets the first kind. Essays, if a learner turned storage on, may meet the second: with their account, they may identify a person and concern their health (privacy 3.4 spec). The scans of forms in the operator's bucket will carry names.

**The learners.** Tell every person whose sensitive personal information was, or is reasonably believed to have been, acquired by an unauthorized person: "without unreasonable delay and in each case not later than the 60th day after the date on which the person determines that the breach occurred" (sources 9.1). The law allows a delay only to determine the scope of the breach and to restore the system, or at a request of the police (§521.053(b), (d)).

**Beyond the law.** The operator tells every learner whose data was reached, by the same deadline, even when the data are not sensitive personal information (R27).

**How.** The law allows written notice to the last known address, or electronic notice "in accordance with 15 U.S.C. Section 7001", and electronic mail when the operator "does not have sufficient contact information" (§521.053(e), (f)). The operator has email addresses and no postal ones. This procedure does not decide whether an email alone meets the law. In a breach of sensitive personal information, ask a lawyer before you send it.

**The attorney general.** If the breach involves at least 250 Texas residents, notify the attorney general "as soon as practicable and not later than the 30th day after the date on which the person determines that the breach occurred". It goes through the electronic form on the attorney general's website, with six items (sources 9.1):

1. what happened;
2. how many Texas residents are affected;
3. how many of them have been told;
4. what was done;
5. what will be done;
6. whether the police are investigating.

**More than 10,000 people at once.** Tell the nationwide consumer reporting agencies of the timing, distribution and content of the notices (§521.053(h)).

**§521.053(g).** A person who keeps "the person's own notification procedures as part of an information security policy for the treatment of sensitive personal information" that meet the law's deadlines complies when they notify by them, "notwithstanding Subsection (e)" (sources 9.1). The operator means this procedure to be such procedures. Whether it counts as one — the operator has no other written security policy — and so whether its email meets the law is the same question for a lawyer as above. The penalties are $2,000 to $50,000 for a violation. For failing to notify, they are up to $100 for each person and each day, and at most $250,000 for one breach (§521.151).

### 9. Counting Texas residents

The platform knows a learner's country, not their state, and does not ask for it: the state is a new kind of data, which spec rejected (R140 spec). While the operator lets in each learner personally, the operator counts from what they already know of them, and asks nobody. Before the platform has 250 learners, this procedure is reviewed: with 250 or more, the count of Texas residents can no longer come from what the operator knows.

### 10. Learners from other states

A resident of another state may be told under that state's law instead (§521.053(b-1)). That state's law may also bind the operator by itself, with its own deadline and its own authority. Those laws have not been read: privacy 3.4 spec read the states' laws on children's data, on privacy and on biometrics, not their laws on breaches. The question has gone to spec (row В29 of RUN.md).

Until spec answers, in a breach:

- for each learner reached whose state you already know, without asking them (section 9), read that state's breach law from its primary source the same day;
- keep the shorter of the deadlines;
- for a learner whose state you do not know, keep the deadline of Texas, and say in the record that the state is unknown.

Whether the operator may ask a learner for their state in a breach is part of the question to spec. The states of learners are never written into this repository or into the record.

### 11. Not yet

- **Learners from the EU, the EEA and the United Kingdom.** `api` accepts none until the operator has appointed representatives there (R131 spec). The GDPR's Articles 33 and 34 set notices to the supervisory authority and to the people. This repository could not read their text on 2026-11-13 (sources 9.1), and spec's row Д200 names 72 hours for the authority. Read both articles before the first such learner, and write their steps here.
- **Children.** None learn yet (R25). Before the first child, read privacy spec again for what a breach of a child's data requires, and write it here.
