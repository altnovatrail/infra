// A stand-in for gcloud and docker, for the test of tools/deploy/api.sh: `node stub.mjs gcloud ...`
// or `node stub.mjs docker ...`. It knows the commands the script runs and nothing else, keeps what
// they did in one JSON file and writes every call to a log, one JSON array a line. A command it does
// not know fails loudly, so that a script that drifts from what the test holds shows it.
//
// STUB_STATE  the JSON file: the service with its revisions and traffic, the registry's packages
//             and tags, the jobs, their executions, the facts' versions, what docker built and pushed,
//             and the layers of a copy's legal texts it built over a release's image
// STUB_LOG    the log of calls

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const [program, ...args] = process.argv.slice(2);
const statePath = process.env.STUB_STATE;
const state = JSON.parse(fs.readFileSync(statePath, "utf8"));
state.tags ??= [];
// The images the registry holds a package of: one is there once anything was pushed to it.
state.packages ??= [...new Set(state.tags.map((t) => t.image))];
state.jobs ??= {};
state.executions ??= [];
state.facts ??= [];
state.built ??= {};
state.layers ??= {};

fs.appendFileSync(process.env.STUB_LOG, JSON.stringify([program, ...args]) + "\n");

const save = () => fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
const out = (text) => process.stdout.write(text + "\n");
const fail = (text, code = 1) => {
  process.stderr.write(`ERROR: (${program}) ${text}\n`);
  process.exit(code);
};
const flag = (name) => {
  const found = args.find((a) => a.startsWith(`--${name}=`));
  return found === undefined ? undefined : found.slice(name.length + 3);
};
const positional = args.filter((a) => !a.startsWith("--"));
const sha = (text) => crypto.createHash("sha256").update(text).digest("hex");

function gcloud() {
  const command = positional.slice(0, 3).join(" ");
  const subject = positional[3];
  const service = state.service;
  switch (true) {
    case command === "run services describe":
      if (state.describeError) fail(state.describeError);
      // As Cloud Run answers the deployment's account for a service not there: its right is on the
      // service, which is not there to hold it (T24).
      if (!service || service.name !== subject)
        fail(`PERMISSION_DENIED: Permission 'run.services.get' denied on resource 'namespaces/p/services/${subject}' (or resource may not exist).`);
      out(
        JSON.stringify({
          status: { traffic: service.traffic, latestCreatedRevisionName: service.latestCreated, latestReadyRevisionName: service.latestReady },
        }),
      );
      return;
    case command === "run revisions describe": {
      const revision = service?.revisions[subject] ?? fail(`NOT_FOUND: revision ${subject}`);
      out(JSON.stringify({ status: { imageDigest: revision.image, conditions: [{ type: "Ready", status: revision.ready === false ? "False" : "True" }] } }));
      return;
    }
    case positional.slice(0, 4).join(" ") === "artifacts docker tags list": {
      const image = positional[4];
      if (state.tagsError) fail(state.tagsError);
      // As Artifact Registry answers for an image with no package yet, before its first push (T24).
      if (!state.packages.includes(image)) fail("NOT_FOUND: Requested entity was not found.");
      out(
        JSON.stringify(
          state.tags
            .filter((t) => t.image === image)
            .map((t) => ({ tag: `projects/p/locations/l/repositories/images/packages/api/tags/${t.tag}`, version: `projects/p/locations/l/repositories/images/packages/api/versions/sha256:${t.digest}` })),
        ),
      );
      return;
    }
    case positional.slice(0, 2).join(" ") === "auth configure-docker":
      return;
    case command === "secrets versions add":
      state.facts.push(fs.readFileSync(flag("data-file"), "utf8"));
      out(`projects/123456789012/secrets/${subject}/versions/${state.facts.length}`);
      return;
    case command === "run jobs update":
      if (!state.jobs[subject]) fail(`NOT_FOUND: job ${subject}`);
      state.jobs[subject].image = flag("image");
      if (flag("update-secrets")) {
        const [file, secretVersion] = flag("update-secrets").split("=");
        Object.assign(state.jobs[subject], { factsFile: file, facts: secretVersion });
      }
      return;
    case command === "run jobs execute":
      if (!state.jobs[subject]) fail(`NOT_FOUND: job ${subject}`);
      if (!args.includes("--wait")) fail("stub: a job runs to its end here, with --wait", 2);
      state.executions.push({ job: subject, image: state.jobs[subject].image });
      if ((state.failJobs ?? []).includes(subject)) {
        save();
        fail(`the execution of ${subject} failed`);
      }
      return;
    case command === "run services update": {
      if (!service || service.name !== subject) fail(`NOT_FOUND: service ${subject}`);
      const [file, secretVersion] = flag("update-secrets").split("=");
      const name = `${subject}-${String(Object.keys(service.revisions).length + 1).padStart(5, "0")}`;
      service.revisions[name] = { image: flag("image"), factsFile: file, facts: secretVersion, ...(state.notReady ? { ready: false } : {}) };
      service.latestCreated = name;
      // As Cloud Run does: a revision with no traffic leaves latestReadyRevisionName on the one that
      // serves, ready or not (T24).
      if (!state.notReady && !args.includes("--no-traffic")) service.latestReady = name;
      // With --no-traffic, the traffic stays where it was; without it, the new revision would take
      // it all at once.
      if (!args.includes("--no-traffic")) service.traffic = [{ revisionName: name, percent: 100 }];
      return;
    }
    case command === "run services update-traffic": {
      const to = flag("to-revisions") ?? fail("stub: traffic goes to a revision by name, --to-revisions", 2);
      const [name, percent] = to.split("=");
      if (!service.revisions[name] || percent !== "100") fail(`stub: no revision ${name}, or not all the traffic`);
      service.traffic = [{ revisionName: name, percent: 100 }];
      return;
    }
    default:
      fail(`stub: unknown command ${args.join(" ")}`, 2);
  }
}

