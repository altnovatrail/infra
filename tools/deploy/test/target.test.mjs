// tools/deploy/target.mjs against git repositories made here — an origin and its clone — and a
// stand-in for GitHub's API on this machine, and the shape of .github/workflows/deploy.yml that
// R18 holds it to: no network. Run by `just deploy-target-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";
import { decide, identity, lastDelivered, partsOfInputs, Refusal, tipOfMain } from "../target.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, "..", "..", "..");
const script = path.join(here, "..", "target.mjs");

const made = [];
after(() => {
  for (const dir of made) fs.rmSync(dir, { recursive: true, force: true });
});

const list = (apiRelease = "v0.1.5", appRelease = "v0.1.0") => ({
  format: 1,
  api: { release: apiRelease, binary: { name: `api_${apiRelease}_linux_amd64`, sha256: "1".repeat(64) }, dockerfile: { sha256: "2".repeat(64) } },
  app: { release: appRelease, archive: { name: `app_${appRelease}.tar.gz`, sha256: "3".repeat(64) }, deployment: { sha256: "4".repeat(64) } },
  admission: { rung: "full" },
});
const facts = { openai: { data_processing_agreement: ["adult"] } };
const tfvars = 'project_id = "novatrail-x"\napi_image  = "us-east4-docker.pkg.dev/novatrail-x/images/api@sha256:' + "5".repeat(64) + '"\n';
const setUp = { "tofu/ci.env": "GCP_WORKLOAD_IDENTITY_PROVIDER=projects/1/locations/global/workloadIdentityPools/infra-github/providers/github\n", "tofu/production.auto.tfvars": tfvars, "tofu/backend.hcl": 'bucket = "novatrail-x-state"\n' };

// An origin and its clone; commit() writes files, commits them and pushes main.
function repository() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-target-test-"));
  made.push(dir);
  const origin = path.join(dir, "origin.git");
  const clone = path.join(dir, "clone");
  const g = (cwd, ...args) => {
    const r = spawnSync("/usr/bin/git", ["-C", cwd, ...args], { encoding: "utf8" });
    assert.equal(r.status, 0, `git ${args.join(" ")}: ${r.stderr}`);
    return r.stdout.trim();
  };
  fs.mkdirSync(origin);
  g(origin, "init", "-q", "--bare", "-b", "main");
  g(dir, "clone", "-q", origin, clone);
  g(clone, "config", "user.email", "test@example.com");
  g(clone, "config", "user.name", "test");
  g(clone, "config", "commit.gpgsign", "false");
  g(clone, "checkout", "-q", "-b", "main");
  const commit = (files) => {
    for (const [file, content] of Object.entries(files)) {
      const where = path.join(clone, file);
      if (content === null) {
        fs.rmSync(where, { force: true });
        continue;
      }
      fs.mkdirSync(path.dirname(where), { recursive: true });
      fs.writeFileSync(where, typeof content === "string" ? content : JSON.stringify(content, null, 2));
    }
    g(clone, "add", "-A");
    g(clone, "commit", "-q", "--allow-empty", "-m", "change");
    g(clone, "push", "-q", "origin", "main");
    return g(clone, "rev-parse", "HEAD");
  };
  return { clone, commit, git: (...args) => g(clone, ...args) };
}

const decideAt = (r, commit, base, byHand = null) => decide({ dir: r.clone, commit, tip: tipOfMain(r.clone), base, byHand });

test("main moved on: nothing is delivered, and the run says so", () => {
  const r = repository();
  const first = r.commit({ ...setUp, "deploy/production.json": list() });
  r.commit({ README: "next" });
  const d = decideAt(r, first, null);
  assert.equal(d.deliver, false);
  assert.match(d.lines[0], /main stands on [0-9a-f]{12} now, not on [0-9a-f]{12}: its own run delivers it/);
});

test("a project not set up yet: nothing is delivered, and the files it waits for are named", () => {
  const r = repository();
  const commit = r.commit({ "tofu/production.auto.tfvars": setUp["tofu/production.auto.tfvars"], "deploy/production.json": list() });
  const d = decideAt(r, commit, null);
  assert.equal(d.deliver, false);
  assert.match(d.lines[0], /the project is not set up yet: tofu\/ci\.env, tofu\/backend\.hcl not at/);
});

