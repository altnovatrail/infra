// deploy-check's checks: what CI asks of a pull request that changes the deployment's list,
// with no access to production (R05, R14). main.mjs runs them; the tests import them.
//
// It reads <deploy dir>/production.json, deploy/ by default, and holds it, in R05's order, to:
//   1. its own schema, deploy/schema/production.schema.json;
//   2. the name api's release gives its binary, api_<tag>_linux_amd64 (R28 api);
//   3. the files of both releases — api's binary and Dockerfile, app's archive —, each downloaded
//      with its bundle from the release on GitHub, accepted by spec's release-verify and of the
//      sha256 the list names (R77 spec);
//   4. production/deployment.json, by the deployment.schema.json of the archive of that build, and
//      of the sha256 the list names;
//   5. production/facts.json, by the facts a deployment declares in spec's admission schemas, with
//      every provider and fact of the dictionary of spec's admission table, at the tag of the
//      submodule: an early sign, since api checks the file again with its own table (R25 api);
//   6. the rung full;
//   7. api's tag no lower than in the list at <ref>, the main a pull request merges into; with no
//      list there, nothing to hold it to.
// A list that fails its schema is refused there; every other check runs, each says what it found,
// and any refusal fails the run. With no production.json there is nothing to check yet, and it says
// so, unless the base has one: a list once there is not removed.

import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const Ajv2020 = require("ajv/dist/2020").default;

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SPEC = path.join(ROOT, "spec");
const LIST_SCHEMA = path.join(ROOT, "deploy", "schema", "production.schema.json");
const ORGANIZATION = "altnovatrail";
const DIALECT = "https://json-schema.org/draft/2020-12/schema";
const TAG = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

export class Refusal extends Error {}

function readJson(file, what) {
  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    throw new Refusal(`${what} is not there: ${file}`);
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Refusal(`${what} is not JSON: ${error.message}`);
  }
}

// A validator of JSON Schema 2020-12, with spec's own options (spec/tools/format-check/schemas.mjs):
// every error rather than the first; a keyword it does not know is an error, never a check skipped
// without a word; format an annotation only, as 2020-12 has it by default; and strictTypes and
// strictTuples off, which would refuse conventions spec's schemas keep.
function ajv() {
  return new Ajv2020({ allErrors: true, validateFormats: false, strictTypes: false, strictTuples: false });
}

