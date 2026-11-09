// app: the release of app's build on Firebase Hosting by the list, as R06 lays out its steps
// (R17), through Hosting's REST API rather than the Firebase CLI: the steps are five calls, and the
// CLI is a large program of somebody else's that asks for more than a release needs (R12).
//
//   node tools/deploy/app.mjs release <outputs.json> [<deploy dir>]
//   node tools/deploy/app.mjs check <outputs.json> [<deploy dir>]
//
// <outputs.json> is what `tofu output -json` prints after the apply: the site and its address are
// read from it. <deploy dir> is deploy/ by default. HOSTING_ACCESS_TOKEN is an OAuth access token
// of the identity that publishes, hosting-publish; the recipes of the justfile take it from gcloud.
//
// release:
//   1. production/deployment.json, of the sha256 the list names;
//   2. the archive of the list's build, through check.mjs's releaseFile — the sha256 and
//      release-verify again, so that what reaches production is the file verified (R05) — unpacked,
//      and deployment.json by the build's deployment.schema.json;
//   3. the build before, by the message of the live channel's release: none, and this is the first
//      release; a message not of this script's, and the release is refused; otherwise that build's
//      archive, through releaseFile too, and its assets/ into the folder, which keep a page loaded
//      before the release working (R06). The build before is the one released, or, when the list's
//      build is the one released already, the one whose assets that release kept: a release of the
//      same build again keeps what the first kept;
//   4. deployment.json into the folder;
//   5. a version of the folder with its configuration — the headers and the rewrite of R06 — its
//      files uploaded, finalized and released, with the message that names the build;
//   6. check.
// check: what the site answers, against the list's build (R06).

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";
import zlib from "node:zlib";
import { buildCsp, buildFiles, deploymentHoldsToItsBuild, deploymentOfTheList, readJson, readList, Refusal, releaseFile, ROOT, unpackBuild } from "../deploy-check/check.mjs";

export const HOSTING_API = "https://firebasehosting.googleapis.com/v1beta1";

// The live release's message, which says which build it is — the tag, the archive and its sha256,
// all three needed to verify a build again before its assets go into the next version — and, after
// "keeping", the build whose assets/ it kept, when it kept any.
const BUILD = "(v(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)) ([A-Za-z0-9][A-Za-z0-9._-]*\\.tar\\.gz) ([0-9a-f]{64})";
const MESSAGE = new RegExp(`^app ${BUILD}(?: keeping ${BUILD})?$`);

// Files read, gzipped and uploaded at once, at most.
const PARALLEL = 8;

const gzip = promisify(zlib.gzip);

// "You can send a maximum of 1000 file hashes in each API request" (Firebase, Deploy to your site
// using the Hosting REST API).
const BATCH = 1000;

const named = (build) => `${build.release} ${build.archive.name} ${build.archive.sha256}`;

export function releaseMessage(app, kept = null) {
  return `app ${named(app)}${kept ? ` keeping ${named(kept)}` : ""}`;
}

const same = (a, b) => a.release === b.release && a.archive.name === b.archive.name && a.archive.sha256 === b.archive.sha256;

// Each of the items through work, at most PARALLEL at a time, in no order.
async function inParallel(items, work) {
  const queue = [...items];
  await Promise.all(Array.from({ length: Math.min(PARALLEL, queue.length) }, async () => {
    while (queue.length) await work(queue.shift());
  }));
}

