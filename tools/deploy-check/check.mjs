// deploy-check's checks: what CI asks of a pull request that changes the deployment's list,
// with no access to production (R05, R14). main.mjs runs them; the tests import them.
//
// It reads <deploy dir>/production.json, deploy/ by default, and holds it, in R05's order, to:
//   1. its own schema, deploy/schema/production.schema.json;
//   2. the name api's release gives its binary, api_<tag>_linux_amd64 (R28 api);
//   3. the files of both releases — api's binary and Dockerfile, app's archive —, each downloaded
//      with its bundle from the release on GitHub, accepted by spec's release-verify and of the
//      sha256 the list names (R77 spec);
//   4. production/deployment.json, of the sha256 the list names; accepted by spec's reading of the
//      deployment configuration at the tag of the submodule — its schema and its rules — and by the
//      deployment.schema.json of the archive of that build, whose version is spec's (R85 spec); the
//      archive holding what a release of the build is made of, and its csp.json making the header
//      of that deployment.json (R17); its api, the address of api's service, the output api_origin,
//      by the project tofu/ci.env names and the values of tofu/production.auto.tfvars (R05);
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
import { readingOf } from "./reading.mjs";
import { PROVIDER } from "./setup.mjs";

const require = createRequire(import.meta.url);
const Ajv2020 = require("ajv/dist/2020").default;

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SPEC = path.join(ROOT, "spec");
const LIST_SCHEMA = path.join(ROOT, "deploy", "schema", "production.schema.json");
// The path of the schema of /deployment.json stays the same from version to version, and its $id
// names the version (spec's deployment/README.md, section 3).
const SPEC_DEPLOYMENT_SCHEMA = path.join(SPEC, "deployment", "schemas", "deployment.schema.json");
const DEPLOYMENT_ID = /^https:\/\/altnovatrail\.github\.io\/spec\/deployment\/([1-9]\d*)\/deployment\.schema\.json$/;
// The platform's app is open on Hosting, at https://<site>.web.app (R06), never on a loopback host.
// A pull request's check knows no site, and the rules of reading look at no more of the origin than
// whether its host is a loopback one: it reads the file at the origin of web.app itself.
export const HOSTED_ORIGIN = "https://web.app";
const ORGANIZATION = "altnovatrail";
const DIALECT = "https://json-schema.org/draft/2020-12/schema";
const TAG = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

// The programs the checks run, by absolute path, as spec's tools run theirs (spec/tools/shared.mjs):
// no directory on PATH decides which program runs. just is the one that runs the recipe, whose path
// the justfile exports as INFRA_JUST: the toolchain stage's /usr/local/bin/just, or, on a runner of
// the workflow Deploy, the one tools/ci/install.sh put in a folder no fixed path names (T24). Run
// outside a recipe, it is the toolchain stage's. git is the devcontainers base image's, or else the
// system's; tar the system's.
const JUST = justProgram(process.env.INFRA_JUST);
const GIT = first(["/usr/local/bin/git", "/usr/bin/git", "/bin/git"]);
const TAR = first(["/usr/bin/tar", "/bin/tar"]);

// The just that runs release-verify: the absolute path a recipe names, or the toolchain stage's.
export function justProgram(named) {
  return named && path.isAbsolute(named) ? named : first(["/usr/local/bin/just"]);
}

// The first of the paths that exists, or the first of them, which then fails by its own name.
function first(paths) {
  return paths.find((program) => fs.existsSync(program)) ?? paths[0];
}

export class Refusal extends Error {}

