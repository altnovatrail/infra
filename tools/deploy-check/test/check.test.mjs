// The checks of the deployment's list, on synthetic releases: no network, and a stand-in for
// release-verify that refuses the file it is told to, both given to run() as the tests' stand-ins.
// Each refusal R05 names is made on its own, and a list that holds passes; the command line, which
// gives no stand-ins, is run where it needs no release. Run by `just deploy-check-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";
import { buildReadsSpecVersion, justProgram, Refusal, run } from "../check.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const main = path.join(here, "..", "main.mjs");

const made = [];
after(() => {
  for (const dir of made) fs.rmSync(dir, { recursive: true, force: true });
});

const hash = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");

// The build's schema of /deployment.json, synthetic: what the check reads from the archive.
const deploymentSchema = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $id: "https://altnovatrail.github.io/spec/deployment/1/deployment.schema.json",
  type: "object",
  properties: {
    format: { const: 1 },
    api: { type: "string", pattern: "^https://" },
    signIn: { type: "object" },
  },
  required: ["format", "api", "signIn"],
  unevaluatedProperties: false,
};

// /deployment.json, synthetic, of spec's deployment configuration 1.
const deployment = {
  format: 1,
  api: "https://api-example.a.run.app",
  signIn: { service: "firebase", apiKey: "synthetic-key", authDomain: "novatrail-test-0.firebaseapp.com", projectId: "novatrail-test-0", appId: "1:2:web:3" },
};

// An edit of the list's world that writes this deployment.json, and names it in the list.
const withDeployment = (value) => (l, w) => {
  const text = JSON.stringify(value);
  fs.writeFileSync(path.join(w.deploy, "production", "deployment.json"), text);
  l.app.deployment.sha256 = hash(text);
};

// The build's table of the CSP header, synthetic, with the place deployment.json fills.
const cspTable = { "default-src": "'none'", "script-src": "'self'", "connect-src": "'self' {api}" };

// A git repository with deploy/ and a folder of releases for each, the list on main at baseTag
// (or none), and the working tree's list at tag. `build` changes the build's folder before it is
// packed.
function world({ tag = "v0.2.0", baseTag = "v0.1.0", schema = deploymentSchema, csp = cspTable, build: change, edit } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-check-test-"));
  made.push(dir);
  const releases = path.join(dir, "releases");
  const repo = path.join(dir, "repo");
  const deploy = path.join(repo, "deploy");
  fs.mkdirSync(path.join(deploy, "production"), { recursive: true });

  const put = (repository, release, name, bytes) => {
    const folder = path.join(releases, repository, release);
    fs.mkdirSync(folder, { recursive: true });
    fs.writeFileSync(path.join(folder, name), bytes);
    fs.writeFileSync(path.join(folder, `${name}.sigstore.json`), "{}");
    return hash(bytes);
  };

  const binary = put("api", tag, `api_${tag}_linux_amd64`, `binary of ${tag}`);
  const dockerfile = put("api", tag, "Dockerfile", "FROM scratch\n");
  const build = path.join(dir, "build");
  fs.mkdirSync(path.join(build, "assets"), { recursive: true });
  fs.writeFileSync(path.join(build, "index.html"), "<!doctype html>");
  fs.writeFileSync(path.join(build, "assets", "index-1a2b3c.js"), "console.log(1)");
  if (schema) fs.writeFileSync(path.join(build, "deployment.schema.json"), JSON.stringify(schema));
  if (csp !== null) fs.writeFileSync(path.join(build, "csp.json"), JSON.stringify(csp));
  fs.writeFileSync(path.join(build, "NOTICE"), "Notices of the code this build bundles.\n");
  fs.writeFileSync(path.join(build, "LICENSE"), "Apache License, Version 2.0\n");
  change?.(build);
  const archivePath = path.join(dir, "app_v0.3.0.tar.gz");
  assert.equal(spawnSync("/usr/bin/tar", ["-czf", archivePath, "-C", build, "."]).status, 0);
  const archive = put("app", "v0.3.0", "app_v0.3.0.tar.gz", fs.readFileSync(archivePath));

  const deploymentText = JSON.stringify(deployment, null, 2) + "\n";
  fs.writeFileSync(path.join(deploy, "production", "deployment.json"), deploymentText);
  fs.writeFileSync(path.join(deploy, "production", "facts.json"), JSON.stringify({ openai: { data_processing_agreement: ["adult"] } }));

  const listOf = (release) => ({
    format: 1,
    api: { release, binary: { name: `api_${release}_linux_amd64`, sha256: binary }, dockerfile: { sha256: dockerfile } },
    app: { release: "v0.3.0", archive: { name: "app_v0.3.0.tar.gz", sha256: archive }, deployment: { sha256: hash(deploymentText) } },
    admission: { rung: "full" },
  });

  const g = (...args) => assert.equal(spawnSync("/usr/bin/git", ["-C", repo, ...args], { encoding: "utf8" }).status, 0, args.join(" "));
  g("init", "-q", "-b", "main");
  g("config", "user.email", "test@example.com");
  g("config", "user.name", "test");
  g("config", "commit.gpgsign", "false");
  if (baseTag) {
    fs.writeFileSync(path.join(deploy, "production.json"), JSON.stringify(listOf(baseTag)));
    g("add", "-A");
    g("commit", "-q", "-m", "base");
  } else {
    fs.writeFileSync(path.join(repo, "README"), "base");
    g("add", "-A");
    g("commit", "-q", "-m", "base");
  }
  const list = listOf(tag);
  edit?.(list, { deploy, releases });
  fs.writeFileSync(path.join(deploy, "production.json"), JSON.stringify(list, null, 2));

  // The stand-in for release-verify: given what to refuse, then the repository, the tag and the
  // file, it refuses a file whose name holds that, as release-verify would a file its bundle does not
  // hold.
  const verify = path.join(dir, "verify");
  fs.writeFileSync(verify, 'case "$4" in *"$1"*) echo "release-verify: the bundle does not hold $4" >&2; exit 1;; esac\necho "verified $2 $3 $4"\n');

  return {
    deploy,
    // What run() found: a pass, with its lines, or a failure, with every refusal as one text.
    async check({ base = "main", refuse = "//" } = {}) {
      try {
        const { lines, refusals } = await run(deploy, base, { releases, verifier: ["/bin/sh", verify, refuse] });
        return { ok: refusals.length === 0, stdout: lines.join("\n"), stderr: refusals.join("\n"), output: [...lines, ...refusals].join("\n") };
      } catch (error) {
        if (!(error instanceof Refusal)) throw error;
        return { ok: false, stdout: "", stderr: error.message, output: error.message };
      }
    },
    cli(...args) {
      const r = spawnSync(process.execPath, [main, ...args, deploy], { encoding: "utf8" });
      return { ...r, output: r.stdout + r.stderr };
    },
  };
}

