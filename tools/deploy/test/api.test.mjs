// The test of tools/deploy/api.sh, with no cloud: stub.mjs stands in for gcloud and docker ahead on
// PATH, and the script runs from a copy of the repository's layout in which tools/deploy-check/
// fetch.mjs is a stand-in too, reading synthetic release files, so that the deployment's own fetch
// keeps no hook to bypass release-verify. It holds the script to R05's steps and their order, to
// what it refuses, and to the path of the facts alone. Run by `just deploy-api-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "api.sh");
const stub = path.join(here, "stub.mjs");

const made = [];
after(() => {
  for (const dir of made) fs.rmSync(dir, { recursive: true, force: true });
});

const hash = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const repository = "us-east4-docker.pkg.dev/novatrail-test-0/images";
const image = `${repository}/api`;

// The stand-in for fetch.mjs: the file from the synthetic releases, of the sha256 named, or a
// refusal; REFUSE names a file it refuses as release-verify would.
const fetchStub = `import fs from "node:fs";
import crypto from "node:crypto";
import path from "node:path";
const [repository, tag, file, sha256, dir] = process.argv.slice(2);
const source = path.join(process.env.STUB_RELEASES, repository, tag, file);
if (!fs.existsSync(source)) { console.error("fetch: the release " + tag + " of " + repository + " holds no " + file); process.exit(1); }
if (process.env.REFUSE === file) { console.error("fetch: release-verify refused " + file); process.exit(1); }
const got = crypto.createHash("sha256").update(fs.readFileSync(source)).digest("hex");
if (got !== sha256) { console.error("fetch: " + file + " has sha256 " + got + ", and the list names " + sha256); process.exit(1); }
fs.mkdirSync(path.join(dir, repository, tag), { recursive: true });
const target = path.join(dir, repository, tag, file);
fs.copyFileSync(source, target);
console.log(target);
`;

// The jobs of the list: one of each part, and one of the clock.
const jobs = {
  check: { job: "api-check", deploy: "check" },
  migrate: { job: "api-migrate", deploy: "migrate" },
  after: { job: "api-after", deploy: "after" },
  daily: { job: "api-daily", deploy: null },
};

