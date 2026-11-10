// The release of app's build, tools/deploy/app.mjs, against a stand-in for Hosting's REST API on
// this machine, synthetic releases of app and a stand-in for release-verify, all given as the
// tests' stand-ins: no network, no cloud. What the site answers after the release is a stand-in
// too, built to answer as R06 has it, and broken one answer at a time. Run by
// `just deploy-app-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";
import zlib from "node:zlib";
import { check, release, releaseMessage, servingConfig } from "../app.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "app.mjs");

const made = [];
after(() => {
  for (const dir of made) fs.rmSync(dir, { recursive: true, force: true });
});

const hash = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");

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
const cspTable = {
  "default-src": "'none'",
  "script-src": "'self' https://apis.google.com",
  "connect-src": "'self' {api} https://identitytoolkit.googleapis.com",
  "frame-src": "https://{authDomain}",
};
const deployment = {
  format: 1,
  api: "https://api-example.a.run.app",
  signIn: { service: "firebase", apiKey: "synthetic-key", authDomain: "novatrail-test-0.firebaseapp.com", projectId: "novatrail-test-0", appId: "1:2:web:3" },
};
const wantedCsp =
  "default-src 'none'; script-src 'self' https://apis.google.com; connect-src 'self' https://api-example.a.run.app https://identitytoolkit.googleapis.com; frame-src https://novatrail-test-0.firebaseapp.com; frame-ancestors 'none'";

// The stand-in for Hosting's API: the live channel's release, the versions made, every call in
// order, the files uploaded by their hash. `known` are the hashes Hosting holds already and does
// not ask for; `fail` makes a call of that method and path answer 403.
let server;
let base;
const hosting = { reset() {
  Object.assign(this, { site: "novatrail-test-0", calls: [], live: {}, versions: {}, uploads: {}, known: new Set(), fail: null, released: null });
} };
hosting.reset();

