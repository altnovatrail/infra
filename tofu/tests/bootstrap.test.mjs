// The test of tofu/bootstrap.sh, with no cloud: gcloud-stub.mjs stands in for gcloud ahead on
// PATH, and synthetic values stand in for production.auto.tfvars and backend.hcl. It holds the
// script to what R13 says it makes, to what it takes back on a run again, to its refusals, and to
// never printing the billing account. Run by `just bootstrap-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "bootstrap.sh");
const stub = path.join(here, "gcloud-stub.mjs");

const billing = "0A1B2C-3D4E5F-6A7B8C";
const project = "novatrail-test-0";
const account = `serviceAccount:infra-config@${project}.iam.gserviceaccount.com`;
const subject = "repo:example@1000/infra@2000";
const borrower = `principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/infra-github/subject/${subject}:environment:production-config`;

const tfvars = (extra = "") => `project_id = "${project}"
region     = "us-east4"

budget_amount   = "10"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "${subject}"
${extra}`;

// A directory with the values, a bin with the stand-in gcloud, and the stand-in's state and log.
function world({ values = tfvars(), backend = 'bucket = "novatrail-test-0-state"\nprefix = "tofu"\n', gcloud = true } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bootstrap-test-"));
  fs.mkdirSync(path.join(dir, "tofu"));
  fs.mkdirSync(path.join(dir, "bin"));
  fs.writeFileSync(path.join(dir, "tofu", "production.auto.tfvars"), values);
  fs.writeFileSync(path.join(dir, "tofu", "backend.hcl"), backend);
  if (gcloud) {
    fs.writeFileSync(path.join(dir, "bin", "gcloud"), `#!/bin/sh\nexec ${JSON.stringify(process.execPath)} ${JSON.stringify(stub)} "$@"\n`, { mode: 0o755 });
  }
  return {
    dir,
    state: path.join(dir, "state.json"),
    log: path.join(dir, "log"),
    read() {
      return JSON.parse(fs.readFileSync(this.state, "utf8"));
    },
    seed(state) {
      fs.writeFileSync(this.state, JSON.stringify(state));
    },
    calls() {
      return fs.existsSync(this.log) ? fs.readFileSync(this.log, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : [];
    },
    run(env = {}) {
      fs.rmSync(this.log, { force: true });
      const result = spawnSync("bash", [script], {
        encoding: "utf8",
        env: {
          // The system's directories alone, and none where a real gcloud might be.
          PATH: `${path.join(dir, "bin")}:/usr/bin:/bin`,
          HOME: dir,
          BOOTSTRAP_TOFU_DIR: path.join(dir, "tofu"),
          BOOTSTRAP_RETRY_DELAY: "0",
          TF_VAR_billing_account: billing,
          STUB_STATE: this.state,
          STUB_LOG: this.log,
          ...env,
        },
      });
      return { ...result, output: result.stdout + result.stderr };
    },
  };
}

const makes = (calls) => calls.filter((c) => c.includes("create") || c.includes("create-oidc") || c.includes("link") || c.includes("undelete")).map((c) => c.join(" "));

const unconditioned = (state) =>
  state.projectPolicy[project].filter((b) => b.member === account && b.condition === "").map((b) => b.role).sort();

const expression = `api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly(['projects/${project}/roles/hostingPublisher', 'projects/${project}/roles/signInUsers'])`;

test("a first run makes the project, its state, the pool and the configuration's identity", () => {
  const w = world();
  const r = w.run();
  assert.equal(r.status, 0, r.output);
  const s = w.read();

  assert.deepEqual(Object.keys(s.projects), [project]);
  assert.equal(s.billingLinks[project], `billingAccounts/${billing}`);
  assert.deepEqual(s.buckets["gs://novatrail-test-0-state"], {
    project,
    location: "us-east4",
    versioning: true,
    policy: [{ role: "roles/storage.objectAdmin", member: account, condition: "" }],
  });
  for (const api of ["serviceusage.googleapis.com", "cloudresourcemanager.googleapis.com", "iam.googleapis.com", "sts.googleapis.com", "iamcredentials.googleapis.com", "storage.googleapis.com", "observability.googleapis.com", "run.googleapis.com", "firebase.googleapis.com", "firebasehosting.googleapis.com", "identitytoolkit.googleapis.com"]) {
    assert.ok(s.services[project].includes(api), `${api} is enabled`);
  }
  assert.ok(s.pools["infra-github"]);
  assert.ok(s.accounts[`infra-config@${project}.iam.gserviceaccount.com`]);
});

test("the pool admits the jobs of the one repository, by the numbers of its owner and its own", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  assert.deepEqual(w.read().providers["infra-github/github"], {
    issuer: "https://token.actions.githubusercontent.com",
    mapping: "google.subject=assertion.sub",
    condition: "assertion.repository_owner_id=='1000' && assertion.repository_id=='2000'",
    state: "ACTIVE",
  });
});

