// target: what a run of the deployment's workflow delivers (R05, R18), decided once by its first
// job and asked again by every later job on a retry.
//
//   node tools/deploy/target.mjs target <commit> [--by-hand=<parts>]
//   node tools/deploy/target.mjs current <commit>
//   node tools/deploy/target.mjs identity
//   node tools/deploy/target.mjs environments <name>...
//
// target prints, one `key=value` a line for $GITHUB_OUTPUT, whether the run delivers and which parts
// of the list it delivers: `deliver`, `commit`, `image`, `api`, `facts`, `app`, each part true or
// false. It delivers only while main still stands on <commit>, and only once the project is set up:
// tofu/ci.env, tofu/production.auto.tfvars and tofu/backend.hcl at <commit> (T23). The parts are the
// list's blocks that changed against the commit of the last run of the workflow that delivered:
// pushed to main, green, and its job Configuration through — a run that delivered nothing, because
// main had moved on or the project was not set up, is green too and counts for nothing. Not against
// the push before this one either, which a run waiting in the queue and replaced by a newer one, or a
// run that failed, would leave undelivered. With no such run, every part the list has; with no list,
// none, and the run applies the configuration alone. Until tofu/production.auto.tfvars names
// api_image, api has no jobs to run a release with (R11), and a changed api is its image alone; until
// it sets api_serving = true, api has no service, and a changed app waits for the run that sets it,
// which delivers app (R05).
//
// A run started by hand delivers the parts it names, among image, api, facts and app, and none when
// it names none: --by-hand=<parts>, apart by commas, or, in the workflow, GITHUB_EVENT_NAME
// workflow_dispatch with INPUT_IMAGE, INPUT_API, INPUT_FACTS and INPUT_APP true or false. Such a run
// is not a base: one that delivered app alone would hide a change of api it left behind, and a part
// it did deliver is delivered again by the next push, which is safe.
//
// current fails unless main still stands on <commit>: a job run again after main moved on would
// roll production back to an older list (R45 canvas-api).
//
// identity prints, for $GITHUB_OUTPUT, the provider of the federated pool and the configuration's
// identity that tofu/ci.env names, as bootstrap.sh printed them (R13), once each holds to its form.
//
// environments fails unless each GitHub environment it names is there and is run from main alone:
// the configuration lends its identities to the jobs of these environments, and GitHub makes an
// environment a job names that it does not have, with no rule of branches (R18).
//
// It reads the repository it runs in, its origin and, for the last run that delivered, GitHub's
// API with GITHUB_TOKEN; GITHUB_REPOSITORY names the repository, GITHUB_API_URL the API.

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { envValues, PROVIDER, tfvarsValue } from "../deploy-check/setup.mjs";

export class Refusal extends Error {}

// git by its absolute path, the runner's or the devcontainer's: no folder on PATH decides it.
const GIT = ["/usr/bin/git", "/usr/local/bin/git", "/bin/git"].find((program) => fs.existsSync(program)) ?? "/usr/bin/git";

const PARTS = ["image", "api", "facts", "app"];
const SETUP = ["tofu/ci.env", "tofu/production.auto.tfvars", "tofu/backend.hcl"];
const LIST = "deploy/production.json";
const FACTS = "deploy/production/facts.json";
const WORKFLOW = "deploy.yml";
const CONFIG_JOB = "Configuration";
const TFVARS = "tofu/production.auto.tfvars";
// The green runs looked through for the last that delivered: the newest of them that did.
const LOOK = 20;

function git(dir, args, { allowFailure = false } = {}) {
  const run = spawnSync(GIT, ["-C", dir, ...args], { encoding: "utf8" });
  if (run.error) throw new Refusal(`git cannot be run: ${run.error.message}`);
  if (run.status !== 0 && !allowFailure) throw new Refusal(`git ${args.join(" ")} failed: ${run.stderr.trim()}`);
  return run;
}

// The commit main stands on at the origin, now.
export function tipOfMain(dir) {
  const tip = git(dir, ["ls-remote", "origin", "refs/heads/main"]).stdout.split("\t")[0].trim();
  if (!/^[0-9a-f]{40}$/.test(tip)) throw new Refusal("the origin names no commit main stands on");
  return tip;
}

