// A stand-in for gcloud, for the test of bootstrap.sh: it knows the commands the script runs and
// nothing else, keeps what they made in a JSON file and writes every call to a log, one JSON array
// of arguments a line. A command it does not know fails loudly, so that a script that drifts from
// what the test holds shows it.
//
// STUB_STATE    the JSON file of what exists
// STUB_LOG      the log of calls
// STUB_CURRENCY the billing account's currency, USD unless given
// STUB_FAIL     a command whose arguments, joined by spaces, hold this text fails, and its error
//               names the billing account TF_VAR_billing_account gives and the member it was
//               given, as gcloud's errors do
// STUB_FAIL_ONCE the same, for the first such command alone, with an error that is not NOT_FOUND
//
// A policy is printed as one read in version 3 is: a binding under a condition names its role as it
// is and carries its expression. Which version the real gcloud reads, the first run shows (T23).

import fs from "node:fs";

const args = process.argv.slice(2);
const statePath = process.env.STUB_STATE;
const state = fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, "utf8")) : {};
for (const key of ["projects", "billingLinks", "services", "roles", "buckets", "pools", "providers", "accounts", "projectPolicy"]) {
  state[key] ??= {};
}
state.billingPolicy ??= [];
state.failedOnce ??= false;

fs.appendFileSync(process.env.STUB_LOG, JSON.stringify(args) + "\n");

function save() {
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
}
const out = (text) => process.stdout.write(text === "" ? "" : text + "\n");
const fail = (text, code = 1) => {
  process.stderr.write(`ERROR: (gcloud) ${text}\n`);
  process.exit(code);
};

if (process.env.STUB_FAIL && args.join(" ").includes(process.env.STUB_FAIL)) {
  const member = args.find((a) => a.startsWith("--member="));
  fail(`PERMISSION_DENIED: the caller may not act on billingAccounts/${process.env.TF_VAR_billing_account}${member ? ` for ${member.slice("--member=".length)}` : ""}`);
}
if (process.env.STUB_FAIL_ONCE && !state.failedOnce && args.join(" ").includes(process.env.STUB_FAIL_ONCE)) {
  state.failedOnce = true;
  save();
  fail("UNAVAILABLE: the service is unavailable, try again");
}

// IAM refuses, in a role of a project, a permission that is valid only at a higher level.
const NOT_IN_A_PROJECT_ROLE = ["resourcemanager.projects.list"];
function projectRolePermissions() {
  for (const permission of (flag("permissions") ?? "").split(",")) {
    if (NOT_IN_A_PROJECT_ROLE.includes(permission)) fail(`INVALID_ARGUMENT: Permission ${permission} is not valid.`);
  }
}

const flag = (name) => {
  const prefix = `--${name}=`;
  const found = args.find((a) => a.startsWith(prefix));
  return found === undefined ? undefined : found.slice(prefix.length);
};
const positional = args.filter((a) => !a.startsWith("--"));
const command = positional.slice(0, 3).join(" ");
const [, , , first] = positional;

const binding = (list, role, member, condition) => {
  if (!list.some((b) => b.role === role && b.member === member && b.condition === condition)) {
    list.push({ role, member, condition });
  }
};
// A binding on a bucket or a service account may leave its condition out, and is then bare.
const conditionOrBare = () => (flag("condition") === undefined && flag("condition-from-file") === undefined ? "" : conditionOf());
const conditionOf = () => {
  const file = flag("condition-from-file");
  if (file !== undefined) {
    return fs.readFileSync(file, "utf8").match(/^expression: (.*)$/m)[1];
  }
  if (flag("condition") === "None") return "";
  fail("a binding names its condition, or None");
};
const projectOf = () => flag("project") ?? fail("no --project");
const notFound = (what) => fail(`NOT_FOUND: ${what} was not found`);
const printPolicy = (list) => {
  for (const b of list) out(`${b.role}\t${b.member}\t${b.condition}`);
};
const removeBinding = (list) => {
  const all = args.includes("--all");
  const condition = all ? undefined : flag("condition") === undefined ? "" : conditionOf();
  return list.filter((b) => !(b.role === flag("role") && b.member === flag("member") && (all || b.condition === condition)));
};