// modules and tutor, as the platform names them: their subjects are public (R120 spec).
const evalList = 'eval_github_subject_prefixes = ["repo:altnovatrail@344507087/modules@1425775415", "repo:altnovatrail@344507087/tutor@1425813274"]';
const evalCondition =
  "assertion.repository_owner_id=='344507087' && (assertion.repository_id=='1425775415' || assertion.repository_id=='1425813274') && assertion.environment=='eval' && assertion.actor!='dependabot[bot]'";

test("with repositories of eval, the pool github-eval admits their jobs of eval alone, and Dependabot's not", () => {
  const w = world({ values: tfvars(evalList) });
  const r = w.run();
  assert.equal(r.status, 0, r.output);
  const s = w.read();
  assert.ok(s.pools["github-eval"]);
  assert.deepEqual(s.providers["github-eval/github"], {
    issuer: "https://token.actions.githubusercontent.com",
    mapping: "google.subject=assertion.sub",
    condition: evalCondition,
    state: "ACTIVE",
  });
  // The pool the configuration signs in through still admits infra alone.
  assert.equal(s.providers["infra-github/github"].condition, "assertion.repository_owner_id=='1000' && assertion.repository_id=='2000'");
  assert.match(r.stdout, /^GCP_EVAL_WORKLOAD_IDENTITY_PROVIDER=projects\/123456789012\/locations\/global\/workloadIdentityPools\/github-eval\/providers\/github$/m);
});

test("with no repository of eval, there is no pool of eval, and one made before admits nobody", () => {
  const none = world();
  const r = none.run();
  assert.equal(r.status, 0, r.output);
  assert.ok(!none.calls().some((c) => c.includes("create") && c.includes("github-eval")), "no pool of eval is made");
  assert.ok(!none.read().pools["github-eval"]);
  assert.doesNotMatch(r.stdout, /GCP_EVAL_WORKLOAD_IDENTITY_PROVIDER/);

  const before = world({ values: tfvars(evalList) });
  assert.equal(before.run().status, 0);
  fs.writeFileSync(path.join(before.dir, "tofu", "production.auto.tfvars"), tfvars("eval_github_subject_prefixes = []"));
  assert.equal(before.run().status, 0);
  assert.ok(before.read().pools["github-eval"], "the pool is kept");
  assert.equal(before.read().providers["github-eval/github"].condition, "false");
});

test("the list of eval may end its line with a comment", () => {
  const w = world({ values: tfvars(`${evalList} # modules and tutor`) });
  assert.equal(w.run().status, 0);
  assert.equal(w.read().providers["github-eval/github"].condition, evalCondition);
});

test("a run again gives the pool of eval its condition back", () => {
  const w = world({ values: tfvars(evalList) });
  assert.equal(w.run().status, 0);
  const s = w.read();
  s.providers["github-eval/github"].condition = "true";
  w.seed(s);
  assert.equal(w.run().status, 0);
  assert.equal(w.read().providers["github-eval/github"].condition, evalCondition);
});