export function readJson(file, what) {
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

export function sha256(file) {
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
export function verify(repository, tag, file, command = [JUST, "-f", path.join(SPEC, "justfile"), "release-verify"]) {
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
  return spawnSync(GIT, ["-C", cwd, ...args], { encoding: "utf8" });
}

// The top of the git repository deployDir is in; `unread` says what is lost when it is in none.
function repositoryOf(deployDir, unread) {
  const top = git(deployDir, ["rev-parse", "--show-toplevel"]);
  if (top.status !== 0) throw new Refusal(`${deployDir} is not in a git repository, and ${unread}`);
  return top.stdout.trim();
}

// The list at the base, or null when the base has none.
function baseList(base, deployDir) {
  const root = repositoryOf(deployDir, `the base ${base} cannot be read`);
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

// app reads /deployment.json only if it is no larger (architecture 3.7 app).
const DEPLOYMENT_LIMIT = 16 * 1024;

// The list of <deploy dir>, held to its schema: what the release of either part reads it as.
export function readList(listFile) {
  const list = readJson(listFile, "the list");
  const validate = ajv().compile(readJson(LIST_SCHEMA, "the list's schema"));
  if (!validate(list)) throw new Refusal(`the list does not hold to its schema: ${explain(validate.errors)}`);
  return list;
}

// production/deployment.json as the list names it: there, of the sha256 named, and no larger than
// app reads.
export function deploymentOfTheList(app, deploymentFile) {
  if (!fs.existsSync(deploymentFile)) throw new Refusal("production/deployment.json is not there");
  const got = sha256(deploymentFile);
  if (got !== app.deployment.sha256) throw new Refusal(`production/deployment.json has sha256 ${got}, and the list names ${app.deployment.sha256}`);
  if (fs.statSync(deploymentFile).size > DEPLOYMENT_LIMIT) throw new Refusal(`production/deployment.json is larger than the ${DEPLOYMENT_LIMIT} bytes app reads`);
}

// What a build of app holds at the root of its archive, and what a release of it is made of: its
// page, its assets, the schema of /deployment.json, the table of the CSP header and the notices of
// the licenses of what it bundles, NOTICE and LICENSE (the 2026-11-11 amendment to R85 spec); never
// a deployment.json of its own, which is the deployment's (architecture 3.7 app; R17).
const BUILD_FILES = ["index.html", "deployment.schema.json", "csp.json", "NOTICE", "LICENSE"];

// The archive of a build unpacked into dir, once its listing shows nothing but files and folders
// under it: no link, no device, no path that is absolute or climbs out with "..". The release is
// verified before this, and the listing is read all the same, since what is unpacked here is
// published on the platform's own address.
export function unpackBuild(archive, archiveName, dir) {
  const names = spawnSync(TAR, ["-tzf", archive], { encoding: "utf8" });
  const kinds = spawnSync(TAR, ["-tvzf", archive], { encoding: "utf8" });
  if (names.status !== 0 || kinds.status !== 0) throw new Refusal(`${archiveName} cannot be read: ${(names.stderr || kinds.stderr).trim()}`);
  const listed = names.stdout.split("\n").filter(Boolean);
  const types = kinds.stdout.split("\n").filter(Boolean).map((line) => line[0]);
  if (listed.length !== types.length) throw new Refusal(`${archiveName} holds a name that cannot be read as one line`);
  for (const [i, name] of listed.entries()) {
    if (types[i] !== "-" && types[i] !== "d") throw new Refusal(`${archiveName} holds ${name}, which is neither a file nor a folder`);
    if (name.startsWith("/") || name.split("/").includes("..")) throw new Refusal(`${archiveName} holds ${name}, a path out of the build`);
  }
  fs.mkdirSync(dir, { recursive: true });
  const tar = spawnSync(TAR, ["-xzf", archive, "-C", dir, "--no-same-owner", "--no-same-permissions"], { encoding: "utf8" });
  if (tar.status !== 0) throw new Refusal(`${archiveName} cannot be unpacked: ${tar.stderr.trim()}`);
  for (const name of BUILD_FILES) {
    if (!fs.statSync(path.join(dir, name), { throwIfNoEntry: false })?.isFile()) throw new Refusal(`${archiveName} holds no ${name} at its root`);
  }
  const assets = path.join(dir, "assets");
  if (!fs.statSync(assets, { throwIfNoEntry: false })?.isDirectory() || !buildFiles(assets).length) throw new Refusal(`${archiveName} holds no file under assets/`);
  if (fs.existsSync(path.join(dir, "deployment.json"))) throw new Refusal(`${archiveName} holds a deployment.json of its own, and that file is the deployment's`);
  return dir;
}

// Every file under dir, by its path relative to it with "/" between the parts, in order.
export function buildFiles(dir) {
  return fs
    .readdirSync(dir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.relative(dir, path.join(entry.parentPath, entry.name)).split(path.sep).join("/"))
    .sort((a, b) => a.localeCompare(b));
}

// A schema of /deployment.json, of JSON Schema 2020-12 and compiled, and the version of spec's
// deployment configuration its $id names: { validate, version }.
function deploymentSchema(file, what) {
  const schema = readJson(file, what);
  if (schema.$schema !== DIALECT) throw new Refusal(`${what} is not of JSON Schema 2020-12, but ${schema.$schema ?? "of no dialect named"}`);
  const version = DEPLOYMENT_ID.exec(typeof schema.$id === "string" ? schema.$id : "")?.[1];
  if (!version) throw new Refusal(`${what} names no version of spec's deployment configuration: its $id is ${JSON.stringify(schema.$id ?? null)}`);
  try {
    return { validate: ajv().compile(schema), version: Number(version) };
  } catch (error) {
    throw new Refusal(`${what} cannot be read: ${error.message}`);
  }
}

// spec's deployment configuration at the submodule's tag, which the deployment reads its files by.
export function specDeployment() {
  return deploymentSchema(SPEC_DEPLOYMENT_SCHEMA, "spec's deployment.schema.json");
}

// The build's copy of that schema, at the root of the unpacked build.
export function buildDeployment(build) {
  return deploymentSchema(path.join(build, "deployment.schema.json"), "the build's deployment.schema.json");
}

export function readDeployment(deploymentFile) {
  return readJson(deploymentFile, "production/deployment.json");
}

// The lines of a file of tofu/, or null when it is not there.
function linesOf(file) {
  return fs.existsSync(file) ? fs.readFileSync(file, "utf8").split("\n") : null;
}

// The string a line `<name> = "<value>"` of a file of values gives the variable, or null: line by
// line, with no regular expression over the whole text, which would backtrack (S8786).
export function valueOf(lines, name) {
  for (const line of lines ?? []) {
    const at = line.indexOf("=");
    if (at > 0 && line.slice(0, at).trim() === name) return /^"([^"]*)"/.exec(line.slice(at + 1).trim())?.[1] ?? null;
  }
  return null;
}

// The string default of the variable name in a file of the configuration, or null: the line
// `default = "<value>"` of its block, which tofu fmt leaves at the top level of the block.
export function defaultOf(lines, name) {
  const start = (lines ?? []).indexOf(`variable "${name}" {`);
  if (start < 0) return null;
  for (const line of lines.slice(start + 1)) {
    if (line === "}") return null;
    const at = line.indexOf("=");
    if (at > 0 && line.slice(0, at).trim() === "default") return /^"([^"]*)"/.exec(line.slice(at + 1).trim())?.[1] ?? null;
  }
  return null;
}