function docker() {
  switch (positional[0]) {
    case "build": {
      if (!args.includes("--build-context")) return layer();
      const at = args.indexOf("--build-context");
      const context = flag("build-context") ?? (at >= 0 ? args[at + 1] : fail("stub: no --build-context"));
      const [name, dir] = context.split("=");
      if (name !== "binary") fail("stub: the build context is binary");
      const binary = path.join(dir, "api");
      if (!fs.existsSync(binary) || !(fs.statSync(binary).mode & 0o111)) fail("stub: the context binary holds no executable api");
      const dockerfile = args[args.indexOf("-f") + 1];
      if (!fs.existsSync(dockerfile)) fail("stub: no Dockerfile");
      const main = args.at(-1);
      if (fs.readdirSync(main).length) fail("stub: the main context is not empty");
      if (args[args.indexOf("--target") + 1] !== "release") fail("stub: the target is release");
      if (flag("platform") !== "linux/amd64") fail("stub: the platform is linux/amd64, the binary's");
      state.built[args[args.indexOf("-t") + 1]] = sha(fs.readFileSync(binary));
      return;
    }
    case "push": {
      const tagged = positional[1];
      if (!state.built[tagged]) fail(`stub: ${tagged} was not built`);
      const [image, tag] = [tagged.slice(0, tagged.lastIndexOf(":")), tagged.slice(tagged.lastIndexOf(":") + 1)];
      const digest = sha(`${tagged} ${state.built[tagged]}`);
      // A tag pushed again moves to the new image, as in Artifact Registry.
      state.tags = state.tags.filter((t) => !(t.image === image && t.tag === tag));
      state.tags.push({ image, tag, digest });
      if (!state.packages.includes(image)) state.packages.push(image);
      out(`The push refers to repository [${image}]`);
      out(`${tag}: digest: sha256:${digest} size: 528`);
      return;
    }
    default:
      fail(`stub: unknown command ${args.join(" ")}`, 2);
  }
}

// The build of a copy's legal texts over the release's image: a Dockerfile FROM an image the
// registry holds, by its digest, that copies the context's folder legal and names it; what it laid is
// kept as the layer of its tag, each file with its text and whether all may read it.
function layer() {
  const dockerfile = fs.readFileSync(args[args.indexOf("-f") + 1], "utf8").trim().split("\n");
  const from = dockerfile[0].match(/^FROM (.+)@sha256:([0-9a-f]{64})$/) ?? fail(`stub: the texts are built FROM an image by its digest, not ${dockerfile[0]}`);
  if (!state.tags.some((t) => t.image === from[1] && t.digest === from[2])) fail(`stub: the registry holds no ${from[1]}@sha256:${from[2]}`);
  if (flag("platform") !== "linux/amd64") fail("stub: the platform is linux/amd64, the binary's");
  const context = args.at(-1);
  const files = {};
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if ((fs.statSync(full).mode & 0o005) !== 0o005) fail(`stub: ${full} is not open to all`);
        walk(full);
      } else {
        // One descriptor for the mode and the text, so both are of the same file.
        const fd = fs.openSync(full, "r");
        try {
          if (!(fs.fstatSync(fd).mode & 0o004)) fail(`stub: ${full} is not read by all`);
          files[path.relative(path.join(context, "legal"), full)] = fs.readFileSync(fd, "utf8");
        } finally {
          fs.closeSync(fd);
        }
      }
    }
  };
  walk(path.join(context, "legal"));
  const tagged = args[args.indexOf("-t") + 1];
  state.layers[tagged] = { from: `${from[1]}@sha256:${from[2]}`, steps: dockerfile.slice(1), files };
  state.built[tagged] = sha(JSON.stringify(state.layers[tagged]));
}

if (program === "gcloud") gcloud();
else if (program === "docker") docker();
else fail(`stub: unknown program ${program}`, 2);
save();