test("the identity holds exactly its roles, the conditioned admin and nothing of who may change a role", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const s = w.read();
  assert.deepEqual(unconditioned(s), [
    "roles/artifactregistry.admin",
    "roles/browser",
    "roles/cloudscheduler.admin",
    "roles/firebase.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/logging.configWriter",
    "roles/monitoring.alertPolicyEditor",
    "roles/monitoring.notificationChannelEditor",
    "roles/observability.editor",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
  ]);
  assert.ok(!unconditioned(s).some((r) => /owner|editor$|roleAdmin|projectIamAdmin/.test(r) && r !== "roles/observability.editor"), "no Owner, Editor, role admin or unconditioned IAM admin");
  assert.deepEqual(
    s.projectPolicy[project].filter((b) => b.condition !== ""),
    [{ role: "roles/resourcemanager.projectIamAdmin", member: account, condition: expression }],
  );
  assert.deepEqual(s.billingPolicy, [{ role: "roles/billing.costsManager", member: account, condition: "" }]);
});

test("only the jobs of production-config may borrow the identity", () => {
  const w = world();
  const r = w.run();
  assert.equal(r.status, 0);
  assert.deepEqual(w.read().accounts[`infra-config@${project}.iam.gserviceaccount.com`].policy, [
    { role: "roles/iam.workloadIdentityUser", member: borrower, condition: "" },
  ]);
  assert.match(r.stdout, /^GCP_WORKLOAD_IDENTITY_PROVIDER=projects\/123456789012\/locations\/global\/workloadIdentityPools\/infra-github\/providers\/github$/m);
  assert.match(r.stdout, new RegExp(`^GCP_CONFIG_SERVICE_ACCOUNT=infra-config@${project}\\.iam\\.gserviceaccount\\.com$`, "m"));
});

test("the custom roles hold exactly the permissions of the deployment's steps, of a release and of api's users", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const s = w.read();
  assert.deepEqual(s.roles[`${project}/apiDeployer`].permissions.sort(), [
    "run.executions.get",
    "run.executions.list",
    "run.jobs.get",
    "run.jobs.run",
    "run.jobs.runWithOverrides",
    "run.jobs.update",
    "run.operations.get",
    "run.revisions.get",
    "run.revisions.list",
    "run.services.get",
    "run.services.update",
  ]);
  assert.deepEqual(s.roles[`${project}/hostingPublisher`].permissions.sort(), [
    "firebase.clients.get",
    "firebase.clients.list",
    "firebase.projects.get",
    "firebasehosting.sites.get",
    "firebasehosting.sites.list",
    "firebasehosting.sites.update",
    "resourcemanager.projects.get",
  ]);
  assert.deepEqual(s.roles[`${project}/signInUsers`].permissions.sort(), [
    "firebaseauth.users.delete",
    "firebaseauth.users.get",
    "firebaseauth.users.update",
  ]);
});

test("a run again makes nothing and leaves the same", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const before = w.read();
  const r = w.run();
  assert.equal(r.status, 0, r.output);
  assert.deepEqual(makes(w.calls()), []);
  assert.ok(!w.calls().some((c) => c.includes("remove-iam-policy-binding")), "nothing is taken back");
  assert.deepEqual(w.read(), before);
});