// The configuration of a version (R06). Two sets of paths that do not overlap, so that no header
// depends on which of two matching rules Hosting applies: outside /assets/** the CSP header and
// no-cache, since index.html and deployment.json change with every release and a path of the SPA
// is index.html; under /assets/**, whose names change with their content, immutable. Both get
// nosniff and HSTS, and nobody gets Cross-Origin-Opener-Policy: same-origin, which breaks the
// window of sign-in (R06). The rewrite takes a path outside /assets/** that holds no file to
// index.html — Hosting rewrites only a path no file is at — so that a file of /assets/ that is gone
// is a 404, not the page. The paths are matched before the rewrite, by the path asked for.
export function servingConfig(csp) {
  const outside = "!/@(assets)/**";
  const both = { "X-Content-Type-Options": "nosniff", "Strict-Transport-Security": "max-age=31536000" };
  return {
    headers: [
      { glob: outside, headers: { ...both, "Content-Security-Policy": csp, "Cache-Control": "no-cache" } },
      { glob: "/assets/**", headers: { ...both, "Cache-Control": "public, max-age=31536000, immutable" } },
    ],
    rewrites: [{ glob: outside, path: "/index.html" }],
  };
}

function siteOf(outputsFile) {
  const outputs = readJson(outputsFile, "the configuration's outputs");
  const value = (name) => {
    const found = outputs?.[name]?.value;
    if (typeof found !== "string" || !found) throw new Refusal(`the configuration's outputs name no ${name}`);
    return found;
  };
  return { site: value("hosting_site"), url: value("hosting_url").replace(/\/+$/, "") };
}

// The list's block of app, the list held to its schema, and its deployment.json, of the sha256
// named and no larger than app reads: the same refusals as the check of a pull request.
function theList(deployDir) {
  const { app } = readList(path.join(deployDir, "production.json"));
  const deploymentFile = path.join(deployDir, "production", "deployment.json");
  deploymentOfTheList(app, deploymentFile);
  return { app, deploymentFile };
}

// The list's build, verified, unpacked, its deployment.json held to its schema and its CSP header
// made.
async function theBuild(app, deploymentFile, work, standIns) {
  const archive = await releaseFile("app", app.release, app.archive.name, app.archive.sha256, path.join(work, "new"), standIns);
  const build = unpackBuild(archive, app.archive.name, path.join(work, "new-build"));
  deploymentHoldsToItsBuild(build, deploymentFile);
  return { build, csp: buildCsp(build, deploymentFile) };
}

function client(api, token) {
  if (!token) throw new Refusal("HOSTING_ACCESS_TOKEN is not set: the release signs in as hosting-publish with an access token");
  return async (method, url, { json, body, what } = {}) => {
    const headers = { Authorization: `Bearer ${token}` };
    if (json !== undefined) headers["Content-Type"] = "application/json";
    if (body !== undefined) headers["Content-Type"] = "application/octet-stream";
    let response;
    try {
      response = await fetch(url.startsWith("http") ? url : `${api}/${url}`, { method, headers, body: json !== undefined ? JSON.stringify(json) : body });
    } catch (error) {
      throw new Refusal(`Hosting cannot be reached for ${what}: ${error.message}`);
    }
    const text = await response.text();
    if (!response.ok) throw new Refusal(`Hosting answered ${response.status} to ${what}: ${text.slice(0, 400)}`);
    // An upload answers with no JSON; every other call answers with it.
    try {
      return text ? JSON.parse(text) : {};
    } catch {
      return {};
    }
  };
}

// The build the site serves now and the one whose assets its release kept, by the live release's
// message, or null when the site has no release.
async function released(call, site) {
  const live = await call("GET", `sites/${site}/channels/live`, { what: "the live channel" });
  if (!live.release) return null;
  const found = MESSAGE.exec(live.release.message ?? "");
  if (!found) {
    throw new Refusal(
      `the live release of ${site}, ${live.release.name ?? "unnamed"}, says ${JSON.stringify(live.release.message ?? "")}, and not which build it is: it was not made by this release, and its files cannot be verified to keep them`,
    );
  }
  const build = (at) => ({ release: found[at], archive: { name: found[at + 1], sha256: found[at + 2] } });
  return { build: build(1), kept: found[4] ? build(4) : null };
}