test("a list that holds passes every check", async () => {
  const r = await world().check();
  assert.ok(r.ok, r.output);
  for (const line of [
    "the list holds to its schema",
    "api's binary is named by its release",
    "api v0.2.0: api_v0.2.0_linux_amd64 is verified, of the sha256 named",
    "api v0.2.0: the Dockerfile is verified, of the sha256 named",
    "app v0.3.0: app_v0.3.0.tar.gz is verified, of the sha256 named",
    "production/deployment.json is of the sha256 named",
    "app v0.3.0: app_v0.3.0.tar.gz holds a build to release",
    "production/deployment.json is accepted by spec's reading of the deployment configuration 1",
    "app v0.3.0 reads the deployment configuration 1, spec's at the submodule's tag",
    "production/deployment.json holds to its build's deployment.schema.json",
    "the build's csp.json makes the CSP header of production/deployment.json",
    "facts of spec's admission table",
    "the rung is full",
    "api v0.2.0 is no lower than v0.1.0 at main",
  ]) {
    assert.ok(r.stdout.includes(line), `${line}\n${r.output}`);
  }
});

test("the same tag of api as on the base passes", async () => {
  const r = await world({ tag: "v0.1.0", baseTag: "v0.1.0" }).check();
  assert.ok(r.ok, r.output);
});

test("a base with no list, or no base named, holds the tag to nothing", async () => {
  const first = await world({ baseTag: null }).check();
  assert.ok(first.ok, first.output);
  assert.match(first.stdout, /main has no list yet/);
  const none = await world().check({ base: null });
  assert.ok(none.ok, none.output);
  assert.match(none.stdout, /no base named/);
});

test("no list, where the base has none either, is nothing to check", async () => {
  const w = world({ baseTag: null });
  fs.rmSync(path.join(w.deploy, "production.json"));
  const r = await w.check();
  assert.ok(r.ok, r.output);
  assert.match(r.stdout, /is not there yet, and there is nothing to check/);
});