test("a run again takes back what drifted: a role not named, a condition rewritten, a borrower, a role's permissions", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const s = w.read();
  s.projectPolicy[project].push({ role: "roles/owner", member: account, condition: "" });
  s.projectPolicy[project] = s.projectPolicy[project].map((b) =>
    b.role === "roles/resourcemanager.projectIamAdmin" ? { ...b, condition: "true" } : b,
  );
  // Somebody else's grant is not the script's to take back.
  s.projectPolicy[project].push({ role: "roles/owner", member: "user:operator@example.com", condition: "" });
  s.accounts[`infra-config@${project}.iam.gserviceaccount.com`].policy.push(
    { role: "roles/iam.workloadIdentityUser", member: borrower.replace("production-config", "pull_request"), condition: "" },
    { role: "roles/iam.serviceAccountTokenCreator", member: "user:someone@example.com", condition: "" },
    { role: "roles/iam.workloadIdentityUser", member: borrower, condition: "request.time < timestamp('2099-01-01T00:00:00Z')" },
  );
  s.roles[`${project}/hostingPublisher`].permissions.push("firebasehosting.sites.delete");
  s.roles[`${project}/apiDeployer`].deleted = true;
  s.roles[`${project}/signInUsers`].permissions.push("firebaseauth.configs.update");
  w.seed(s);

  const r = w.run();
  assert.equal(r.status, 0, r.output);
  const after = w.read();
  assert.ok(!unconditioned(after).includes("roles/owner"));
  assert.ok(after.projectPolicy[project].some((b) => b.role === "roles/owner" && b.member === "user:operator@example.com"));
  assert.deepEqual(
    after.projectPolicy[project].filter((b) => b.role === "roles/resourcemanager.projectIamAdmin").map((b) => b.condition),
    [expression],
  );
  assert.deepEqual(after.accounts[`infra-config@${project}.iam.gserviceaccount.com`].policy.map((b) => b.member), [borrower]);
  assert.ok(!after.roles[`${project}/hostingPublisher`].permissions.includes("firebasehosting.sites.delete"));
  assert.equal(after.roles[`${project}/apiDeployer`].deleted, false);
  assert.ok(!after.roles[`${project}/signInUsers`].permissions.includes("firebaseauth.configs.update"));
});

test("the billing account is printed nowhere, not even in gcloud's error about it", () => {
  const w = world();
  const ok = w.run();
  assert.equal(ok.status, 0);
  assert.ok(!ok.output.includes(billing), ok.output);

  for (const failing of ["billing accounts describe", "billing projects link", "billing accounts add-iam-policy-binding"]) {
    const fresh = world();
    const r = fresh.run({ STUB_FAIL: failing });
    assert.notEqual(r.status, 0, `${failing} fails the run`);
    assert.ok(!r.output.includes(billing), `${failing}: ${r.output}`);
    assert.match(r.output, /<billing account>/, failing);
  }
});

test("a project paid for through another account is not moved", () => {
  const w = world();
  w.seed({ projects: { [project]: { number: "123456789012" } }, billingLinks: { [project]: "billingAccounts/FFFFFF-FFFFFF-FFFFFF" } });
  const r = w.run();
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /pays through another billing account/);
  assert.ok(!w.calls().some((c) => c.includes("link")));
});

// A self-hosted copy: its own project, region, currency, pool, repository and environments, and no
// eval (T29). Nothing of the platform's own deployment may reach what the script makes or prints.
test("a copy brings up its own project by its own values, and nothing of the platform's", () => {
  const values = `project_id = "acme-learning-1"
region     = "europe-west3"

budget_amount   = "20"
budget_currency = "EUR"

workload_identity_pool_id  = "acme-ci"
github_oidc_subject_prefix = "repo:acme@555/platform@777"
deploy_environment         = "acme-api"
hosting_environment        = "acme-site"
`;
  const w = world({ values, backend: 'bucket = "acme-learning-1-state"\nprefix = "tofu"\n' });
  const r = w.run({ STUB_CURRENCY: "EUR" });
  assert.equal(r.status, 0, r.output);
  const s = w.read();
  assert.deepEqual(Object.keys(s.projects), ["acme-learning-1"]);
  assert.equal(s.buckets["gs://acme-learning-1-state"].location, "europe-west3");
  assert.deepEqual(Object.keys(s.pools), ["acme-ci"], "the copy's pool alone, and no pool of eval");
  assert.equal(s.providers["acme-ci/github"].condition, "assertion.repository_owner_id=='555' && assertion.repository_id=='777'");
  assert.match(r.stdout, /repo:acme@555\/platform@777:environment:production-config/);
  assert.match(r.stdout, /^GCP_WORKLOAD_IDENTITY_PROVIDER=projects\/\d+\/locations\/global\/workloadIdentityPools\/acme-ci\/providers\/github$/m);
  assert.match(r.stdout, /^GCP_CONFIG_SERVICE_ACCOUNT=infra-config@acme-learning-1\.iam\.gserviceaccount\.com$/m);
  assert.doesNotMatch(r.stdout, /GCP_EVAL_WORKLOAD_IDENTITY_PROVIDER/);
  // The script looks whether a pool of eval was made before, to shut it; that look is the one
  // mention of github-eval, and it makes nothing.
  const asked = JSON.stringify(w.calls().filter((c) => !(c.includes("describe") && c.includes("github-eval"))));
  const made = JSON.stringify({ state: s, out: r.stdout }) + asked;
  for (const platform of ["novatrail", "us-east4", "344507087", "altnovatrail", "infra-github", "github-eval"]) {
    assert.ok(!made.includes(platform), `${platform} reaches the copy`);
  }
});