// The layout of the repository, the release's files, the configuration's outputs, and the stand-ins'
// state: the service serving `serving` (or none), the registry's tags.
// `project` and `region` are the copy's when a test is about a copy: its registry follows them.
function world({ release = "v0.2.0", serving = "v0.1.0", outputs: change, state: edit, project = "novatrail-test-0", region = "us-east4" } = {}) {
  const ownRepository = `${region}-docker.pkg.dev/${project}/images`;
  const ownImage = `${ownRepository}/api`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-api-test-"));
  made.push(dir);
  fs.mkdirSync(path.join(dir, "tools", "deploy"), { recursive: true });
  fs.mkdirSync(path.join(dir, "tools", "deploy-check"), { recursive: true });
  fs.copyFileSync(script, path.join(dir, "tools", "deploy", "api.sh"));
  fs.writeFileSync(path.join(dir, "tools", "deploy-check", "fetch.mjs"), fetchStub);

  const releases = path.join(dir, "releases");
  const put = (tag, name, text) => {
    fs.mkdirSync(path.join(releases, "api", tag), { recursive: true });
    fs.writeFileSync(path.join(releases, "api", tag, name), text);
    return hash(text);
  };
  const binary = put(release, `api_${release}_linux_amd64`, `binary of ${release}`);
  const dockerfile = put(release, "Dockerfile", "FROM scratch AS release\n");

  fs.mkdirSync(path.join(dir, "deploy", "production"), { recursive: true });
  fs.writeFileSync(
    path.join(dir, "deploy", "production.json"),
    JSON.stringify({
      format: 1,
      api: { release, binary: { name: `api_${release}_linux_amd64`, sha256: binary }, dockerfile: { sha256: dockerfile } },
      app: { release: "v0.3.0", archive: { name: "app_v0.3.0.tar.gz", sha256: "3".repeat(64) }, deployment: { sha256: "4".repeat(64) } },
      admission: { rung: "full" },
    }),
  );
  fs.writeFileSync(path.join(dir, "deploy", "production", "facts.json"), '{"openai":{"data_processing_agreement":["adult"]}}\n');

  const values = {
    project_id: project,
    region,
    image_repository: ownRepository,
    api_service_name: "api",
    admission_facts_secret: "api-admission-facts",
    admission_facts_file: "/etc/api/admission/facts.json",
    api_jobs: jobs,
  };
  change?.(values);
  const outputs = path.join(dir, "outputs.json");
  fs.writeFileSync(outputs, JSON.stringify(Object.fromEntries(Object.entries(values).map(([k, v]) => [k, { value: v, sensitive: false }]))));

  const servingDigest = "a".repeat(64);
  const state = {
    jobs: Object.fromEntries(Object.values(jobs).map((j) => [j.job, { image: `${ownImage}@sha256:${"f".repeat(64)}` }])),
    tags: serving ? [{ image: ownImage, tag: serving, digest: servingDigest }] : [],
    service: serving
      ? {
          name: "api",
          revisions: { "api-00001": { image: `${ownImage}@sha256:${servingDigest}`, facts: "1" } },
          traffic: [{ revisionName: "api-00001", percent: 100 }],
          latestCreated: "api-00001",
          latestReady: "api-00001",
        }
      : null,
  };
  edit?.(state);
  const statePath = path.join(dir, "state.json");
  fs.writeFileSync(statePath, JSON.stringify(state));

  fs.mkdirSync(path.join(dir, "bin"));
  for (const program of ["gcloud", "docker"]) {
    fs.writeFileSync(path.join(dir, "bin", program), `#!/bin/sh\nexec ${JSON.stringify(process.execPath)} ${JSON.stringify(stub)} ${program} "$@"\n`, { mode: 0o755 });
  }
  const log = path.join(dir, "log");

  return {
    read: () => JSON.parse(fs.readFileSync(statePath, "utf8")),
    calls: () => (fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []),
    run(command, env = {}) {
      fs.rmSync(log, { force: true });
      const r = spawnSync("bash", [path.join(dir, "tools", "deploy", "api.sh"), command, outputs], {
        encoding: "utf8",
        env: {
          PATH: `${path.join(dir, "bin")}:${path.dirname(process.execPath)}:/usr/bin:/bin`,
          HOME: dir,
          STUB_STATE: statePath,
          STUB_LOG: log,
          STUB_RELEASES: releases,
          ...env,
        },
      });
      return { ...r, output: r.stdout + r.stderr };
    },
  };
}

// The calls in the order they came, as short names: what the deployment did.
const steps = (calls) =>
  calls
    .map(([program, ...a]) => {
      const p = a.filter((x) => !x.startsWith("--"));
      if (program === "docker") return `docker ${p[0]}`;
      const c = p.slice(0, 3).join(" ");
      if (c === "run jobs execute") return `execute ${p[3]}`;
      if (c === "run jobs update") return `image ${p[3]}`;
      if (c === "run services update") return "revision";
      if (c === "run services update-traffic") return "traffic";
      if (c === "secrets versions add") return "facts";
      return null;
    })
    .filter(Boolean);