switch (true) {
  case command === "billing accounts describe":
    out(process.env.STUB_CURRENCY ?? "USD");
    break;
  case command === "billing accounts add-iam-policy-binding":
    binding(state.billingPolicy, flag("role"), flag("member"), "");
    break;
  case command === "billing accounts get-iam-policy":
    printPolicy(state.billingPolicy);
    break;
  case command === "billing accounts remove-iam-policy-binding":
    state.billingPolicy = removeBinding(state.billingPolicy);
    break;
  case command === "billing projects describe":
    out(state.billingLinks[positional[3]] ?? "");
    break;
  case command === "billing projects link":
    state.billingLinks[first] = `billingAccounts/${flag("billing-account")}`;
    break;

  case positional[0] === "projects" && positional[1] === "describe": {
    const project = state.projects[positional[2]] ?? notFound(`project ${positional[2]}`);
    const format = flag("format");
    out(format === "value(projectNumber)" ? project.number : format === "value(lifecycleState)" ? (project.lifecycle ?? "ACTIVE") : `projectId: ${positional[2]}`);
    break;
  }
  case positional[0] === "projects" && positional[1] === "create":
    if (state.projects[positional[2]]) fail("ALREADY_EXISTS");
    state.projects[positional[2]] = { number: "123456789012" };
    break;
  case positional[0] === "projects" && positional[1] === "add-iam-policy-binding":
    binding((state.projectPolicy[positional[2]] ??= []), flag("role"), flag("member"), conditionOf());
    break;
  case positional[0] === "projects" && positional[1] === "remove-iam-policy-binding":
    state.projectPolicy[positional[2]] = removeBinding(state.projectPolicy[positional[2]] ?? []);
    break;
  case positional[0] === "projects" && positional[1] === "get-iam-policy":
    printPolicy(state.projectPolicy[positional[2]] ?? []);
    break;

  case positional[0] === "services" && positional[1] === "enable": {
    const list = (state.services[projectOf()] ??= []);
    for (const service of positional.slice(2)) if (!list.includes(service)) list.push(service);
    break;
  }

  case command === "iam roles describe": {
    const role = state.roles[`${projectOf()}/${first}`] ?? notFound(`role ${first}`);
    out(role.deleted ? "True" : "");
    break;
  }
  case command === "iam roles create":
    if (state.roles[`${projectOf()}/${first}`]) fail("ALREADY_EXISTS: role");
    projectRolePermissions();
    state.roles[`${projectOf()}/${first}`] = { title: flag("title"), permissions: flag("permissions").split(","), deleted: false };
    break;
  case command === "iam roles update": {
    const role = state.roles[`${projectOf()}/${first}`] ?? notFound(`role ${first}`);
    if (role.deleted) fail("FAILED_PRECONDITION: the role is deleted");
    projectRolePermissions();
    Object.assign(role, { title: flag("title"), permissions: flag("permissions").split(",") });
    break;
  }
  case command === "iam roles undelete":
    (state.roles[`${projectOf()}/${first}`] ?? notFound(`role ${first}`)).deleted = false;
    break;

  // A bucket's place is shown as Cloud Storage names it, in capitals.
  case command === "storage buckets describe": {
    const bucket = state.buckets[first] ?? notFound(`bucket ${first}`);
    out(flag("format") === "value(location)" ? bucket.location.toUpperCase() : `name: ${first}`);
    break;
  }
  // What gcloud gives a bucket it is not told otherwise: Standard, soft delete of 7 days, no
  // uniform access, public access prevention inherited (sources 10.3, 10.7).
  case command === "storage buckets create":
    if (state.buckets[first]) fail("ALREADY_EXISTS: bucket");
    state.buckets[first] = {
      project: projectOf(),
      location: flag("location") ?? "us",
      storageClass: flag("default-storage-class") ?? "STANDARD",
      uniform: args.includes("--uniform-bucket-level-access"),
      publicAccessPrevention: args.includes("--public-access-prevention") ? "enforced" : "inherited",
      softDelete: flag("soft-delete-duration") ?? "7d",
      versioning: false,
      lifecycle: flag("lifecycle-file") === undefined ? null : JSON.parse(fs.readFileSync(flag("lifecycle-file"), "utf8")),
      cors: null,
      policy: [],
    };
    break;
  // An update changes what it is given and keeps the rest; it knows the flags the script gives.
  case command === "storage buckets update": {
    const bucket = state.buckets[first] ?? notFound(`bucket ${first}`);
    for (const a of args.filter((a) => a.startsWith("--"))) {
      const [name, value] = a.slice(2).split(/=(.*)/s);
      if (name === "versioning" || name === "no-versioning") bucket.versioning = name === "versioning";
      else if (name === "uniform-bucket-level-access") bucket.uniform = true;
      else if (name === "public-access-prevention") bucket.publicAccessPrevention = "enforced";
      else if (name === "default-storage-class") bucket.storageClass = value;
      else if (name === "clear-soft-delete") bucket.softDelete = "0";
      else if (name === "clear-cors") bucket.cors = null;
      else if (name === "clear-lifecycle") bucket.lifecycle = null;
      else if (name === "lifecycle-file") bucket.lifecycle = JSON.parse(fs.readFileSync(value, "utf8"));
      else fail(`stub: unknown flag of an update: ${a}`, 2);
    }
    break;
  }
  case command === "storage buckets add-iam-policy-binding":
    binding((state.buckets[first] ?? notFound(`bucket ${first}`)).policy, flag("role"), flag("member"), conditionOrBare());
    break;
  // The buckets of one project, by their names, as `--format=value(name)` prints them.
  case command === "storage buckets list":
    for (const [url, bucket] of Object.entries(state.buckets)) {
      if (bucket.project === projectOf()) out(url.slice("gs://".length));
    }
    break;
  case command === "storage buckets get-iam-policy":
    printPolicy((state.buckets[first] ?? notFound(`bucket ${first}`)).policy);
    break;
  case command === "storage buckets remove-iam-policy-binding": {
    const bucket = state.buckets[first] ?? notFound(`bucket ${first}`);
    bucket.policy = removeBinding(bucket.policy);
    break;
  }

  case command === "iam workload-identity-pools describe": {
    const pool = state.pools[first] ?? notFound(`pool ${first}`);
    out(flag("format") === "value(state)" ? (pool.state ?? "ACTIVE") : `name: ${first}`);
    break;
  }
  case command === "iam workload-identity-pools create":
    if (state.pools[first]) fail("ALREADY_EXISTS: pool");
    state.pools[first] = { project: projectOf(), state: "ACTIVE" };
    break;
  case command === "iam workload-identity-pools undelete":
    (state.pools[first] ?? notFound(`pool ${first}`)).state = "ACTIVE";
    break;
  case command === "iam workload-identity-pools providers": {
    const [verb, id] = positional.slice(3);
    const key = `${flag("workload-identity-pool")}/${id}`;
    if (verb === "describe") {
      const provider = state.providers[key] ?? notFound(`provider ${key}`);
      out(flag("format") === "value(state)" ? (provider.state ?? "ACTIVE") : `name: ${key}`);
    } else if (verb === "undelete") {
      (state.providers[key] ?? notFound(`provider ${key}`)).state = "ACTIVE";
    } else if (verb === "create-oidc" || verb === "update-oidc") {
      if (verb === "create-oidc" && state.providers[key]) fail("ALREADY_EXISTS: provider");
      if (verb === "update-oidc" && !state.providers[key]) notFound(`provider ${key}`);
      if (verb === "update-oidc" && state.providers[key].state === "DELETED") fail("FAILED_PRECONDITION: the provider is deleted");
      // An update changes what it is given, as gcloud's does, and keeps the rest.
      const given = Object.entries({ issuer: flag("issuer-uri"), mapping: flag("attribute-mapping"), condition: flag("attribute-condition") }).filter(([, value]) => value !== undefined);
      state.providers[key] = { ...(verb === "update-oidc" ? state.providers[key] : {}), ...Object.fromEntries(given), state: "ACTIVE" };
    } else {
      fail(`stub: unknown command ${args.join(" ")}`, 2);
    }
    break;
  }

  case command === "iam service-accounts describe":
    if (!state.accounts[first]) notFound(`service account ${first}`);
    out(`email: ${first}`);
    break;
  case command === "iam service-accounts create": {
    const email = `${first}@${projectOf()}.iam.gserviceaccount.com`;
    if (state.accounts[email]) fail("ALREADY_EXISTS: service account");
    state.accounts[email] = { policy: [] };
    break;
  }
  case command === "iam service-accounts add-iam-policy-binding":
    binding((state.accounts[first] ?? notFound(`service account ${first}`)).policy, flag("role"), flag("member"), conditionOrBare());
    break;
  case command === "iam service-accounts remove-iam-policy-binding": {
    const account = state.accounts[first] ?? notFound(`service account ${first}`);
    account.policy = removeBinding(account.policy);
    break;
  }
  case command === "iam service-accounts get-iam-policy":
    printPolicy((state.accounts[first] ?? notFound(`service account ${first}`)).policy);
    break;

  default:
    fail(`stub: unknown command ${args.join(" ")}`, 2);
}

save();