test("a billing account in another currency than the budget's is refused before anything is made", () => {
  const w = world();
  const r = w.run({ STUB_CURRENCY: "EUR" });
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /billed in EUR, and budget_currency .* is USD/);
  assert.deepEqual(makes(w.calls()), []);
});

test("refusals, each before any call to gcloud", async (t) => {
  const cases = [
    ["no gcloud", { gcloud: false }, {}, /there is no gcloud here/],
    ["a value not filled in", { values: tfvars().replace(`"${project}"`, '"REPLACE_ME"') }, {}, /project_id is not filled in yet/],
    ["no bucket", { backend: "" }, {}, /bucket is not filled in yet/],
    ["a subject of another form", { values: tfvars().replace(subject, "repo:example/infra") }, {}, /github_oidc_subject_prefix is not of the form/],
    ["no billing account", {}, { TF_VAR_billing_account: "" }, /TF_VAR_billing_account is not set/],
    ["a billing account of another form", {}, { TF_VAR_billing_account: "billingAccounts/0A1B2C-3D4E5F-6A7B8C" }, /TF_VAR_billing_account is not set, or is not the id/],
    ["api's deployment in the configuration's environment", { values: tfvars('deploy_environment = "Production-Config"') }, {}, /the configuration's own, production-config/],
    ["the publisher in the configuration's environment", { values: tfvars('hosting_environment = "production-config"') }, {}, /the configuration's own, production-config/],
    ["repositories of eval on more lines than one", { values: tfvars('eval_github_subject_prefixes = [\n  "repo:altnovatrail@344507087/modules@1425775415",\n]') }, {}, /eval_github_subject_prefixes in production\.auto\.tfvars is not a list on one line/],
    ["repositories of eval not apart by commas", { values: tfvars('eval_github_subject_prefixes = ["repo:a@1/b@2" "repo:a@1/c@3"]') }, {}, /is not a list on one line/],
    ["a repository of eval of another form", { values: tfvars('eval_github_subject_prefixes = ["altnovatrail/modules"]') }, {}, /holds altnovatrail\/modules, not of the form/],
    ["a repository of eval named twice", { values: tfvars('eval_github_subject_prefixes = ["repo:a@1/b@2", "repo:a@1/b@2"]') }, {}, /names the repository 2 twice/],
    ["repositories of eval of two owners", { values: tfvars('eval_github_subject_prefixes = ["repo:a@1/b@2", "repo:c@3/d@4"]') }, {}, /of more than one owner/],
    ["the configuration's pool named as eval's", { values: tfvars().replace('"infra-github"', '"github-eval"') }, {}, /workload_identity_pool_id is github-eval, the pool of eval/],
  ];
  for (const [name, setup, env, message] of cases) {
    await t.test(name, () => {
      const w = world(setup);
      const r = w.run(env);
      assert.notEqual(r.status, 0, `${name}: ${r.output}`);
      assert.match(r.stderr, message);
      assert.deepEqual(w.calls(), []);
    });
  }
});

test("what the identity holds beyond its lists is taken back, under any condition, on the project, the bucket and the billing account", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const s = w.read();
  s.projectPolicy[project].push(
    { role: "roles/iam.roleAdmin", member: account, condition: "request.time < timestamp('2099-01-01T00:00:00Z')" },
    { role: "roles/run.admin", member: account, condition: "true" },
  );
  s.buckets["gs://novatrail-test-0-state"].policy.push({ role: "roles/storage.admin", member: account, condition: "" });
  s.billingPolicy.push({ role: "roles/billing.admin", member: account, condition: "" });
  w.seed(s);

  const r = w.run();
  assert.equal(r.status, 0, r.output);
  const after = w.read();
  const mine = after.projectPolicy[project].filter((b) => b.member === account);
  assert.ok(!mine.some((b) => b.role === "roles/iam.roleAdmin"), "a role not named, under a condition, is taken back");
  assert.deepEqual(mine.filter((b) => b.role === "roles/run.admin"), [{ role: "roles/run.admin", member: account, condition: "" }]);
  assert.deepEqual(after.buckets["gs://novatrail-test-0-state"].policy.map((b) => b.role), ["roles/storage.objectAdmin"]);
  assert.deepEqual(after.billingPolicy.map((b) => b.role), ["roles/billing.costsManager"]);
  assert.ok(!r.output.includes(billing), r.output);
});

test("Owner and Editor are taken from the project's own service accounts, and from nobody else", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const s = w.read();
  const keep = [
    { role: "roles/editor", member: "serviceAccount:123456789012@cloudservices.gserviceaccount.com", condition: "" },
    { role: "roles/owner", member: "user:operator@example.com", condition: "" },
    { role: "roles/run.invoker", member: `serviceAccount:api-run@${project}.iam.gserviceaccount.com`, condition: "" },
  ];
  s.projectPolicy[project].push(
    ...keep,
    { role: "roles/editor", member: "serviceAccount:123456789012-compute@developer.gserviceaccount.com", condition: "" },
    { role: "roles/editor", member: `serviceAccount:${project}@appspot.gserviceaccount.com`, condition: "" },
    { role: "roles/owner", member: `serviceAccount:api-run@${project}.iam.gserviceaccount.com`, condition: "true" },
  );
  w.seed(s);

  const r = w.run();
  assert.equal(r.status, 0, r.output);
  const after = w.read().projectPolicy[project].filter((b) => b.member !== account);
  assert.deepEqual(after, keep);
  assert.match(r.stdout, /roles\/editor of 123456789012-compute@developer\.gserviceaccount\.com: taken back/);
});