// api's address as the configuration makes it, the output api_origin of tofu/outputs.tf:
// https://<api_service_name>-<the project's number>.<region>.run.app (R05). The number is in the
// provider of the federated pool tofu/ci.env names (R13); the region and the service's name are the
// values of tofu/production.auto.tfvars, and the name, when they leave it out, its default in
// tofu/variables.tf. Null with no tofu/ci.env in the repository: no project to compare with.
export function serviceOrigin(root) {
  const env = linesOf(path.join(root, "tofu", "ci.env"));
  if (!env) return null;
  const named = "GCP_WORKLOAD_IDENTITY_PROVIDER=";
  const number = PROVIDER.exec(env.find((line) => line.startsWith(named))?.slice(named.length).trim() ?? "")?.[1];
  if (!number) throw new Refusal("tofu/ci.env names no provider of a federated pool in GCP_WORKLOAD_IDENTITY_PROVIDER, and the number of the project of api's service is not known");
  const values = linesOf(path.join(root, "tofu", "production.auto.tfvars"));
  const region = valueOf(values, "region");
  if (!region) throw new Refusal("tofu/production.auto.tfvars names no region, and the region of api's service is not known");
  const name = valueOf(values, "api_service_name") ?? defaultOf(linesOf(path.join(root, "tofu", "variables.tf")), "api_service_name");
  if (!name) throw new Refusal("neither tofu/production.auto.tfvars nor the default in tofu/variables.tf names api_service_name, and the name of api's service is not known");
  return `https://${name}-${number}.${region}.run.app`;
}