test("a release goes R05's way: image, facts, check and migrate on the new image, a revision with no traffic, all of it to that revision, then the other jobs' image and after", () => {
  const w = world();
  const r = w.run("release");
  assert.equal(r.status, 0, r.output);
  assert.deepEqual(steps(w.calls()), [
    "docker build",
    "docker push",
    "facts",
    "image api-check",
    "image api-migrate",
    "execute api-check",
    "execute api-migrate",
    "revision",
    "traffic",
    "image api-after",
    "image api-daily",
    "execute api-after",
  ]);
  const s = w.read();
  const pushed = s.tags.find((t) => t.tag === "v0.2.0");
  const digest = `${image}@sha256:${pushed.digest}`;
  for (const job of Object.values(s.jobs)) assert.equal(job.image, digest, "every job runs the new image, by digest");
  assert.deepEqual(s.service.revisions["api-00002"], { image: digest, factsFile: "/etc/api/admission/facts.json", facts: "api-admission-facts:1" });
  assert.deepEqual(
    { factsFile: s.jobs["api-check"].factsFile, facts: s.jobs["api-check"].facts },
    { factsFile: "/etc/api/admission/facts.json", facts: "api-admission-facts:1" },
    "the check runs on the version of the facts the revision mounts, the one just added, not the latest",
  );
  for (const job of ["api-migrate", "api-after", "api-daily"]) assert.equal(s.jobs[job].facts, undefined, `${job} is given no facts`);
  assert.deepEqual(s.service.traffic, [{ revisionName: "api-00002", percent: 100 }]);
  assert.match(r.stdout, /api v0\.2\.0 after v0\.1\.0, which takes the traffic/);
  const build = w.calls().find((c) => c[0] === "docker" && c[1] === "build");
  assert.ok(build.includes("--platform=linux/amd64"), "the image is the binary's platform");
  const revision = w.calls().find((c) => c.includes("update") && c.includes("services"));
  assert.ok(revision.includes("--no-traffic"), "the revision takes no traffic until it is ready");
});

test("the same release as the one that takes the traffic goes again, on the image it has, built not again", () => {
  const w = world({ release: "v0.1.0", serving: "v0.1.0" });
  const r = w.run("release");
  assert.equal(r.status, 0, r.output);
  assert.ok(!steps(w.calls()).some((s) => s.startsWith("docker")), "no build: the registry holds the release's image");
  const s = w.read();
  assert.deepEqual(s.tags, [{ image, tag: "v0.1.0", digest: "a".repeat(64) }], "the tag stays on the image that takes the traffic");
  assert.equal(s.service.revisions["api-00002"].image, `${image}@sha256:${"a".repeat(64)}`);
});

test("a tag of the serving image that is not an exact release is refused, not taken as lower", () => {
  const w = world({ release: "v0.2.0", state: (s) => (s.tags = [{ image, tag: "v1.0.0-rc.1", digest: "a".repeat(64) }]) });
  const r = w.run("release");
  assert.notEqual(r.status, 0, r.output);
  assert.match(r.stderr, /v1\.0\.0-rc\.1 is not an exact tag of a release/);
  assert.deepEqual(steps(w.calls()), []);
});

test("a list of jobs with no check is refused before anything runs: the migrations do not go before api's check of its configuration", () => {
  const w = world({ outputs: (o) => (o.api_jobs = { migrate: jobs.migrate, daily: jobs.daily }) });
  const r = w.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /name no job of the part check/);
  assert.deepEqual(steps(w.calls()), []);
});

test("a list of jobs with no migrate is refused before anything runs", () => {
  const w = world({ outputs: (o) => (o.api_jobs = { check: jobs.check, daily: jobs.daily }) });
  const r = w.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /name no job of the part migrate/);
  assert.deepEqual(steps(w.calls()), []);
});

test("jobs not of their form are refused, not run as none", () => {
  const w = world({ outputs: (o) => (o.api_jobs = [jobs.migrate]) });
  const r = w.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /are not jobs with their parts/);
});

test("a higher release by number, though lower as text, goes", () => {
  for (const [release, serving] of [["v0.10.0", "v0.9.0"], ["v0.2.10", "v0.2.9"]]) {
    const r = world({ release, serving }).run("release");
    assert.equal(r.status, 0, `${release} after ${serving}: ${r.output}`);
  }
});