function has(dir, commit, file) {
  return git(dir, ["cat-file", "-e", `${commit}:${file}`], { allowFailure: true }).status === 0;
}

// A JSON file at a commit, or null when it is not there.
function jsonAt(dir, commit, file) {
  if (!has(dir, commit, file)) return null;
  const text = git(dir, ["show", `${commit}:${file}`]).stdout;
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Refusal(`${file} at ${commit.slice(0, 12)} is not JSON: ${error.message}`);
  }
}

async function github(url, token, what = "the last run that delivered", { missing } = {}) {
  let response;
  try {
    response = await fetch(url, { headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" } });
  } catch (error) {
    throw new Refusal(`GitHub cannot be reached for ${what}: ${error.message}`);
  }
  if (response.status === 404 && missing) throw new Refusal(missing);
  if (!response.ok) throw new Refusal(`GitHub answered ${response.status} for ${what}: ${(await response.text()).slice(0, 300)}`);
  return response.json();
}

// The GitHub environments the configuration lends its identities to — its own, api's deployment's
// and app's publisher's, as its outputs name them — each there and run from main alone. A job that
// names an environment GitHub does not have makes it, with no rule of branches, and then a workflow
// of any branch could borrow the identity lent to it (R12, R13, R18).
export async function environmentsHoldToMain({ repository, token, names, api = "https://api.github.com" }) {
  if (!repository || !token) throw new Refusal("GITHUB_REPOSITORY and GITHUB_TOKEN name the repository and read its environments");
  for (const name of names) {
    const at = `${api}/repos/${repository}/environments/${encodeURIComponent(name)}`;
    const environment = await github(at, token, `the environment ${name}`, { missing: `there is no environment ${name}: a job in it would make it, with no rule of branches, and lend its identity to any branch; make it with the rule main first (docs/architecture.md, section 3.2)` });
    const policy = environment.deployment_branch_policy;
    if (!policy || policy.protected_branches || !policy.custom_branch_policies) throw new Refusal(`the environment ${name} is not run from chosen branches alone: its rule is main, and main alone`);
    const rules = ((await github(`${at}/deployment-branch-policies?per_page=100`, token, `the branches of the environment ${name}`)).branch_policies ?? []).map((rule) => `${rule.type ?? "branch"}:${rule.name}`);
    if (rules.length !== 1 || rules[0] !== "branch:main") throw new Refusal(`the environment ${name} is run from ${rules.join(", ") || "no branch"}, and not from main alone`);
  }
}

// The commit of the last run of the workflow that delivered: pushed to main, green, and its job
// Configuration through, or null when none of the newest green runs did.
export async function lastDelivered({ repository, token, api = "https://api.github.com" }) {
  if (!repository || !token) throw new Refusal("GITHUB_REPOSITORY and GITHUB_TOKEN name the repository and read its runs");
  const runs = (await github(`${api}/repos/${repository}/actions/workflows/${WORKFLOW}/runs?branch=main&event=push&status=success&per_page=${LOOK}`, token)).workflow_runs ?? [];
  for (const run of runs) {
    const jobs = (await github(`${api}/repos/${repository}/actions/runs/${run.id}/jobs?filter=latest&per_page=100`, token)).jobs ?? [];
    if (!jobs.some((job) => job.name === CONFIG_JOB && job.conclusion === "success")) continue;
    if (!/^[0-9a-f]{40}$/.test(run.head_sha ?? "")) throw new Refusal(`GitHub names the last run that delivered at ${JSON.stringify(run.head_sha)}, not a commit`);
    return run.head_sha;
  }
  return null;
}

// The parts a run started by hand names, from its inputs as the workflow passes them.
export function partsOfInputs(env) {
  return PARTS.filter((part) => {
    const value = env[`INPUT_${part.toUpperCase()}`];
    if (value !== "true" && value !== "false") throw new Refusal(`INPUT_${part.toUpperCase()} is ${JSON.stringify(value)}, not true or false`);
    return value === "true";
  }).join(",");
}

// Whether tofu/production.auto.tfvars at the commit sets the variable name to a value that holds,
// by the line that sets it (setup.mjs).
function setsVariable(dir, commit, name, holds) {
  if (!has(dir, commit, TFVARS)) return false;
  const value = tfvarsValue(git(dir, ["show", `${commit}:${TFVARS}`]).stdout.split("\n"), name);
  return value !== null && holds(value);
}

// Whether tofu/production.auto.tfvars at the commit names api_image: until it does, api has no jobs.
const hasImage = (dir, commit) => setsVariable(dir, commit, "api_image", (value) => /^"[^"]+"/.test(value));

// Whether the configuration of the commit makes api's service: app goes only once it is there, since
// its /deployment.json names the service's address (R05).
// The value true, or the string "true", which OpenTofu reads as the same bool.
const hasServing = (dir, commit) => setsVariable(dir, commit, "api_serving", (value) => /^("true"|true)(\s|#|$)/.test(value));

function partsByHand(text) {
  const named = text.split(",").map((part) => part.trim()).filter(Boolean);
  const unknown = named.filter((part) => !PARTS.includes(part));
  if (unknown.length) throw new Refusal(`no part ${unknown.join(", ")}: the parts are ${PARTS.join(", ")}`);
  return new Set(named);
}

// What the run delivers. `tip` and `base` are what tipOfMain and lastDelivered give; `byHand` the
// parts a run started by hand names, or null.
export function decide({ dir, commit, tip, base, byHand = null }) {
  const no = { deliver: false, commit, image: false, api: false, facts: false, app: false };
  if (tip !== commit) return { ...no, lines: [`main stands on ${tip.slice(0, 12)} now, not on ${commit.slice(0, 12)}: its own run delivers it, and this one would roll it back`] };
  const missing = SETUP.filter((file) => !has(dir, commit, file));
  if (missing.length) return { ...no, lines: [`the project is not set up yet: ${missing.join(", ")} not at ${commit.slice(0, 12)} (T23)`] };

  if (byHand !== null) {
    const parts = partsByHand(byHand);
    return { deliver: true, commit, ...Object.fromEntries(PARTS.map((part) => [part, parts.has(part)])), lines: [`started by hand: the configuration, and ${parts.size ? [...parts].join(", ") : "no part of the list"}`] };
  }

  const list = jsonAt(dir, commit, LIST);
  if (!list) return { deliver: true, commit, image: false, api: false, facts: false, app: false, lines: [`no ${LIST} at ${commit.slice(0, 12)}: the configuration alone`] };

  const known = base && git(dir, ["cat-file", "-e", `${base}^{commit}`], { allowFailure: true }).status === 0 ? base : null;
  const lines = [];
  if (base && !known) lines.push(`the last run that delivered stands on ${base.slice(0, 12)}, which this history does not hold: every part, as if none had`);
  const before = known ? jsonAt(dir, known, LIST) : null;
  const facts = jsonAt(dir, commit, FACTS);
  const changed = {
    api: !before || !isDeepStrictEqual(before.api, list.api),
    facts: !before || !isDeepStrictEqual(jsonAt(dir, known, FACTS), facts),
    app: !before || !isDeepStrictEqual(before.app, list.app),
  };
  if (!known) lines.push("no run has delivered the list yet: every part of it");
  else lines.push(`against ${known.slice(0, 12)}, the last run that delivered: ${Object.entries(changed).filter(([, is]) => is).map(([part]) => part).join(", ") || "no part"} changed`);
  // app goes after api's service, whose address its /deployment.json names: a run before it would
  // ship a build that calls an api not there. The run that brings the service delivers it, changed
  // or not since the last run that delivered, which held it back (R05).
  const serving = hasServing(dir, commit);
  const servingNew = serving && !(known && hasServing(dir, known));
  const app = serving && (changed.app || servingNew);
  if (changed.app && !serving) lines.push(`${TFVARS} does not set api_serving = true yet, so api has no service for app to call: app waits for the run that sets it (R05)`);
  if (app && !changed.app) lines.push(`${TFVARS} sets api_serving = true since the last run that delivered: app, which waited for the service`);
  if ((changed.api || changed.facts) && !hasImage(dir, commit)) {
    lines.push(`${TFVARS} names no api_image yet, so api has no jobs: its image alone; name the digest it prints in api_image, then run api by hand (R11)`);
    return { deliver: true, commit, image: changed.api, api: false, facts: false, app, lines };
  }
  return { deliver: true, commit, image: false, ...changed, app, lines };
}

// tofu/ci.env: the two lines bootstrap.sh prints, neither of them a secret, and nothing else.
export function identity(file) {
  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    throw new Refusal(`${file} is not there: the project is not set up yet (T23)`);
  }
  const { values, wrong } = envValues(text);
  if (wrong !== null) throw new Refusal(`${file} holds ${JSON.stringify(wrong)}, not one line of KEY=value of its own`);
  const provider = values.GCP_WORKLOAD_IDENTITY_PROVIDER;
  const account = values.GCP_CONFIG_SERVICE_ACCOUNT;
  if (!PROVIDER.test(provider ?? "")) throw new Refusal(`${file} names no provider of a federated pool in GCP_WORKLOAD_IDENTITY_PROVIDER`);
  if (!/^infra-config@[a-z][a-z0-9-]{4,28}[a-z0-9]\.iam\.gserviceaccount\.com$/.test(account ?? "")) throw new Refusal(`${file} names no infra-config identity of a project in GCP_CONFIG_SERVICE_ACCOUNT`);
  const extra = Object.keys(values).filter((key) => !["GCP_WORKLOAD_IDENTITY_PROVIDER", "GCP_CONFIG_SERVICE_ACCOUNT"].includes(key));
  if (extra.length) throw new Refusal(`${file} holds ${extra.join(", ")}, which it does not name`);
  return { provider, config_service_account: account };
}

const USAGE = "usage: target target <commit> [--by-hand=<parts>] | target current <commit> | target identity | target environments <name>...";

async function main(argv) {
  const [command, commit, flag] = argv;
  if (command === "environments" && argv.length > 1) {
    await environmentsHoldToMain({ repository: process.env.GITHUB_REPOSITORY, token: process.env.GITHUB_TOKEN, names: argv.slice(1), api: process.env.GITHUB_API_URL || undefined });
    console.error(`target: ${argv.slice(1).join(", ")} — each there, and run from main alone`);
    return;
  }
  if (command === "identity" && argv.length === 1) {
    for (const [key, value] of Object.entries(identity("tofu/ci.env"))) console.log(`${key}=${value}`);
    return;
  }
  if (!["target", "current"].includes(command) || !/^[0-9a-f]{40}$/.test(commit ?? "") || argv.length > (command === "current" ? 2 : 3)) throw new Refusal(USAGE);
  if (flag !== undefined && !flag.startsWith("--by-hand=")) throw new Refusal(USAGE);
  const byHand = flag !== undefined ? flag.slice("--by-hand=".length) : process.env.GITHUB_EVENT_NAME === "workflow_dispatch" ? partsOfInputs(process.env) : null;
  const dir = process.cwd();
  const tip = tipOfMain(dir);
  if (command === "current") {
    if (tip !== commit) throw new Refusal(`main stands on ${tip.slice(0, 12)} now, not on ${commit.slice(0, 12)}: its own run delivers it, and this job would roll it back`);
    console.error(`target: main still stands on ${commit.slice(0, 12)}`);
    return;
  }
  const base = byHand === null && tip === commit ? await lastDelivered({ repository: process.env.GITHUB_REPOSITORY, token: process.env.GITHUB_TOKEN, api: process.env.GITHUB_API_URL || undefined }) : null;
  const decided = decide({ dir, commit, tip, base, byHand });
  for (const line of decided.lines) console.error(`target: ${line}`);
  for (const key of ["deliver", "commit", ...PARTS]) console.log(`${key}=${decided[key]}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error instanceof Refusal ? `target: ${error.message}` : error);
    process.exit(1);
  });
}