// deployment, the parsed /deployment.json, read as spec's deployment configuration reads it, with
// app open at origin: its schema, then its rules of reading (R85 spec; reading.mjs).
export function deploymentReadBySpec(spec, deployment, origin) {
  const reading = readingOf(spec.validate, origin, deployment);
  if (!reading.refused_by) return;
  const by = reading.refused_by === "schema" ? `the schema: ${explain(spec.validate.errors)}` : `the rule ${reading.refused_by}`;
  throw new Refusal(`production/deployment.json is refused by spec's deployment configuration ${spec.version}, at ${reading.fields.map((f) => f || "the root").join(", ")}, by ${by}`);
}

// The build reads the version of the deployment configuration that spec has at the submodule's tag,
// or it is refused, naming both: a build of a higher version waits for infra to move to a tag of
// spec of that version, by a task of its own, and a build of a lower one is not the build to list
// (R85 spec).
export function buildReadsSpecVersion(built, spec) {
  if (built.version > spec.version) {
    throw new Refusal(`the build reads the deployment configuration ${built.version}, and spec at the submodule's tag is of ${spec.version}: infra moves to a tag of spec of version ${built.version} first`);
  }
  if (built.version < spec.version) {
    throw new Refusal(`the build reads the deployment configuration ${built.version}, older than ${spec.version}, spec's at the submodule's tag: the list names a build of app that reads ${spec.version}`);
  }
}

// deployment against the build's own schema.
export function deploymentHoldsToItsBuild(built, deployment) {
  if (!built.validate(deployment)) {
    throw new Refusal(`production/deployment.json does not hold to the build's deployment.schema.json: ${explain(built.validate.errors)}`);
  }
}

// What a release asks of its deployment.json, with the build unpacked and app open at origin, in the
// order of the check of a pull request: the file passes spec's reading, the build reads spec's
// version, and the file holds to the build's schema (R17).
export function deploymentHolds(build, deploymentFile, origin) {
  const spec = specDeployment();
  const deployment = readDeployment(deploymentFile);
  deploymentReadBySpec(spec, deployment, origin);
  const built = buildDeployment(build);
  buildReadsSpecVersion(built, spec);
  deploymentHoldsToItsBuild(built, deployment);
}

// The Content-Security-Policy header of a release, out of the build's csp.json and the
// deployment.json it ships with (R17). csp.json is one table of directives, each name to its
// sources as one string, with two places in it: {api}, which takes the origin of api, and
// {authDomain}, the host sign-in's window is opened on (architecture 3.7 app). frame-ancestors is
// 'none', and a table that does not say so gets it: the header is the only place it holds, a meta
// tag cannot carry it. Anything else — another shape, another place, a value that would end a
// directive or start another — is refused rather than guessed at.
export function cspHeader(csp, deployment) {
  if (csp === null || typeof csp !== "object" || Array.isArray(csp) || !Object.keys(csp).length) {
    throw new Refusal("the build's csp.json is not a table of directives, each name to its sources");
  }
  const places = { api: deployment?.api, authDomain: deployment?.signIn?.authDomain };
  const directives = [];
  for (const [name, sources] of Object.entries(csp)) {
    if (!/^[a-z]+(-[a-z]+)*$/.test(name)) throw new Refusal(`the build's csp.json names ${JSON.stringify(name)}, which is no directive's name`);
    if (typeof sources !== "string" || !sources.trim() || /[;,\r\n]/.test(sources)) {
      throw new Refusal(`the build's csp.json gives ${name} ${JSON.stringify(sources)}, which is not its sources as one string`);
    }
    const filled = sources.replace(/\{([^{}]*)\}/g, (_, place) => {
      if (!Object.hasOwn(places, place)) throw new Refusal(`the build's csp.json has the place {${place}} in ${name}, and only {api} and {authDomain} are filled`);
      const value = places[place];
      if (typeof value !== "string" || !/^[A-Za-z0-9.:/-]+$/.test(value)) throw new Refusal(`production/deployment.json gives no value {${place}} of csp.json can take`);
      return value;
    });
    if (/[{}]/.test(filled)) throw new Refusal(`the build's csp.json has a brace in ${name} that is no place`);
    if (name === "frame-ancestors" && filled.trim() !== "'none'") throw new Refusal(`the build's csp.json gives frame-ancestors ${filled.trim()}, and app is framed by nobody: 'none'`);
    directives.push(`${name} ${filled.trim().split(/\s+/).join(" ")}`);
  }
  if (!Object.hasOwn(csp, "frame-ancestors")) directives.push("frame-ancestors 'none'");
  return directives.join("; ");
}