test("no list: the configuration alone", () => {
  const r = repository();
  const d = decideAt(r, r.commit(setUp), null);
  assert.deepEqual({ ...d, lines: undefined }, { deliver: true, commit: d.commit, image: false, api: false, facts: false, app: false, lines: undefined });
});

test("no run has delivered yet: every part of the list", () => {
  const r = repository();
  const d = decideAt(r, r.commit({ ...setUp, "deploy/production.json": list(), "deploy/production/facts.json": facts }), null);
  assert.deepEqual([d.deliver, d.image, d.api, d.facts, d.app], [true, false, true, true, true]);
  assert.match(d.lines.join("\n"), /no run has delivered the list yet/);
});

test("against the last run that delivered, each part changes alone, and the rest stays", async (t) => {
  const cases = [
    ["api", { "deploy/production.json": list("v0.1.6") }, { api: true, facts: false, app: false }],
    ["facts", { "deploy/production/facts.json": { openai: { data_processing_agreement: ["adult", "school"] } } }, { api: false, facts: true, app: false }],
    ["app", { "deploy/production.json": list("v0.1.5", "v0.1.1") }, { api: false, facts: false, app: true }],
    ["nothing of the list: the configuration alone", { "tofu/main.tf": "# changed" }, { api: false, facts: false, app: false }],
    ["the list's layout alone, the same values", { "deploy/production.json": JSON.stringify(list()) }, { api: false, facts: false, app: false }],
  ];
  for (const [name, change, want] of cases) {
    await t.test(name, () => {
      const r = repository();
      const delivered = r.commit({ ...setUp, "deploy/production.json": list(), "deploy/production/facts.json": facts });
      const d = decideAt(r, r.commit(change), delivered);
      assert.equal(d.deliver, true);
      assert.deepEqual({ api: d.api, facts: d.facts, app: d.app }, want, d.lines.join("\n"));
    });
  }
});

test("a change waiting behind a newer one is not lost: the parts count from the last run that delivered, not from the push before", () => {
  const r = repository();
  const delivered = r.commit({ ...setUp, "deploy/production.json": list(), "deploy/production/facts.json": facts });
  r.commit({ "deploy/production.json": list("v0.1.6") }); // its run waited, and was replaced
  const newest = r.commit({ "deploy/production/facts.json": { openai: { data_processing_agreement: [] } } });
  const d = decideAt(r, newest, delivered);
  assert.deepEqual({ api: d.api, facts: d.facts, app: d.app }, { api: true, facts: true, app: false });
});

test("a last run that delivered at a commit this history does not hold counts as none", () => {
  const r = repository();
  const d = decideAt(r, r.commit({ ...setUp, "deploy/production.json": list() }), "f".repeat(40));
  assert.deepEqual([d.api, d.facts, d.app], [true, true, true]);
  assert.match(d.lines.join("\n"), /which this history does not hold/);
});

test("until api_image is named, a changed api is its image alone, and the facts wait for the service", () => {
  const r = repository();
  const commit = r.commit({ ...setUp, "tofu/production.auto.tfvars": 'project_id = "novatrail-x"\n# api_image = "…"\n', "deploy/production.json": list(), "deploy/production/facts.json": facts });
  const d = decideAt(r, commit, null);
  assert.deepEqual([d.deliver, d.image, d.api, d.facts, d.app], [true, true, false, false, true]);
  assert.match(d.lines.join("\n"), /names no api_image yet, so api has no jobs: its image alone; name the digest it prints in api_image, then run api by hand/);
});

test("the inputs of a run started by hand are its parts, and only true or false", () => {
  assert.equal(partsOfInputs({ INPUT_IMAGE: "false", INPUT_API: "true", INPUT_FACTS: "false", INPUT_APP: "true" }), "api,app");
  assert.equal(partsOfInputs({ INPUT_IMAGE: "false", INPUT_API: "false", INPUT_FACTS: "false", INPUT_APP: "false" }), "");
  assert.throws(() => partsOfInputs({ INPUT_IMAGE: "", INPUT_API: "true", INPUT_FACTS: "false", INPUT_APP: "false" }), /INPUT_IMAGE is "", not true or false/);
});