function explain(errors) {
  return errors.map((e) => `${e.instancePath || "/"} ${e.message}${e.params?.unevaluatedProperty ? `: ${e.params.unevaluatedProperty}` : ""}`).join("; ");
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function compare(a, b) {
  const [x, y] = [a, b].map((tag) => tag.match(TAG).slice(1).map(Number));
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
}

// A file of a release, with its bundle beside it, into the work folder: from GitHub, or, for the
// tests, from a folder of <repository>/<tag>/<file>.
async function fetchRelease(repository, tag, name, work, releases) {
  const folder = path.join(work, repository, tag);
  fs.mkdirSync(folder, { recursive: true });
  for (const file of [name, `${name}.sigstore.json`]) {
    const target = path.join(folder, file);
    if (releases) {
      const source = path.join(releases, repository, tag, file);
      if (!fs.existsSync(source)) throw new Refusal(`the release ${tag} of ${repository} holds no ${file}`);
      fs.copyFileSync(source, target);
      continue;
    }
    const url = `https://github.com/${ORGANIZATION}/${repository}/releases/download/${encodeURIComponent(tag)}/${encodeURIComponent(file)}`;
    let response;
    try {
      response = await fetch(url, { redirect: "follow" });
    } catch (error) {
      throw new Refusal(`${url} cannot be read: ${error.message}`);
    }
    if (response.status === 404) throw new Refusal(`the release ${tag} of ${repository} holds no ${file}`);
    if (!response.ok) throw new Refusal(`${url} answered ${response.status}`);
    fs.writeFileSync(target, Buffer.from(await response.arrayBuffer()));
  }
  return path.join(folder, name);
}

// spec's release-verify, as RULES.md has a repository run it, or, for the tests, a command that
// stands in for it with the same arguments.
export function verify(repository, tag, file, command = ["just", "-f", path.join(SPEC, "justfile"), "release-verify"]) {
  const run = spawnSync(command[0], [...command.slice(1), repository, tag, file], { encoding: "utf8" });
  if (run.error) throw new Refusal(`${command[0]} cannot be run: ${run.error.message}`);
  if (run.status !== 0) throw new Refusal(`release-verify refused ${path.basename(file)} of ${repository} ${tag}: ${(run.stderr || run.stdout).trim()}`);
}

// A file of a release, of the sha256 the list names and accepted by release-verify.
export async function releaseFile(repository, tag, name, want, work, { releases, verifier } = {}) {
  const file = await fetchRelease(repository, tag, name, work, releases);
  const got = sha256(file);
  if (got !== want) throw new Refusal(`${name} of ${repository} ${tag} has sha256 ${got}, and the list names ${want}`);
  verify(repository, tag, file, verifier);
  return file;
}

function git(cwd, args) {
  return spawnSync("git", ["-C", cwd, ...args], { encoding: "utf8" });
}

// The list at the base, or null when the base has none.
function baseList(base, deployDir) {
  const top = git(deployDir, ["rev-parse", "--show-toplevel"]);
  if (top.status !== 0) throw new Refusal(`${deployDir} is not in a git repository, and the base ${base} cannot be read`);
  const root = top.stdout.trim();
  if (git(root, ["rev-parse", "--verify", "--quiet", `${base}^{commit}`]).status !== 0) {
    throw new Refusal(`the base ${base} is not a commit here: fetch it before the check`);
  }
  const relative = path.relative(root, path.join(fs.realpathSync(deployDir), "production.json")).split(path.sep).join("/");
  if (git(root, ["cat-file", "-e", `${base}:${relative}`]).status !== 0) return null;
  const shown = git(root, ["show", `${base}:${relative}`]);
  try {
    return JSON.parse(shown.stdout);
  } catch (error) {
    throw new Refusal(`the list at ${base} is not JSON: ${error.message}`);
  }
}

// /deployment.json against the deployment.schema.json at the root of the build's archive.
function deploymentHoldsToItsBuild(archive, archiveName, deploymentFile, work) {
  const unpacked = path.join(work, "app-build");
  fs.mkdirSync(unpacked);
  const tar = spawnSync("tar", ["-xzf", archive, "-C", unpacked, "--no-same-owner", "--no-same-permissions"], { encoding: "utf8" });
  if (tar.status !== 0) throw new Refusal(`${archiveName} cannot be unpacked: ${tar.stderr.trim()}`);
  const schemaFile = path.join(unpacked, "deployment.schema.json");
  if (!fs.existsSync(schemaFile)) throw new Refusal(`${archiveName} holds no deployment.schema.json at its root`);
  const schema = readJson(schemaFile, "the build's deployment.schema.json");
  if (schema.$schema !== DIALECT) throw new Refusal(`the build's deployment.schema.json is not of JSON Schema 2020-12, but ${schema.$schema ?? "of no dialect named"}`);
  let check;
  try {
    check = ajv().compile(schema);
  } catch (error) {
    throw new Refusal(`the build's deployment.schema.json cannot be read: ${error.message}`);
  }
  if (!check(readJson(deploymentFile, "production/deployment.json"))) {
    throw new Refusal(`production/deployment.json does not hold to the build's deployment.schema.json: ${explain(check.errors)}`);
  }
}

// production/facts.json against the facts a deployment declares in spec's admission schemas, and
// every provider and fact it names against the dictionary of spec's admission table.
function factsHoldToTheTable(factsFile) {
  const facts = readJson(factsFile, "production/facts.json");
  const schemas = path.join(SPEC, "admission", "schemas");
  const validator = ajv();
  const table = readJson(path.join(schemas, "admission-table.schema.json"), "spec's schema of the admission table");
  const answers = readJson(path.join(schemas, "answer-vector.schema.json"), "spec's schema of a vector of answers");
  let check;
  try {
    validator.addSchema(table).addSchema(answers);
    check = validator.getSchema(`${answers.$id}#/$defs/declared_facts`);
  } catch (error) {
    throw new Refusal(`spec's admission schemas cannot be read: ${error.message}`);
  }
  if (!check) throw new Refusal(`spec's admission schemas give no $defs/declared_facts in ${answers.$id}, which the check of the facts reads`);
  if (!check(facts)) throw new Refusal(`production/facts.json is not facts a deployment declares: ${explain(check.errors)}`);
  const dictionary = readJson(path.join(SPEC, "admission", "admission-table.json"), "spec's admission table");
  const unknown = [];
  for (const [provider, declared] of Object.entries(facts)) {
    if (!Object.hasOwn(dictionary.providers, provider)) unknown.push(`the provider ${provider}`);
    for (const fact of Object.keys(declared)) if (!Object.hasOwn(dictionary.facts, fact)) unknown.push(`the fact ${fact} of ${provider}`);
  }
  if (unknown.length) throw new Refusal(`production/facts.json names what spec's admission table does not: ${unknown.join(", ")}`);
}

// Each check in turn, every one of them run whatever an earlier one found: its line when it passes,
// its refusal when it does not. A check that stands on a file an earlier one refused says it is not
// run. `stand-ins` are the tests' alone: `releases`, a folder to read the releases from instead of
// GitHub, and `verifier`, a command to run instead of release-verify; main.mjs never gives them.
export async function run(deployDir, base, standIns = {}) {
  const listFile = path.join(deployDir, "production.json");
  if (!fs.existsSync(listFile)) {
    // A list once on main is not taken away by a pull request: the next list would then be held to
    // no tag of api, and api goes forward only (R05).
    if (base && baseList(base, deployDir)) throw new Refusal(`production.json is gone, and ${base} has one: a pull request changes the list, it does not remove it`);
    return { lines: [`deploy-check: ${listFile} is not there yet, and there is nothing to check`], refusals: [] };
  }
  const list = readJson(listFile, "the list");
  const validate = ajv().compile(readJson(LIST_SCHEMA, "the list's schema"));
  if (!validate(list)) throw new Refusal(`the list does not hold to its schema: ${explain(validate.errors)}`);

  const lines = ["the list holds to its schema"];
  const refusals = [];
  const step = async (what, check) => {
    try {
      const line = await check();
      lines.push(line ?? what);
      return true;
    } catch (error) {
      if (!(error instanceof Refusal)) throw error;
      refusals.push(error.message);
      return false;
    }
  };
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-check-"));
  try {
    const { api, app } = list;
    const deploymentFile = path.join(deployDir, "production", "deployment.json");
    let archive = null;
    await step("api's binary is named by its release", () => {
      const want = `api_${api.release}_linux_amd64`;
      if (api.binary.name !== want) throw new Refusal(`api's binary is ${api.binary.name}, and its release ${api.release} names it ${want}`);
    });
    await step(`api ${api.release}: ${api.binary.name} is verified, of the sha256 named`, () =>
      releaseFile("api", api.release, api.binary.name, api.binary.sha256, path.join(work, "binary"), standIns).then(() => undefined),
    );
    await step(`api ${api.release}: the Dockerfile is verified, of the sha256 named`, () =>
      releaseFile("api", api.release, "Dockerfile", api.dockerfile.sha256, path.join(work, "dockerfile"), standIns).then(() => undefined),
    );
    await step(`app ${app.release}: ${app.archive.name} is verified, of the sha256 named`, async () => {
      archive = await releaseFile("app", app.release, app.archive.name, app.archive.sha256, path.join(work, "archive"), standIns);
    });
    await step("production/deployment.json is of the sha256 named", () => {
      const got = fs.existsSync(deploymentFile) ? sha256(deploymentFile) : null;
      if (!got) throw new Refusal("production/deployment.json is not there");
      if (got !== app.deployment.sha256) throw new Refusal(`production/deployment.json has sha256 ${got}, and the list names ${app.deployment.sha256}`);
    });
    await step("production/deployment.json holds to its build's deployment.schema.json", () => {
      if (!archive) return `production/deployment.json is not checked against its build's schema: ${app.archive.name} was refused`;
      if (!fs.existsSync(deploymentFile)) return "production/deployment.json is not checked against its build's schema: it is not there";
      deploymentHoldsToItsBuild(archive, app.archive.name, deploymentFile, work);
    });
    await step("production/facts.json declares facts of spec's admission table", () => factsHoldToTheTable(path.join(deployDir, "production", "facts.json")));
    await step("the rung is full", () => {
      if (list.admission.rung !== "full") throw new Refusal(`the rung is ${list.admission.rung}, and a deployment ships full alone (R25 api)`);
    });
    await step("api's tag is no lower than on the base", () => {
      if (!base) return "api's tag: no base named, nothing to hold it to";
      const before = baseList(base, deployDir);
      if (!before) return `api's tag: ${base} has no list yet, nothing to hold it to`;
      const was = before?.api?.release;
      if (typeof was !== "string" || !TAG.test(was)) throw new Refusal(`the list at ${base} names no tag of api`);
      if (compare(api.release, was) < 0) throw new Refusal(`api ${api.release} is lower than ${was}, the list's at ${base}: api goes forward only (R05)`);
      return `api ${api.release} is no lower than ${was} at ${base}`;
    });
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
  return { lines, refusals };
}
