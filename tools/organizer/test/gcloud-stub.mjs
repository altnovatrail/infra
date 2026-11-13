// A stand-in for gcloud, for the test of tools/organizer/organizer.mjs: `node gcloud-stub.mjs ...`.
// It knows the commands the tool runs and nothing else, keeps the bucket's objects in one JSON file
// and writes every call to a log, one JSON array a line. A command it does not know fails loudly.
//
// STUB_STATE  the JSON file: { bucket, objects: { <name>: { customTime?, timeCreated?, metadata? } },
//             signError?, failMove? },
//             failMove the destination of a move that fails
// STUB_KEY    the private key, PEM, that sign-blob signs with, as IAM signs with Google's key
// STUB_LOG    the log of calls

import crypto from "node:crypto";
import fs from "node:fs";

const args = process.argv.slice(2);
const statePath = process.env.STUB_STATE;
const state = JSON.parse(fs.readFileSync(statePath, "utf8"));
fs.appendFileSync(process.env.STUB_LOG, JSON.stringify(args) + "\n");

const save = () => fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
const out = (text) => process.stdout.write(text + "\n");
const fail = (text) => {
  process.stderr.write(`ERROR: (gcloud) ${text}\n`);
  process.exit(1);
};
const flag = (name) => args.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const positional = args.filter((a) => !a.startsWith("--"));
const command = positional.slice(0, 3).join(" ");

// gs://<bucket>/<name>: its name, in the one bucket the stand-in holds.
const nameOf = (url) => {
  const prefix = `gs://${state.bucket}/`;
  if (!url?.startsWith(prefix)) fail(`no bucket of ${url}`);
  return url.slice(prefix.length);
};
// When an object the state names no creation of was made.
const CREATED = "2026-11-01T10:00:00.000Z";
const object = (url) => state.objects[nameOf(url)] ?? fail(`NotFoundError: ${url} not found: 404.`);

switch (true) {
  case command === "iam service-accounts sign-blob": {
    if (state.signError) fail(state.signError);
    const [input, output] = positional.slice(3);
    const signature = crypto.sign("sha256", fs.readFileSync(input), fs.readFileSync(process.env.STUB_KEY, "utf8"));
    fs.writeFileSync(output, signature);
    process.stderr.write(`signed blob [${input}] as [${output}] for [${flag("iam-account")}]\n`);
    break;
  }
  case command === "storage objects describe":
    out(JSON.stringify({ name: nameOf(positional[3]), timeCreated: CREATED, ...object(positional[3]) }));
    break;
  case command === "storage objects update": {
    const found = object(positional[3]);
    // A Custom-Time can be neither removed nor decreased, but by a rewrite (sources 10.3).
    if (args.includes("--clear-custom-time") && found.customTime) fail("HTTPError 400: Custom time cannot be removed.");
    const wanted = flag("custom-time");
    if (wanted !== undefined) {
      if (found.customTime && Date.parse(found.customTime) > Date.parse(wanted)) fail("HTTPError 400: Custom time cannot be decreased.");
      found.customTime = wanted;
    }
    save();
    break;
  }
  case command === "storage objects list": {
    const url = positional[3];
    if (!url.endsWith("**")) fail(`the stand-in lists only gs://<bucket>/<prefix>**, not ${url}`);
    const prefix = nameOf(url.slice(0, -2));
    const found = Object.entries(state.objects)
      .filter(([name]) => name.startsWith(prefix))
      .map(([name, meta]) => ({ kind: "storage#object", bucket: state.bucket, name, ...meta }));
    if (found.length === 0) fail("One or more URLs matched no objects.");
    out(JSON.stringify(found));
    break;
  }
  case positional.slice(0, 2).join(" ") === "storage mv": {
    // A copy, which keeps the source's Custom-Time unless --custom-time names another, then an
    // erasure; never onto the source itself (sources 10.8).
    const [from, to] = positional.slice(2).map(nameOf);
    if (from === to) fail(`Source URL matches destination URL: gs://${state.bucket}/${from}`);
    if (state.failMove === to) fail(`HTTPError 503: ${to}`);
    const source = state.objects[from] ?? fail(`NotFoundError: ${from}`);
    const wanted = flag("custom-time");
    const added = flag("update-custom-metadata");
    const metadata = { ...source.metadata, ...(added !== undefined && Object.fromEntries([added.split("=")])) };
    state.objects[to] = { ...source, timeCreated: new Date().toISOString(), ...(Object.keys(metadata).length > 0 && { metadata }), ...(wanted !== undefined && { customTime: wanted }) };
    delete state.objects[from];
    save();
    break;
  }
  default:
    fail(`the stand-in knows no ${args.join(" ")}`);
}