test("a release lower than the one that takes the traffic is refused before anything is built", () => {
  for (const [release, serving] of [["v0.1.9", "v0.2.0"], ["v0.2.9", "v0.2.10"]]) {
    const w = world({ release, serving });
    const r = w.run("release");
    assert.notEqual(r.status, 0, r.output);
    assert.match(r.stderr, new RegExp(`api ${release.replaceAll(".", "\\.")} is lower than ${serving.replaceAll(".", "\\.")}, which takes the traffic`));
    assert.deepEqual(steps(w.calls()), []);
  }
});

test("the release of the serving image must be told by one tag", () => {
  const untagged = world({ state: (s) => (s.tags = []) });
  const r = untagged.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /has no tag in the registry/);

  const twice = world({ state: (s) => s.tags.push({ image, tag: "v0.1.1", digest: "a".repeat(64) }) });
  const t = twice.run("release");
  assert.notEqual(t.status, 0);
  assert.match(t.stderr, /has more than one tag: v0\.1\.0 v0\.1\.1/);
});

test("traffic split between revisions is refused", () => {
  const w = world({
    state: (s) => {
      s.service.revisions["api-00002"] = { image: `${image}@sha256:${"b".repeat(64)}` };
      s.service.traffic = [{ revisionName: "api-00001", percent: 50 }, { revisionName: "api-00002", percent: 50 }];
    },
  });
  const r = w.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /is split between revisions api-00001 api-00002/);
});

test("with no service yet, the jobs alone: every image, check, migrate, and no revision", () => {
  const w = world({ serving: null });
  const r = w.run("release");
  assert.equal(r.status, 0, r.output);
  assert.match(r.stdout, /no service api yet/);
  assert.deepEqual(steps(w.calls()).filter((s) => s.startsWith("execute") || s === "revision" || s === "traffic"), ["execute api-check", "execute api-migrate"]);
  const s = w.read();
  for (const job of Object.values(s.jobs)) assert.match(job.image, new RegExp(`@sha256:${s.tags[0].digest}$`), "every job runs the new image");
});

test("a check or a migration that fails stops the deployment before any revision", () => {
  for (const [failing, ran] of [["api-check", ["execute api-check"]], ["api-migrate", ["execute api-check", "execute api-migrate"]]]) {
    const w = world({ state: (s) => (s.failJobs = [failing]) });
    const r = w.run("release");
    assert.notEqual(r.status, 0, r.output);
    assert.match(r.stderr, new RegExp(`the job ${failing} did not end well`));
    const done = steps(w.calls());
    assert.deepEqual(done.filter((s) => s.startsWith("execute")), ran);
    assert.ok(!done.includes("revision") && !done.includes("traffic"));
    const s = w.read();
    assert.deepEqual(s.service.traffic, [{ revisionName: "api-00001", percent: 100 }]);
    for (const job of ["api-daily", "api-after"]) {
      assert.equal(s.jobs[job].image, `${image}@sha256:${"f".repeat(64)}`, `${job} keeps its image while the migrations have not gone`);
    }
  }
});

test("a revision that is not ready takes no traffic", () => {
  const w = world({ state: (s) => (s.notReady = true) });
  const r = w.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /the revision api-00002 is not ready, and takes no traffic/);
  assert.ok(!steps(w.calls()).includes("traffic"));
  assert.deepEqual(w.read().service.traffic, [{ revisionName: "api-00001", percent: 100 }]);
});