export async function release({ outputsFile, deployDir = path.join(ROOT, "deploy"), token, api = HOSTING_API, standIns = {}, fetchSite } = {}) {
  const { site, url } = siteOf(outputsFile);
  const { app, deploymentFile } = theList(deployDir);
  const call = client(api, token);
  const lines = [];
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-app-"));
  try {
    const { build, csp } = await theBuild(app, deploymentFile, work, standIns);
    lines.push(`app ${app.release}: ${app.archive.name} is verified and holds a build to release`);

    // The folder of the version: the new build, the assets of the one released, deployment.json.
    const files = new Map();
    const live = await released(call, site);
    const before = live && (same(live.build, app) ? live.kept : live.build);
    if (before) {
      const archive = await releaseFile("app", before.release, before.archive.name, before.archive.sha256, path.join(work, "old"), standIns);
      const old = unpackBuild(archive, before.archive.name, path.join(work, "old-build"));
      const kept = buildFiles(old).filter((file) => file.startsWith("assets/"));
      for (const file of kept) files.set(`/${file}`, path.join(old, file));
      lines.push(`app ${before.release} came before: its ${kept.length} files of assets/ are kept`);
    } else if (live) {
      lines.push(`app ${app.release} is released already, with no build before it kept: none is kept now either`);
    } else {
      lines.push(`${site} has no release yet: this is the first, with no build before it`);
    }
    for (const file of buildFiles(build)) files.set(`/${file}`, path.join(build, file));
    files.set("/deployment.json", deploymentFile);

    // Every file by the sha256 of its gzipped bytes, which is what Hosting names it by.
    const gzipped = new Map();
    const hashes = {};
    await inParallel([...files], async ([where, file]) => {
      const bytes = await gzip(await fs.promises.readFile(file), { level: 9 });
      const hash = crypto.createHash("sha256").update(bytes).digest("hex");
      hashes[where] = hash;
      gzipped.set(hash, bytes);
    });

    const version = await call("POST", `sites/${site}/versions`, { json: { config: servingConfig(csp), labels: { "deployment-tool": "novatrail-infra" } }, what: "a new version" });
    if (!version.name) throw new Refusal("Hosting made a version and named none");
    const required = new Set();
    let uploadUrl = null;
    const paths = Object.keys(hashes).sort();
    for (let i = 0; i < paths.length; i += BATCH) {
      const batch = Object.fromEntries(paths.slice(i, i + BATCH).map((where) => [where, hashes[where]]));
      const populated = await call("POST", `${version.name}:populateFiles`, { json: { files: batch }, what: `the files of ${version.name}` });
      for (const hash of populated.uploadRequiredHashes ?? []) required.add(hash);
      uploadUrl = populated.uploadUrl ?? uploadUrl;
    }
    if (required.size && !uploadUrl) throw new Refusal(`Hosting asked for ${required.size} files of ${version.name} and named nowhere to upload them`);
    for (const hash of required) if (!gzipped.has(hash)) throw new Refusal(`Hosting asked for a file of ${version.name} that is not in it: ${hash}`);
    await inParallel(required, (hash) => call("POST", `${uploadUrl}/${hash}`, { body: gzipped.get(hash), what: `the upload of ${hash}` }));
    lines.push(`${version.name}: ${paths.length} files, ${required.size} of them uploaded`);
    await call("PATCH", `${version.name}?update_mask=status`, { json: { status: "FINALIZED" }, what: `the finalizing of ${version.name}` });
    const made = await call("POST", `sites/${site}/releases?versionName=${encodeURIComponent(version.name)}`, { json: { message: releaseMessage(app, before) }, what: `the release of ${version.name}` });
    lines.push(`${made.name ?? version.name} released: app ${app.release}`);

    lines.push(...(await answers({ url, build, deploymentFile, csp, fetchSite })));
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
  return lines;
}

// What the site answers, against the build (R06): index.html's bytes, with its headers, at / and
// at a path of the SPA; a file of assets/ with its own; a 404 for a file of /assets/ that is not
// there; deployment.json as app reads it. Every answer is checked, and every one that is wrong is
// said.
async function answers({ url, build, deploymentFile, csp, fetchSite = fetch }) {
  const random = crypto.randomBytes(6).toString("hex");
  const index = fs.readFileSync(path.join(build, "index.html"));
  const asset = buildFiles(build).find((file) => file.startsWith("assets/"));
  const deployment = fs.readFileSync(deploymentFile);
  const wrong = [];
  const ask = async (where) => {
    try {
      const response = await fetchSite(`${url}${where}`, { redirect: "manual", headers: { "Cache-Control": "no-cache" } });
      return { status: response.status, headers: response.headers, body: Buffer.from(await response.arrayBuffer()) };
    } catch (error) {
      wrong.push(`${where} cannot be read: ${error.message}`);
      return null;
    }
  };
  const holds = (where, got, want) => {
    if (!got) return;
    if (got.status !== want.status) return wrong.push(`${where} answered ${got.status}, not ${want.status}`);
    if (want.body && !got.body.equals(want.body)) wrong.push(`${where} answered other bytes than ${want.of}`);
    for (const [name, value] of Object.entries(want.headers ?? {})) {
      const header = got.headers.get(name);
      if (value instanceof RegExp ? !value.test(header ?? "") : header !== value) wrong.push(`${where} sent ${name}: ${header ?? "nothing"}, not ${value}`);
    }
    const opener = got.headers.get("cross-origin-opener-policy");
    if (opener && /same-origin(?!-)/.test(opener)) wrong.push(`${where} sent Cross-Origin-Opener-Policy: ${opener}, which breaks the window of sign-in`);
  };
  const page = { "content-security-policy": csp, "x-content-type-options": "nosniff", "cache-control": /no-cache/, "strict-transport-security": /max-age=\d+/ };

  holds("/", await ask("/"), { status: 200, body: index, of: "index.html", headers: page });
  holds(`/lesson-${random}`, await ask(`/lesson-${random}`), { status: 200, body: index, of: "index.html", headers: page });
  holds(`/${asset}`, await ask(`/${asset}`), { status: 200, body: fs.readFileSync(path.join(build, asset)), of: asset, headers: { "x-content-type-options": "nosniff", "cache-control": /immutable/ } });
  holds(`/assets/gone-${random}.js`, await ask(`/assets/gone-${random}.js`), { status: 404 });
  holds("/deployment.json", await ask("/deployment.json"), { status: 200, body: deployment, of: "production/deployment.json", headers: { "content-type": /^application\/json/, "cache-control": /no-cache/ } });

  if (wrong.length) throw new Refusal(`${url} does not answer as the release has it:\n  ${wrong.join("\n  ")}`);
  return [`${url} answers as the release has it: the page at / and at a path of the SPA, ${asset}, a 404 under /assets/, deployment.json`];
}

export async function check({ outputsFile, deployDir = path.join(ROOT, "deploy"), standIns = {}, fetchSite } = {}) {
  const { url } = siteOf(outputsFile);
  const { app, deploymentFile } = theList(deployDir);
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-app-"));
  try {
    const { build, csp } = await theBuild(app, deploymentFile, work, standIns);
    return await answers({ url, build, deploymentFile, csp, fetchSite });
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
}

const USAGE = "usage: app release|check <outputs.json> [<deploy dir>]";

async function main(argv) {
  const [command, outputsFile, deployDir] = argv;
  if (!["release", "check"].includes(command) || !outputsFile || argv.length > 3) throw new Refusal(USAGE);
  const options = { outputsFile: path.resolve(outputsFile), deployDir: deployDir ? path.resolve(deployDir) : undefined };
  const lines = command === "release" ? await release({ ...options, token: process.env.HOSTING_ACCESS_TOKEN }) : await check(options);
  for (const line of lines) console.log(line);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof Refusal ? `app: ${error.message}` : error);
    process.exit(1);
  });
}