test("a pool and a provider deleted not long ago are undeleted, and a project marked for deletion is refused", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const s = w.read();
  s.pools["infra-github"].state = "DELETED";
  s.providers["infra-github/github"].state = "DELETED";
  w.seed(s);
  const r = w.run();
  assert.equal(r.status, 0, r.output);
  assert.equal(w.read().pools["infra-github"].state, "ACTIVE");
  assert.equal(w.read().providers["infra-github/github"].state, "ACTIVE");
  assert.ok(!w.calls().some((c) => c.includes("create") || c.includes("create-oidc")));

  const doomed = world();
  doomed.seed({ projects: { [project]: { number: "123456789012", lifecycle: "DELETE_REQUESTED" } } });
  const refused = doomed.run();
  assert.notEqual(refused.status, 0);
  assert.match(refused.stderr, /marked for deletion/);
  assert.ok(!doomed.calls().some((c) => c.includes("link") || c.includes("enable")));
});

test("a role whose reading fails for a passing reason is read again, not made anew", () => {
  const w = world();
  assert.equal(w.run().status, 0);
  const r = w.run({ STUB_FAIL_ONCE: "iam roles describe apiDeployer" });
  assert.equal(r.status, 0, r.output);
  assert.ok(!w.calls().some((c) => c.join(" ").startsWith("iam roles create")), w.calls().map((c) => c.join(" ")).join("\n"));
});