test("the facts alone: a new version, the check of it on the serving image, and a revision on that image, with no build and no migration", () => {
  const w = world();
  const r = w.run("facts");
  assert.equal(r.status, 0, r.output);
  assert.deepEqual(steps(w.calls()), ["facts", "image api-check", "execute api-check", "revision", "traffic"]);
  const s = w.read();
  const serving = `${image}@sha256:${"a".repeat(64)}`;
  assert.deepEqual(s.service.revisions["api-00002"], { image: serving, factsFile: "/etc/api/admission/facts.json", facts: "api-admission-facts:1" });
  assert.deepEqual(s.executions, [{ job: "api-check", image: serving }], "the check runs on the image that takes the traffic, and no other job runs");
  assert.equal(s.jobs["api-check"].facts, "api-admission-facts:1", "the check runs on the new version of the facts");

  const refused = world({ state: (st) => (st.failJobs = ["api-check"]) });
  const stopped = refused.run("facts");
  assert.notEqual(stopped.status, 0);
  assert.match(stopped.stderr, /the job api-check did not end well/);
  assert.ok(!steps(refused.calls()).includes("revision"), "facts the check refuses reach no revision");
  assert.deepEqual(refused.read().service.traffic, [{ revisionName: "api-00001", percent: 100 }]);

  const unchecked = world({ outputs: (o) => (o.api_jobs = { migrate: jobs.migrate, daily: jobs.daily }) }).run("facts");
  assert.notEqual(unchecked.status, 0);
  assert.match(unchecked.stderr, /new facts do not go without api's check of them/);

  const none = world({ serving: null }).run("facts");
  assert.notEqual(none.status, 0);
  assert.match(none.stderr, /there is no service api to give the facts to/);
});

test("image builds around the binary alone, pushes and prints the digest", () => {
  const w = world({ serving: null });
  const r = w.run("image");
  assert.equal(r.status, 0, r.output);
  const pushed = w.read().tags.find((t) => t.tag === "v0.2.0");
  assert.match(r.stdout, new RegExp(`^IMAGE=${image.replaceAll(".", "\\.")}@sha256:${pushed.digest}$`, "m"));
  const build = w.calls().find((c) => c[0] === "docker" && c[1] === "build");
  assert.ok(build.includes("--target") && build[build.indexOf("--target") + 1] === "release");
  assert.deepEqual(steps(w.calls()), ["docker build", "docker push"]);
});

test("a file that fetch refuses stops before any build", () => {
  for (const file of ["api_v0.2.0_linux_amd64", "Dockerfile"]) {
    const w = world();
    const r = w.run("release", { REFUSE: file });
    assert.notEqual(r.status, 0, r.output);
    assert.match(r.stderr, new RegExp(`release-verify refused ${file}`));
    assert.deepEqual(steps(w.calls()), []);
  }
});

test("an output the configuration does not give is refused before anything runs", () => {
  const w = world({ outputs: (o) => delete o.api_jobs });
  const r = w.run("release");
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /the configuration's outputs name no api_jobs/);
  assert.deepEqual(w.calls(), []);
});

// A self-hosted copy: its own project, region and registry come from the configuration's outputs,
// and nothing of the platform's own deployment reaches a command, through a whole release (T29).
test("a copy's release runs on the copy's project, region and registry, every command of it", () => {
  const w = world({ project: "acme-learning-1", region: "europe-west3" });
  const r = w.run("release");
  assert.equal(r.status, 0, r.output);
  const calls = w.calls();
  assert.ok(steps(calls).includes("revision") && steps(calls).includes("execute api-migrate"), "the release went through");
  for (const call of calls.filter((c) => c[0] === "gcloud")) {
    // A command names the project by its flag, the path of the copy's image, or its registry's host.
    assert.ok(call.includes("--project=acme-learning-1") || call.some((a) => a.startsWith("europe-west3-docker.pkg.dev")), call.join(" "));
    if (call.some((a) => a.startsWith("--region="))) assert.ok(call.includes("--region=europe-west3"), call.join(" "));
  }
  assert.ok(JSON.stringify(calls).includes("europe-west3-docker.pkg.dev/acme-learning-1/images/api"), "the image is the copy's");
  const said = JSON.stringify(calls) + r.stdout;
  for (const platform of ["novatrail", "us-east4"]) assert.ok(!said.includes(platform), `${platform} reaches a command of the copy`);
});