before(async () => {
  server = http.createServer((req, res) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const body = Buffer.concat(chunks);
      const url = new URL(req.url, base);
      const call = `${req.method} ${url.pathname}${url.search}`;
      hosting.calls.push(call);
      const answer = (status, json) => {
        res.writeHead(status, { "Content-Type": "application/json" });
        res.end(json === undefined ? "" : JSON.stringify(json));
      };
      if (req.headers.authorization !== "Bearer synthetic-token") return answer(401, { error: "no token" });
      if (hosting.fail && call.startsWith(hosting.fail)) return answer(403, { error: { message: "denied" } });
      let m;
      if (req.method === "GET" && url.pathname === `/v1beta1/sites/${hosting.site}/channels/live`) return answer(200, { name: `sites/${hosting.site}/channels/live`, ...hosting.live });
      if (req.method === "POST" && url.pathname === `/v1beta1/sites/${hosting.site}/versions`) {
        const name = `sites/${hosting.site}/versions/v${Object.keys(hosting.versions).length + 1}`;
        hosting.versions[name] = { ...JSON.parse(body), files: {}, status: "CREATED" };
        return answer(200, { name, status: "CREATED" });
      }
      if (req.method === "POST" && (m = url.pathname.match(/^\/v1beta1\/(sites\/[a-z0-9-]+\/versions\/v\d+):populateFiles$/))) {
        const version = hosting.versions[m[1]];
        const { files } = JSON.parse(body);
        Object.assign(version.files, files);
        return answer(200, { uploadRequiredHashes: [...new Set(Object.values(files))].filter((h) => !hosting.known.has(h) && !hosting.uploads[h]), uploadUrl: `${base}/upload/${m[1]}` });
      }
      if (req.method === "POST" && (m = url.pathname.match(/^\/upload\/sites\/[a-z0-9-]+\/versions\/v\d+\/([0-9a-f]{64})$/))) {
        if (req.headers["content-type"] !== "application/octet-stream" || hash(body) !== m[1]) return answer(400, { error: "not the file of that hash" });
        hosting.uploads[m[1]] = body;
        return answer(200);
      }
      if (req.method === "PATCH" && (m = url.pathname.match(/^\/v1beta1\/(sites\/[a-z0-9-]+\/versions\/v\d+)$/)) && url.searchParams.get("update_mask") === "status") {
        const version = hosting.versions[m[1]];
        const missing = Object.values(version.files).filter((h) => !hosting.known.has(h) && !hosting.uploads[h]);
        if (missing.length) return answer(400, { error: "files not uploaded" });
        version.status = JSON.parse(body).status;
        return answer(200, { name: m[1], status: version.status });
      }
      if (req.method === "POST" && url.pathname === `/v1beta1/sites/${hosting.site}/releases`) {
        const versionName = url.searchParams.get("versionName");
        if (hosting.versions[versionName]?.status !== "FINALIZED") return answer(400, { error: "not finalized" });
        hosting.released = { versionName, message: JSON.parse(body).message };
        return answer(200, { name: `sites/${hosting.site}/releases/r1`, ...hosting.released });
      }
      answer(404, { error: `stub: no ${call}` });
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

// A folder of releases of app, a deploy/ with the list naming `tag`, and the configuration's
// outputs. `builds` are the tags to make, each with the assets it holds.
function world({ tag = "v0.3.0", builds = { "v0.3.0": ["index-new.js"], "v0.2.0": ["index-old.js"] }, change, edit } = {}) {
  hosting.reset();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-app-test-"));
  made.push(dir);
  const releases = path.join(dir, "releases");
  const archives = {};
  for (const [release, assets] of Object.entries(builds)) {
    const build = path.join(dir, "build", release);
    fs.mkdirSync(path.join(build, "assets"), { recursive: true });
    fs.writeFileSync(path.join(build, "index.html"), `<!doctype html><title>app ${release}</title>`);
    for (const asset of assets) fs.writeFileSync(path.join(build, "assets", asset), `// ${asset} of ${release}`);
    fs.writeFileSync(path.join(build, "deployment.schema.json"), JSON.stringify(deploymentSchema));
    fs.writeFileSync(path.join(build, "csp.json"), JSON.stringify(cspTable));
    if (release === tag) change?.(build);
    const name = `app_${release}.tar.gz`;
    const folder = path.join(releases, "app", release);
    fs.mkdirSync(folder, { recursive: true });
    assert.equal(spawnSync("/usr/bin/tar", ["-czf", path.join(folder, name), "-C", build, "."]).status, 0);
    fs.writeFileSync(path.join(folder, `${name}.sigstore.json`), "{}");
    archives[release] = { release, archive: { name, sha256: hash(fs.readFileSync(path.join(folder, name))) }, build };
  }

  const deploy = path.join(dir, "deploy");
  fs.mkdirSync(path.join(deploy, "production"), { recursive: true });
  const deploymentText = JSON.stringify(deployment, null, 2) + "\n";
  fs.writeFileSync(path.join(deploy, "production", "deployment.json"), deploymentText);
  const list = {
    format: 1,
    api: { release: "v0.1.5", binary: { name: "api_v0.1.5_linux_amd64", sha256: "1".repeat(64) }, dockerfile: { sha256: "2".repeat(64) } },
    app: { release: tag, archive: archives[tag].archive, deployment: { sha256: hash(deploymentText) } },
    admission: { rung: "full" },
  };
  edit?.(list, { deploy, archives });
  fs.writeFileSync(path.join(deploy, "production.json"), JSON.stringify(list));

  const outputsFile = path.join(dir, "outputs.json");
  fs.writeFileSync(outputsFile, JSON.stringify({ hosting_site: { value: "novatrail-test-0" }, hosting_url: { value: "https://novatrail-test-0.web.app" } }));

  const verify = path.join(dir, "verify");
  fs.writeFileSync(verify, 'case "$4" in *"$1"*) echo "release-verify: the bundle does not hold $4" >&2; exit 1;; esac\n');

  // The site as R06 has it answer, from the build of `tag` and deployment.json; `breaks` changes
  // one answer.
  const site = (breaks = {}) => async (url, options) => {
    assert.equal(options.redirect, "manual");
    const where = new URL(url).pathname;
    const own = archives[tag].build;
    const page = { "content-security-policy": wantedCsp, "x-content-type-options": "nosniff", "cache-control": "no-cache", "strict-transport-security": "max-age=31556926" };
    let answer;
    if (where.startsWith("/assets/")) {
      const file = path.join(own, where);
      answer = fs.existsSync(file)
        ? { status: 200, body: fs.readFileSync(file), headers: { "x-content-type-options": "nosniff", "cache-control": "public, max-age=31536000, immutable" } }
        : { status: 404, body: "not found", headers: {} };
    } else if (where === "/deployment.json") {
      answer = { status: 200, body: deploymentText, headers: { ...page, "content-type": "application/json" } };
    } else {
      answer = { status: 200, body: fs.readFileSync(path.join(own, "index.html")), headers: { ...page, "content-type": "text/html" } };
    }
    const broken = Object.entries(breaks).find(([prefix]) => where.startsWith(prefix))?.[1];
    if (broken) answer = broken(answer);
    return new Response(answer.body, { status: answer.status, headers: answer.headers });
  };

  const standIns = { releases, verifier: ["/bin/sh", verify, "//"] };
  return {
    archives,
    deploy,
    outputsFile,
    site,
    release: ({ breaks, token = "synthetic-token", refuse = "//" } = {}) =>
      release({ outputsFile, deployDir: deploy, token, api: `${base}/v1beta1`, standIns: { ...standIns, verifier: ["/bin/sh", verify, refuse] }, fetchSite: site(breaks) }),
    check: ({ breaks } = {}) => check({ outputsFile, deployDir: deploy, standIns, fetchSite: site(breaks) }),
  };
}

// The files of the version released, by path, unzipped.
function releasedFiles() {
  const version = hosting.versions[hosting.released.versionName];
  return Object.fromEntries(Object.entries(version.files).map(([where, h]) => [where, zlib.gunzipSync(hosting.uploads[h]).toString()]));
}

test("a first release: the build and deployment.json in one version, configured, finalized and released with the build named", async () => {
  const w = world();
  const lines = await w.release();
  assert.deepEqual(
    hosting.calls.map((c) => c.replace(/v\d+(?=[:?/]|$)/, "v*").replace(/\/[0-9a-f]{64}$/, "/<hash>")),
    [
      "GET /v1beta1/sites/novatrail-test-0/channels/live",
      "POST /v1beta1/sites/novatrail-test-0/versions",
      "POST /v1beta1/sites/novatrail-test-0/versions/v*:populateFiles",
      ...Array(5).fill("POST /upload/sites/novatrail-test-0/versions/v*/<hash>"),
      "PATCH /v1beta1/sites/novatrail-test-0/versions/v*?update_mask=status",
      `POST /v1beta1/sites/novatrail-test-0/releases?versionName=${encodeURIComponent("sites/novatrail-test-0/versions/")}v*`,
    ],
  );
  const files = releasedFiles();
  assert.deepEqual(Object.keys(files).sort(), ["/assets/index-new.js", "/csp.json", "/deployment.json", "/deployment.schema.json", "/index.html"]);
  assert.equal(files["/index.html"], "<!doctype html><title>app v0.3.0</title>");
  assert.deepEqual(JSON.parse(files["/deployment.json"]), deployment);
  assert.equal(hosting.released.message, releaseMessage({ release: "v0.3.0", archive: w.archives["v0.3.0"].archive }));
  assert.match(lines.join("\n"), /has no release yet: this is the first/);
  assert.match(lines.at(-1), /answers as the release has it/);
});

test("the version's configuration: the CSP header from csp.json and deployment.json, no-cache and immutable apart, the rewrite outside /assets/", async () => {
  await world().release();
  const { config, labels } = hosting.versions[hosting.released.versionName];
  assert.deepEqual(config, servingConfig(wantedCsp));
  assert.deepEqual(config, {
    headers: [
      {
        glob: "!/@(assets)/**",
        headers: { "X-Content-Type-Options": "nosniff", "Strict-Transport-Security": "max-age=31536000", "Content-Security-Policy": wantedCsp, "Cache-Control": "no-cache" },
      },
      { glob: "/assets/**", headers: { "X-Content-Type-Options": "nosniff", "Strict-Transport-Security": "max-age=31536000", "Cache-Control": "public, max-age=31536000, immutable" } },
    ],
    rewrites: [{ glob: "!/@(assets)/**", path: "/index.html" }],
  });
  assert.ok(!JSON.stringify(config).includes("Cross-Origin-Opener-Policy"));
  assert.deepEqual(labels, { "deployment-tool": "novatrail-infra" });
});

test("the next release keeps the assets of the build released, verified again, and takes everything else from the new one", async () => {
  const w = world();
  hosting.live = { release: { name: "sites/novatrail-test-0/releases/r0", message: releaseMessage(w.archives["v0.2.0"]) } };
  const lines = await w.release();
  const files = releasedFiles();
  assert.deepEqual(Object.keys(files).sort(), ["/assets/index-new.js", "/assets/index-old.js", "/csp.json", "/deployment.json", "/deployment.schema.json", "/index.html"]);
  assert.equal(files["/assets/index-old.js"], "// index-old.js of v0.2.0");
  assert.equal(files["/index.html"], "<!doctype html><title>app v0.3.0</title>");
  assert.match(lines.join("\n"), /app v0\.2\.0 came before: its 1 files of assets\/ are kept/);
  assert.equal(hosting.released.message, releaseMessage(w.archives["v0.3.0"], w.archives["v0.2.0"]));

  // The build released is verified again, and a refusal stops the release before any version.
  const again = world();
  hosting.live = { release: { name: "sites/novatrail-test-0/releases/r0", message: releaseMessage(again.archives["v0.2.0"]) } };
  await assert.rejects(again.release({ refuse: "app_v0.2.0" }), /release-verify refused app_v0\.2\.0\.tar\.gz/);
  assert.ok(!hosting.calls.some((c) => c.includes("/versions")), hosting.calls.join("\n"));
});

test("the same build released again keeps the assets the first release of it kept", async () => {
  const w = world();
  hosting.live = { release: { message: releaseMessage(w.archives["v0.3.0"], w.archives["v0.2.0"]) } };
  await w.release();
  assert.ok(Object.keys(releasedFiles()).includes("/assets/index-old.js"));
  assert.equal(hosting.released.message, releaseMessage(w.archives["v0.3.0"], w.archives["v0.2.0"]));

  // Released already with nothing kept, it keeps nothing again.
  const first = world();
  hosting.live = { release: { message: releaseMessage(first.archives["v0.3.0"]) } };
  const lines = await first.release();
  assert.deepEqual(Object.keys(releasedFiles()).filter((f) => f.startsWith("/assets/")), ["/assets/index-new.js"]);
  assert.match(lines.join("\n"), /is released already, with no build before it kept/);
  assert.equal(hosting.released.message, releaseMessage(first.archives["v0.3.0"]));
});

test("a file of the same path in both builds is the new build's", async () => {
  const w = world({ builds: { "v0.3.0": ["shared.js"], "v0.2.0": ["shared.js"] } });
  hosting.live = { release: { message: releaseMessage(w.archives["v0.2.0"]) } };
  await w.release();
  assert.equal(releasedFiles()["/assets/shared.js"], "// shared.js of v0.3.0");
});

test("only the files Hosting asks for are uploaded", async () => {
  const w = world();
  const known = zlib.gzipSync(fs.readFileSync(path.join(w.archives["v0.3.0"].build, "index.html")), { level: 9 });
  hosting.known.add(hash(known));
  await w.release();
  assert.equal(hosting.calls.filter((c) => c.startsWith("POST /upload/")).length, 4);
  assert.equal(hosting.versions[hosting.released.versionName].status, "FINALIZED");
});

test("more than a thousand files go in batches of a thousand", async () => {
  const many = Array.from({ length: 1001 }, (_, i) => `chunk-${i}.js`);
  await world({ builds: { "v0.3.0": many } }).release();
  assert.equal(hosting.calls.filter((c) => c.includes(":populateFiles")).length, 2);
  assert.equal(Object.keys(hosting.versions[hosting.released.versionName].files).length, 1005);
});

test("refusals before anything is made on Hosting", async (t) => {
  const cases = [
    ["a live release this script did not make", (w) => (hosting.live = { release: { name: "sites/novatrail-test-0/releases/r9", message: "Deployed from the console" } }), {}, /the live release of novatrail-test-0, sites\/novatrail-test-0\/releases\/r9, says "Deployed from the console", and not which build it is/],
    ["a deployment.json of another sha256", (w) => fs.appendFileSync(path.join(w.deploy, "production", "deployment.json"), " "), {}, /production\/deployment\.json has sha256 [0-9a-f]{64}, and the list names/],
    ["an archive release-verify refuses", () => {}, { refuse: "app_v0.3.0" }, /release-verify refused app_v0\.3\.0\.tar\.gz of app v0\.3\.0/],
    ["no token", () => {}, { token: "" }, /HOSTING_ACCESS_TOKEN is not set/],
    ["a list that does not hold to its schema", (w) => {
      const file = path.join(w.deploy, "production.json");
      const list = JSON.parse(fs.readFileSync(file, "utf8"));
      list.app.release = "v0.3.0-rc1";
      fs.writeFileSync(file, JSON.stringify(list));
    }, {}, /the list does not hold to its schema/],
  ];
  for (const [name, setup, options, message] of cases) {
    await t.test(name, async () => {
      const w = world();
      setup(w);
      await assert.rejects(w.release(options), message);
      assert.ok(!hosting.calls.some((c) => c.includes("/versions")), hosting.calls.join("\n"));
    });
  }

  await t.test("a build with a deployment.json of its own", async () => {
    const w = world({ change: (b) => fs.writeFileSync(path.join(b, "deployment.json"), "{}") });
    await assert.rejects(w.release(), /holds a deployment\.json of its own/);
  });
  await t.test("a build whose csp.json is not a table of directives", async () => {
    const w = world({ change: (b) => fs.writeFileSync(path.join(b, "csp.json"), JSON.stringify("default-src 'none'")) });
    await assert.rejects(w.release(), /csp\.json is not a table of directives/);
  });
  await t.test("a deployment.json its build's schema refuses", async () => {
    const w = world({ change: (b) => fs.writeFileSync(path.join(b, "deployment.schema.json"), JSON.stringify({ ...deploymentSchema, required: [...deploymentSchema.required, "extra"] })) });
    await assert.rejects(w.release(), /does not hold to the build's deployment\.schema\.json/);
  });
  await t.test("a deployment.json its build's schema takes and spec's reading refuses", async () => {
    const w = world({
      edit: (list, { deploy }) => {
        const text = JSON.stringify({ ...deployment, api: "http://localhost:8080" });
        fs.writeFileSync(path.join(deploy, "production", "deployment.json"), text);
        list.app.deployment.sha256 = hash(text);
      },
      change: (b) => fs.writeFileSync(path.join(b, "deployment.schema.json"), JSON.stringify({ ...deploymentSchema, properties: { ...deploymentSchema.properties, api: { type: "string" } } })),
    });
    await assert.rejects(w.release(), /refused by spec's deployment configuration 1, at api, by the rule deployment\.loopback/);
    assert.equal(hosting.calls.length, 0, "nothing is asked of Hosting");
  });
  await t.test("a build of another version of the deployment configuration", async () => {
    const w = world({ change: (b) => fs.writeFileSync(path.join(b, "deployment.schema.json"), JSON.stringify({ ...deploymentSchema, $id: "https://altnovatrail.github.io/spec/deployment/2/deployment.schema.json" })) });
    await assert.rejects(w.release(), /the build reads the deployment configuration 2, and spec at the submodule's tag is of 1/);
    assert.equal(hosting.calls.length, 0, "nothing is asked of Hosting");
  });
  for (const url of ["not a url", "foo://novatrail-test-0", "http://novatrail-test-0.web.app"]) {
    await t.test(`outputs whose hosting_url is ${url}`, async () => {
      const w = world();
      fs.writeFileSync(w.outputsFile, JSON.stringify({ hosting_site: { value: "novatrail-test-0" }, hosting_url: { value: url } }));
      await assert.rejects(w.release(), /name hosting_url .*, which is no https URL/);
      assert.equal(hosting.calls.length, 0, "nothing is asked of Hosting");
    });
  }
  await t.test("a deployment.json larger than app reads", async () => {
    const w = world({
      edit: (list, { deploy }) => {
        const text = JSON.stringify({ ...deployment, signIn: { ...deployment.signIn, apiKey: "k".repeat(17000) } });
        fs.writeFileSync(path.join(deploy, "production", "deployment.json"), text);
        list.app.deployment.sha256 = hash(text);
      },
    });
    await assert.rejects(w.release(), /larger than the 16384 bytes app reads/);
  });
});

test("an answer of Hosting that refuses is said, with its status", async () => {
  const w = world();
  hosting.fail = "POST /v1beta1/sites/novatrail-test-0/releases";
  await assert.rejects(w.release(), /Hosting answered 403 to the release of sites\/novatrail-test-0\/versions\/v1/);
});

test("the check after the release says every answer that is wrong", async (t) => {
  await t.test("the site as the release has it passes", async () => {
    assert.match((await world().check()).at(-1), /answers as the release has it/);
  });
  const cases = [
    ["no CSP at a path of the SPA", { "/lesson-": (a) => ({ ...a, headers: { ...a.headers, "content-security-policy": "default-src *" } }) }, /\/lesson-[0-9a-f]+ sent content-security-policy: default-src \*, not default-src 'none'/],
    ["the page in place of a file of /assets/ that is gone", { "/assets/gone-": () => ({ status: 200, body: "<!doctype html>", headers: {} }) }, /\/assets\/gone-[0-9a-f]+\.js answered 200, not 404/],
    ["an asset that is not immutable", { "/assets/index-new.js": (a) => ({ ...a, headers: { ...a.headers, "cache-control": "max-age=3600" } }) }, /\/assets\/index-new\.js sent cache-control: max-age=3600, not \/immutable\//],
    ["deployment.json of another type", { "/deployment.json": (a) => ({ ...a, headers: { ...a.headers, "content-type": "text/plain" } }) }, /\/deployment\.json sent content-type: text\/plain/],
    ["deployment.json moved elsewhere", { "/deployment.json": () => ({ status: 301, body: "", headers: { location: "/index.html" } }) }, /\/deployment\.json answered 301, not 200/],
    ["another page at /", { "/": (a) => (a.headers["content-type"] === "text/html" ? { ...a, body: "<!doctype html><title>old</title>" } : a) }, /^ {2}\/ answered other bytes than index\.html$/m],
    ["Cross-Origin-Opener-Policy: same-origin", { "/": (a) => ({ ...a, headers: { ...a.headers, "cross-origin-opener-policy": "same-origin" } }) }, /sent Cross-Origin-Opener-Policy: same-origin, which breaks the window of sign-in/],
    ["no nosniff on a file of /assets/", { "/assets/index-new.js": (a) => ({ ...a, headers: { "cache-control": "immutable" } }) }, /\/assets\/index-new\.js sent x-content-type-options: nothing, not nosniff/],
  ];
  for (const [name, breaks, message] of cases) {
    await t.test(name, async () => {
      await assert.rejects(world().check({ breaks }), message);
    });
  }
  await t.test("every wrong answer, not the first only", async () => {
    await assert.rejects(world().check({ breaks: { "/assets/gone-": () => ({ status: 200, body: "", headers: {} }), "/deployment.json": (a) => ({ ...a, headers: { ...a.headers, "content-type": "text/plain" } }) } }), (error) => {
      assert.match(error.message, /answered 200, not 404/);
      assert.match(error.message, /sent content-type: text\/plain/);
      return true;
    });
  });
});

test("the command line says how it is used, and refuses with no token before any network", () => {
  const usage = spawnSync(process.execPath, [script, "publish"], { encoding: "utf8" });
  assert.equal(usage.status, 1);
  assert.match(usage.stderr, /usage: app release\|check <outputs\.json> \[<deploy dir>\]/);

  const w = world();
  const noToken = spawnSync(process.execPath, [script, "release", w.outputsFile, w.deploy], { encoding: "utf8", env: { ...process.env, HOSTING_ACCESS_TOKEN: "" } });
  assert.equal(noToken.status, 1);
  assert.match(noToken.stderr, /^app: HOSTING_ACCESS_TOKEN is not set/m);
});

// A self-hosted copy: the site and its address come from the configuration's outputs, and every
// call to Hosting names the copy's site, through to the release (T29).
test("a copy's release goes to the copy's site, every call of it", async () => {
  const w = world();
  hosting.site = "acme-learning-1";
  fs.writeFileSync(w.outputsFile, JSON.stringify({ hosting_site: { value: "acme-learning-1" }, hosting_url: { value: "https://acme-learning-1.web.app" } }));
  await w.release();
  assert.match(hosting.released.versionName, /^sites\/acme-learning-1\/versions\/v\d+$/);
  assert.ok(hosting.calls.length > 5, "the release went through");
  for (const call of hosting.calls) {
    assert.match(call, /\/sites\/acme-learning-1\//, call);
    assert.doesNotMatch(call, /novatrail/, call);
  }
});