test("a list the base has is not removed, so that a lower api cannot come after", async () => {
  const w = world();
  fs.rmSync(path.join(w.deploy, "production.json"));
  const r = await w.check();
  assert.ok(!r.ok, r.output);
  assert.match(r.stderr, /production\.json is gone, and main has one/);
});

test("refusals, each on its own", async (t) => {
  const cases = [
    ["a field the schema does not know", { edit: (l) => (l.api.extra = 1) }, undefined, /does not hold to its schema: \/api must NOT have unevaluated properties: extra/],
    ["a tag that is not exact", { edit: (l) => (l.api.release = "latest") }, undefined, /does not hold to its schema/],
    ["a binary of another release", { edit: (l) => (l.api.binary.name = "api_v0.1.9_linux_amd64") }, undefined, /api's binary is api_v0\.1\.9_linux_amd64, and its release v0\.2\.0 names it api_v0\.2\.0_linux_amd64/],
    ["a binary of another sha256", { edit: (l) => (l.api.binary.sha256 = "0".repeat(64)) }, undefined, /api_v0\.2\.0_linux_amd64 of api v0\.2\.0 has sha256 [0-9a-f]{64}, and the list names 0{64}/],
    ["a Dockerfile release-verify refuses", {}, "Dockerfile", /release-verify refused Dockerfile of api v0\.2\.0: release-verify: the bundle does not hold/],
    ["an archive release-verify refuses", {}, "app_v0.3.0", /release-verify refused app_v0\.3\.0\.tar\.gz of app v0\.3\.0/],
    ["a file the release does not hold", { edit: (l, w) => fs.rmSync(path.join(w.releases, "api", "v0.2.0", "Dockerfile.sigstore.json")) }, undefined, /the release v0\.2\.0 of api holds no Dockerfile\.sigstore\.json/],
    ["a deployment.json of another sha256", { edit: (l) => (l.app.deployment.sha256 = "1".repeat(64)) }, undefined, /production\/deployment\.json has sha256 [0-9a-f]{64}, and the list names 1{64}/],
    ["a deployment.json larger than app reads", { edit: (l, w) => {
      const text = JSON.stringify({ format: 1, api: `https://${"a".repeat(17000)}.example` });
      fs.writeFileSync(path.join(w.deploy, "production", "deployment.json"), text);
      l.app.deployment.sha256 = hash(text);
    } }, undefined, /production\/deployment\.json is larger than the 16384 bytes app reads/],
    ["a deployment.json its build's schema refuses", { schema: { ...deploymentSchema, properties: { ...deploymentSchema.properties, api: { type: "string", pattern: "^http://" } } } }, undefined, /does not hold to the build's deployment\.schema\.json: \/api must match pattern/],
    ["a deployment.json its build's schema takes and spec's refuses", { edit: withDeployment({ ...deployment, signIn: { ...deployment.signIn, measurementId: "G-SYNTHETIC" } }) }, undefined, /production\/deployment\.json is refused by spec's deployment configuration 1, at signIn\.measurementId, by the schema/],
    ["an api not written as its origin", { edit: withDeployment({ ...deployment, api: "https://api-example.a.run.app:443" }) }, undefined, /refused by spec's deployment configuration 1, at api, by the rule deployment\.api-origin/],
    ["an api in clear text, with app on no loopback host", { edit: withDeployment({ ...deployment, api: "http://localhost:8080" }) }, undefined, /refused by spec's deployment configuration 1, at api, by the rule deployment\.loopback/],
    ["a build of another version of the deployment configuration", { schema: { ...deploymentSchema, $id: "https://altnovatrail.github.io/spec/deployment/2/deployment.schema.json" } }, undefined, /the build reads the deployment configuration 2, and spec at the submodule's tag is of 1: infra moves to a tag of spec of version 2 first/],
    ["a build's schema that names no version", { schema: { ...deploymentSchema, $id: undefined } }, undefined, /the build's deployment\.schema\.json names no version of spec's deployment configuration: its \$id is null/],
    ["a build with no schema", { schema: null }, undefined, /holds no deployment\.schema\.json at its root/],
    ["a build's schema of another dialect", { schema: { ...deploymentSchema, $schema: "http://json-schema.org/draft-07/schema#" } }, undefined, /is not of JSON Schema 2020-12/],
    ["a build with no csp.json", { csp: null }, undefined, /holds no csp\.json at its root/],
    ["a build with no NOTICE", { build: (b) => fs.rmSync(path.join(b, "NOTICE")) }, undefined, /holds no NOTICE at its root/],
    ["a build with no LICENSE", { build: (b) => fs.rmSync(path.join(b, "LICENSE")) }, undefined, /holds no LICENSE at its root/],
    ["a build with no asset", { build: (b) => fs.rmSync(path.join(b, "assets", "index-1a2b3c.js")) }, undefined, /holds no file under assets\//],
    ["a build with a deployment.json of its own", { build: (b) => fs.writeFileSync(path.join(b, "deployment.json"), "{}") }, undefined, /holds a deployment\.json of its own/],
    ["a build with a link", { build: (b) => fs.symlinkSync("/etc/passwd", path.join(b, "assets", "passwd")) }, undefined, /holds \.\/assets\/passwd, which is neither a file nor a folder/],
    ["a csp.json not of its shape", { csp: ["default-src 'none'"] }, undefined, /csp\.json is not a table of directives/],
    ["a csp.json with a place deployment.json does not fill", { csp: { ...cspTable, "img-src": "{images}" } }, undefined, /the place \{images\} in img-src, and only \{api\} and \{authDomain\} are filled/],
    ["a csp.json that would end its directive", { csp: { ...cspTable, "script-src": "'self'; script-src *" } }, undefined, /is not its sources as one string/],
    ["a csp.json framed by others", { csp: { ...cspTable, "frame-ancestors": "*" } }, undefined, /frame-ancestors \*, and app is framed by nobody/],
    ["a fact spec's table does not know", { edit: (l, w) => fs.writeFileSync(path.join(w.deploy, "production", "facts.json"), JSON.stringify({ openai: { signed_by_hand: ["adult"] } })) }, undefined, /names what spec's admission table does not: the fact signed_by_hand of openai/],
    ["a provider spec's table does not know", { edit: (l, w) => fs.writeFileSync(path.join(w.deploy, "production", "facts.json"), JSON.stringify({ acme: { data_processing_agreement: ["adult"] } })) }, undefined, /the provider acme/],
    ["facts not of their form", { edit: (l, w) => fs.writeFileSync(path.join(w.deploy, "production", "facts.json"), JSON.stringify({ openai: { data_processing_agreement: ["grown_up"] } })) }, undefined, /is not facts a deployment declares/],
    ["the rung author", { edit: (l) => (l.admission.rung = "author") }, undefined, /the rung is author, and a deployment ships full alone/],
    ["api lower than on the base", { tag: "v0.1.9", baseTag: "v0.2.0" }, undefined, /api v0\.1\.9 is lower than v0\.2\.0, the list's at main/],
    ["api lower by its minor, though higher by its patch", { tag: "v0.1.10", baseTag: "v0.2.0" }, undefined, /api v0\.1\.10 is lower than v0\.2\.0/],
    ["api lower by number, though higher as text", { tag: "v0.2.9", baseTag: "v0.2.10" }, undefined, /api v0\.2\.9 is lower than v0\.2\.10/],
  ];
  for (const [name, setup, refuse, message] of cases) {
    await t.test(name, async () => {
      const r = await world(setup).check({ refuse });
      assert.ok(!r.ok, `${name}: ${r.output}`);
      assert.match(r.stderr, message);
    });
  }
});

test("a build's schema refused for its version is refused once, and not checked again", async () => {
  const r = await world({ schema: { ...deploymentSchema, $id: undefined } }).check();
  assert.ok(!r.ok, r.output);
  assert.equal(r.stderr.match(/names no version of spec's deployment configuration/g)?.length, 1, r.output);
  assert.match(r.stdout, /is not checked against its build's schema: that schema was refused/);
});

test("a build of a version other than spec's says which side moves", () => {
  assert.throws(() => buildReadsSpecVersion({ version: 2 }, { version: 1 }), /infra moves to a tag of spec of version 2 first/);
  assert.throws(() => buildReadsSpecVersion({ version: 1 }, { version: 2 }), /reads the deployment configuration 1, older than 2, spec's at the submodule's tag: the list names a build of app that reads 2/);
  assert.doesNotThrow(() => buildReadsSpecVersion({ version: 1 }, { version: 1 }));
});

test("a higher tag by number, though lower as text, passes", async () => {
  for (const [tag, baseTag] of [["v0.10.0", "v0.9.0"], ["v0.2.10", "v0.2.9"]]) {
    const r = await world({ tag, baseTag }).check();
    assert.ok(r.ok, `${tag} over ${baseTag}: ${r.output}`);
  }
});

test("a refused file hides no other check: each file and the deployment.json are each said", async () => {
  const r = await world({ edit: (l) => (l.app.deployment.sha256 = "1".repeat(64)) }).check({ refuse: "linux_amd64" });
  assert.ok(!r.ok);
  assert.match(r.stderr, /release-verify refused api_v0\.2\.0_linux_amd64/);
  assert.match(r.stdout, /the Dockerfile is verified/);
  assert.match(r.stderr, /production\/deployment\.json has sha256/);
  assert.match(r.stdout, /production\/deployment\.json holds to its build's deployment\.schema\.json/);

  const archive = await world().check({ refuse: "app_v0.3.0" });
  assert.match(archive.stdout, /is not checked against its build's schema: app_v0\.3\.0\.tar\.gz was refused/);
  assert.match(archive.stdout, /the build's version of the deployment configuration is not read: app_v0\.3\.0\.tar\.gz was refused/);
  // spec's reading needs no build: it is said even when the build was refused.
  assert.match(archive.stdout, /production\/deployment\.json is accepted by spec's reading of the deployment configuration 1/);
});

test("the command line, which takes no stand-ins, says each outcome by its exit", () => {
  const none = world({ baseTag: null });
  fs.rmSync(path.join(none.deploy, "production.json"));
  const empty = none.cli("--base", "main");
  assert.equal(empty.status, 0, empty.output);
  assert.match(empty.stdout, /^deploy-check: .* is not there yet/m);

  const gone = world();
  fs.rmSync(path.join(gone.deploy, "production.json"));
  const refused = gone.cli("--base", "main");
  assert.equal(refused.status, 1, refused.output);
  assert.match(refused.stderr, /^deploy-check: production\.json is gone/m);

  const bad = world({ edit: (l) => (l.format = 2) });
  const schema = bad.cli();
  assert.equal(schema.status, 1, schema.output);
  assert.match(schema.stderr, /^deploy-check: the list does not hold to its schema/m);

  const usage = bad.cli("another-dir");
  assert.equal(usage.status, 1);
  assert.match(usage.stderr, /usage: deploy-check/);
});

test("a base that is not a commit is refused", async () => {
  const r = await world().check({ base: "origin/nowhere" });
  assert.ok(!r.ok);
  assert.match(r.stderr, /the base origin\/nowhere is not a commit here/);
});

test("every refusal is named, not only the first", async () => {
  const r = await world({ tag: "v0.1.9", baseTag: "v0.2.0", edit: (l) => (l.admission.rung = "author") }).check();
  assert.ok(!r.ok);
  assert.match(r.stderr, /the rung is author/);
  assert.match(r.stderr, /is lower than v0\.2\.0/);
});

test("release-verify runs by the just the recipe names, which on a runner of Deploy is not the toolchain stage's", () => {
  assert.equal(justProgram("/home/runner/work/_temp/tools/bin/just"), "/home/runner/work/_temp/tools/bin/just");
  for (const named of [undefined, "", "just", "bin/just"]) assert.equal(justProgram(named), "/usr/local/bin/just", `${named} is no absolute path`);

  // check.mjs in a process of its own, as fetch.mjs runs it, with INFRA_JUST at a stand-in for just
  // that writes down its arguments: verify reaches it, with spec's justfile and release-verify.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-check-just-"));
  made.push(dir);
  const just = path.join(dir, "just");
  fs.writeFileSync(just, `#!/bin/sh\nprintf '%s\\n' "$@" > ${JSON.stringify(path.join(dir, "args"))}\n`, { mode: 0o755 });
  const check = path.join(here, "..", "check.mjs");
  const r = spawnSync(process.execPath, ["--input-type=module", "-e", `import { verify } from ${JSON.stringify(check)}; verify("api", "v0.2.0", "/nowhere/api_v0.2.0_linux_amd64");`], {
    encoding: "utf8",
    env: { ...process.env, INFRA_JUST: just },
  });
  assert.equal(r.status, 0, r.stderr);
  const args = fs.readFileSync(path.join(dir, "args"), "utf8").trim().split("\n");
  assert.deepEqual(args.slice(0, 1), ["-f"]);
  assert.match(args[1], /spec\/justfile$/);
  assert.deepEqual(args.slice(2), ["release-verify", "api", "v0.2.0", "/nowhere/api_v0.2.0_linux_amd64"]);
});