test("a run started by hand delivers the parts it names, and none when it names none", () => {
  const r = repository();
  const commit = r.commit({ ...setUp, "deploy/production.json": list() });
  const d = decideAt(r, commit, null, "image,app");
  assert.deepEqual([d.deliver, d.image, d.api, d.facts, d.app], [true, true, false, false, true]);
  const none = decideAt(r, commit, null, "");
  assert.deepEqual([none.deliver, none.image, none.api, none.facts, none.app], [true, false, false, false, false]);
  assert.throws(() => decideAt(r, commit, null, "api,database"), /no part database: the parts are image, api, facts, app/);
});

let server;
let api;
let answer = () => ({ status: 200, body: { workflow_runs: [] } });
let jobsOf = () => ({ status: 200, body: { jobs: [] } });
const asked = [];
before(async () => {
  server = http.createServer((req, res) => {
    asked.push({ url: req.url, authorization: req.headers.authorization });
    const jobs = /\/actions\/runs\/(\d+)\/jobs/.exec(req.url);
    const { status, body } = jobs ? jobsOf(Number(jobs[1])) : answer();
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  api = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test("the last run that delivered is the newest green run pushed to main whose Configuration went through", async () => {
  // Run 3 is green and delivered nothing: main had moved on, or the project was not set up.
  answer = () => ({ status: 200, body: { workflow_runs: [{ id: 3, head_sha: "c".repeat(40) }, { id: 2, head_sha: "b".repeat(40) }, { id: 1, head_sha: "a".repeat(40) }] } });
  jobsOf = (id) => ({ status: 200, body: { jobs: [{ name: "Target", conclusion: "success" }, { name: "Configuration", conclusion: id === 3 ? "skipped" : "success" }] } });
  asked.length = 0;
  assert.equal(await lastDelivered({ repository: "altnovatrail/infra", token: "synthetic", api }), "b".repeat(40));
  const { url, authorization } = asked[0];
  assert.equal(authorization, "Bearer synthetic");
  const query = new URL(url, api);
  assert.equal(query.pathname, "/repos/altnovatrail/infra/actions/workflows/deploy.yml/runs");
  assert.deepEqual(Object.fromEntries(query.searchParams), { branch: "main", event: "push", status: "success", per_page: "20" });
  assert.deepEqual(asked.slice(1).map((a) => new URL(a.url, api).pathname), ["/repos/altnovatrail/infra/actions/runs/3/jobs", "/repos/altnovatrail/infra/actions/runs/2/jobs"]);

  jobsOf = () => ({ status: 200, body: { jobs: [{ name: "Configuration", conclusion: "skipped" }] } });
  assert.equal(await lastDelivered({ repository: "altnovatrail/infra", token: "synthetic", api }), null);

  answer = () => ({ status: 200, body: { workflow_runs: [] } });
  assert.equal(await lastDelivered({ repository: "altnovatrail/infra", token: "synthetic", api }), null);

  answer = () => ({ status: 403, body: { message: "Resource not accessible by integration" } });
  await assert.rejects(lastDelivered({ repository: "altnovatrail/infra", token: "synthetic", api }), /GitHub answered 403 for the last run that delivered/);
  await assert.rejects(lastDelivered({ repository: "altnovatrail/infra", token: "", api }), Refusal);
});

test("tofu/ci.env: the provider and the configuration's identity, of their forms, and nothing else", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-target-test-"));
  made.push(dir);
  const file = path.join(dir, "ci.env");
  const good = "# printed by bootstrap.sh\nGCP_WORKLOAD_IDENTITY_PROVIDER=projects/123456789012/locations/global/workloadIdentityPools/infra-github/providers/github\nGCP_CONFIG_SERVICE_ACCOUNT=infra-config@novatrail-prod.iam.gserviceaccount.com\n";
  fs.writeFileSync(file, good);
  assert.deepEqual(identity(file), { provider: "projects/123456789012/locations/global/workloadIdentityPools/infra-github/providers/github", config_service_account: "infra-config@novatrail-prod.iam.gserviceaccount.com" });
  for (const [text, message] of [
    [good.replace("providers/github", "providers/github extra"), /names no provider of a federated pool/],
    [good.replace("infra-config@", "api-deploy@"), /names no infra-config identity/],
    [good + "GCP_PROJECT=novatrail-prod\n", /holds GCP_PROJECT, which it does not name/],
    [good + "GCP_CONFIG_SERVICE_ACCOUNT=infra-config@other-proj.iam.gserviceaccount.com\n", /not one line of KEY=value of its own/],
  ]) {
    fs.writeFileSync(file, text);
    assert.throws(() => identity(file), message);
  }
  assert.throws(() => identity(path.join(dir, "none.env")), /is not there: the project is not set up yet \(T23\)/);
});

test("the command line: current fails once main moved on, and target prints its outputs", () => {
  const r = repository();
  const first = r.commit({ ...setUp, "deploy/production.json": list() });
  const run = (...args) => spawnSync(process.execPath, [script, ...args], { cwd: r.clone, encoding: "utf8", env: { ...process.env, GITHUB_REPOSITORY: "", GITHUB_TOKEN: "" } });
  const here = run("target", first, "--by-hand=api");
  assert.equal(here.status, 0, here.stderr);
  assert.equal(here.stdout, `deliver=true\ncommit=${first}\nimage=false\napi=true\nfacts=false\napp=false\n`);
  assert.equal(run("current", first).status, 0);

  r.commit({ README: "next" });
  const moved = run("current", first);
  assert.equal(moved.status, 1);
  assert.match(moved.stderr, /^target: main stands on [0-9a-f]{12} now, not on [0-9a-f]{12}: its own run delivers it, and this job would roll it back/m);
  // On a commit main left, target asks GitHub nothing and delivers nothing.
  const old = run("target", first);
  assert.equal(old.status, 0, old.stderr);
  assert.match(old.stdout, /^deliver=false$/m);
  assert.equal(run("target", first, "--parts=api").status, 1);

  // In the workflow a run started by hand names its parts by its inputs.
  const tip = r.commit({ README: "tip" });
  const dispatched = spawnSync(process.execPath, [script, "target", tip], { cwd: r.clone, encoding: "utf8", env: { ...process.env, GITHUB_EVENT_NAME: "workflow_dispatch", INPUT_IMAGE: "true", INPUT_API: "false", INPUT_FACTS: "false", INPUT_APP: "false" } });
  assert.equal(dispatched.status, 0, dispatched.stderr);
  assert.match(dispatched.stdout, /^image=true$/m);
  assert.match(dispatched.stdout, /^api=false$/m);
});

// The workflow's shape, as R18 has it: what actionlint cannot know.
test("the workflow: every job after target asks again on a retry, signs in only where it deploys, and every action is pinned", () => {
  const text = fs.readFileSync(path.join(root, ".github", "workflows", "deploy.yml"), "utf8");
  const jobs = {};
  let name = null;
  let inJobs = false;
  for (const line of text.split("\n")) {
    if (line === "jobs:") inJobs = true;
    else if (inJobs && /^ {2}[a-z]+:$/.test(line)) jobs[(name = line.trim().slice(0, -1))] = [];
    else if (inJobs && name) jobs[name].push(line);
  }
  assert.deepEqual(Object.keys(jobs), ["target", "config", "api", "app"]);
  const environments = { config: "production-config", api: "production", app: "production-hosting" };
  for (const [job, environment] of Object.entries(environments)) {
    const body = jobs[job].join("\n");
    assert.match(body, new RegExp(`^ {4}environment: ${environment}$`, "m"), job);
    assert.match(body, /if: github\.run_attempt != '1'\n\s+env:\n\s+COMMIT: \$\{\{ needs\.target\.outputs\.commit \}\}\n\s+run: just ci-deploy-current "\$COMMIT"/, `${job} asks again on a retry`);
    assert.match(body, /id-token: write/, job);
    assert.match(body, /ref: \$\{\{ needs\.target\.outputs\.commit \}\}/, `${job} deploys the commit target decided`);
  }
  assert.doesNotMatch(jobs.target.join("\n"), /id-token|environment:/);
  assert.match(text, /^concurrency:\n {2}group: deploy\n {2}cancel-in-progress: false$/m);
  for (const [, ref] of text.matchAll(/^\s+- uses: ([^\s]+)/gm)) {
    assert.ok(ref.startsWith("./") || /@[0-9a-f]{40}$/.test(ref), `${ref} is pinned by its commit`);
  }
  assert.doesNotMatch(text, /persist-credentials: true/);
});