// The CSP header of an unpacked build with the deployment.json it ships with.
export function buildCsp(build, deploymentFile) {
  return cspHeader(readJson(path.join(build, "csp.json"), "the build's csp.json"), readJson(deploymentFile, "production/deployment.json"));
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
  const list = readList(listFile);

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
    let build = null;
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
    await step("production/deployment.json is of the sha256 named, and no larger than app reads", () => deploymentOfTheList(app, deploymentFile));
    await step(`app ${app.release}: ${app.archive.name} holds a build to release`, () => {
      if (!archive) return `${app.archive.name} is not unpacked: it was refused`;
      build = unpackBuild(archive, app.archive.name, path.join(work, "app-build"));
    });
    // spec's schema, the build's and the file, each read once; null while a step has refused it.
    let spec = null;
    let built = null;
    let deployment = null;
    await step("production/deployment.json is accepted by spec's reading of the deployment configuration", () => {
      if (!fs.existsSync(deploymentFile)) return "production/deployment.json is not read by spec's deployment configuration: it is not there";
      spec = specDeployment();
      deployment = readDeployment(deploymentFile);
      deploymentReadBySpec(spec, deployment, HOSTED_ORIGIN);
      return `production/deployment.json is accepted by spec's reading of the deployment configuration ${spec.version}`;
    });
    // The release of app compares the same once the configuration is applied, by its outputs (R17);
    // here, before the merge, by the files the outputs come from.
    await step("production/deployment.json names api at its service's address", () => {
      if (!deployment) return "api in production/deployment.json is not compared with its service's address: the file was not read";
      const origin = serviceOrigin(repositoryOf(deployDir, "the address of api's service cannot be read"));
      if (!origin) return "api in production/deployment.json is not compared with its service's address: the repository has no tofu/ci.env, and so no project";
      if (deployment.api !== origin) throw new Refusal(`production/deployment.json names api ${JSON.stringify(deployment.api)}, not its service's address, ${origin}: the output api_origin, by the project of tofu/ci.env and the values of tofu/production.auto.tfvars (R05)`);
      return `production/deployment.json names api at its service's address, ${origin}`;
    });
    await step("the build reads spec's version of the deployment configuration", () => {
      if (!build) return `the build's version of the deployment configuration is not read: ${app.archive.name} was refused`;
      if (!spec) return "the build's version of the deployment configuration is not compared: spec's schema was not read";
      built = buildDeployment(build);
      buildReadsSpecVersion(built, spec);
      return `app ${app.release} reads the deployment configuration ${built.version}, spec's at the submodule's tag`;
    });
    await step("production/deployment.json holds to its build's deployment.schema.json", () => {
      if (!build) return `production/deployment.json is not checked against its build's schema: ${app.archive.name} was refused`;
      if (!deployment) return "production/deployment.json is not checked against its build's schema: it was not read";
      if (!built) return "production/deployment.json is not checked against its build's schema: that schema was refused";
      deploymentHoldsToItsBuild(built, deployment);
    });
    await step("the build's csp.json makes the CSP header of production/deployment.json", () => {
      if (!build) return `the CSP header is not made: ${app.archive.name} was refused`;
      if (!fs.existsSync(deploymentFile)) return "the CSP header is not made: production/deployment.json is not there";
      buildCsp(build, deploymentFile);
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
