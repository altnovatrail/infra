#!/usr/bin/env node
// The organizer's tool for the operator's bucket (R28; docs/architecture.md, section 3.7). It runs
// where gcloud is signed in as the measurement organizer or the eval-set organizer — Cloud Shell or
// their own machine with Linux or macOS, where gcloud is a program of that name — on Node.js alone,
// with no package of tools/package.json.
//
//   link <purpose> [--samples=N] [--hours=H] [--session=ID] [--out=FILE]
//       an upload link: one self-contained HTML page with a form per file, each form a V4 POST
//       policy signed through IAM by the purpose's upload service account, with no key, valid for at
//       most 12 hours (sources 10.1, 10.8);
//   time <object>... --date=YYYY-MM-DD
//       the Custom-Time of a form, a record or a report, by its prefix: of a measurement's or a
//       parent's form, the date of the last session under it plus 730 days; of a record, the date of
//       its session; of a report, the date of the earliest sample it names; of what lies in
//       eval-set/forms/, the date of the signature;
//   withdraw <form>... --erased=YYYY-MM-DD
//       a measurement's or a parent's form rewritten with the day its samples were erased;
//   contribute <session>
//       a volunteer's form, with its record, moved from eval-set/forms/<session>/ to
//       eval-set/contributed-forms/<session>/;
//   untimed
//       the forms, records and reports that no rule erases, since they have no Custom-Time.
//
// --tfvars=FILE names the values' file, tofu/production.auto.tfvars of the repository unless given:
// the project and the operator's bucket are read from it, by the reader the deployment reads it with.
// The page is written where the tool runs; .gitignore keeps upload-*.html out of a commit, since
// whoever holds a page may upload by it until it expires.

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// The deployment's reader of the values' file, which imports nothing, so the tool still needs no
// package.
import { tfvarsValue } from "../deploy-check/setup.mjs";

// What a link may be valid for: a signature through IAM, with no key of the service account, lives
// at most 12 hours (sources 10.1; R28).
export const MAX_HOURS = 12;

// A sample file of the samples page of canvas, `<id>.json` of `application/json`: canvas bounds its
// size by nothing, and its largest synthetic sample of v0.3.16 is 890,008 bytes (sources 10.8).
export const SAMPLE = { type: "application/json", extension: "json", max: 16 * 1024 * 1024 };

// A scan of a form, as api takes one: a JPEG, a PNG or a PDF, up to 10 MiB (sources 10.5). A policy
// holds one condition a field, so each type has a form of its own (sources 10.1).
export const SCANS = [
  { type: "application/pdf", extension: "pdf", accept: ".pdf,application/pdf", label: "one PDF" },
  { type: "image/jpeg", extension: "jpg", accept: ".jpg,.jpeg,image/jpeg", label: "a JPEG photo" },
  { type: "image/png", extension: "png", accept: ".png,image/png", label: "a PNG image" },
];
export const SCAN_MAX = 10 * 1024 * 1024;

// Each purpose's prefix and the upload service account its links are signed as: the measurement
// organizer's for measurements and children, the eval-set organizer's for the eval sets (R28).
export const PURPOSES = {
  measure: { account: "upload-measure", what: "measurement session", form: "the signed measurement form" },
  child: { account: "upload-measure", what: "children's samples session", form: "the parent's signed form" },
  "eval-set": { account: "upload-eval-set", what: "eval-set samples", form: "your signed volunteer form" },
};

// The prefixes whose lifecycle rule reads the Custom-Time, and how its date is reckoned (section 3.7).
// A form of a measurement or of a parent keeps 5 years after its samples, which the rule of samples
// erases 2 years from the session: its Custom-Time is the session plus 730 days.
// `rule` is the days of the rule that erases by it, as bootstrap.sh writes the rules.
const FORM_DAYS = 730;
const TIMED = [
  { prefix: /^(measure|child)\/forms\/[^/]+\/./, days: FORM_DAYS, rule: 1827, kind: "form" },
  { prefix: /^(measure|child)\/(records|reports)\/./, days: 0, rule: 728, kind: "record" },
  { prefix: /^eval-set\/forms\/[^/]+\/./, days: 0, rule: 364, kind: "volunteer's form" },
];
const DAY = 86400 * 1000;

// What no rule erases without a Custom-Time, listed prefix by prefix: in eval-set/forms/ the rule by
// age erases it anyway.
const UNTIMED = ["measure", "child"].flatMap((purpose) => ["forms", "records", "reports"].map((kind) => `${purpose}/${kind}/`));

// A session's ID and an object's random name: 16 hex characters, as api names a scan's suffix.
const ID = /^[0-9a-f]{16}$/;
const randomId = () => crypto.randomBytes(8).toString("hex");

export class Refusal extends Error {}
const refuse = (text) => {
  throw new Refusal(text);
};

// --- the values ---------------------------------------------------------------------------------

export function readValues(file) {
  if (!fs.existsSync(file)) refuse(`there is no ${file}: name the values' file with --tfvars=FILE`);
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const value = (name) => /^"([^"]*)"/.exec(tfvarsValue(lines, name) ?? "")?.[1];
  const project = value("project_id");
  const bucket = value("operator_bucket");
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project ?? "")) refuse(`${file} names no project_id`);
  if (!/^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$/.test(bucket ?? "")) refuse(`${file} names no operator_bucket`);
  return { project, bucket };
}

// --- the link -----------------------------------------------------------------------------------

const pad = (n) => String(n).padStart(2, "0");
// 20261113T090000Z, x-goog-date's basic format, and its date, the credential's scope.
export const basic = (d) =>
  `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`;
// 2026-11-13T21:00:00Z, as Google's library writes the policy's expiration (sources 10.8).
export const extended = (d) => d.toISOString().replace(/\.\d{3}Z$/, "Z");

// The policy of one kind of file: the bucket, the prefix of the session's folder, the type and the
// size, the status of the answer, and the algorithm, credential and date of the signature. Every
// field the form sends but the signature, the policy and the file has its condition (sources 10.8).
export function policyOf({ bucket, prefix, type, max, credential, date, expiration }) {
  return {
    conditions: [
      { bucket },
      ["starts-with", "$key", prefix],
      { "Content-Type": type },
      ["content-length-range", 1, max],
      { success_action_status: "201" },
      { "x-goog-algorithm": "GOOG4-RSA-SHA256" },
      { "x-goog-credential": credential },
      { "x-goog-date": basic(date) },
    ],
    expiration: extended(expiration),
  };
}

// The policy as the form sends it, base64 of its JSON, and its signature, in hex: IAM's signBlob of
// those base64 bytes as the upload service account, by gcloud, which writes the signature's raw
// bytes to its output file (sources 10.8).
export function sign(policy, account, gcloud = runGcloud) {
  const encoded = Buffer.from(JSON.stringify(policy), "utf8").toString("base64");
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "organizer-"));
  try {
    const input = path.join(dir, "policy");
    const output = path.join(dir, "signature");
    fs.writeFileSync(input, encoded);
    gcloud(["iam", "service-accounts", "sign-blob", `--iam-account=${account}`, input, output]);
    const signature = fs.existsSync(output) ? fs.readFileSync(output) : Buffer.alloc(0);
    if (signature.length === 0) refuse(`gcloud signed nothing as ${account}`);
    return { policy: encoded, signature: signature.toString("hex") };
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const escape = (text) =>
  String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

function formOf({ bucket, key, type, accept, signed, credential, date, label }) {
  const hidden = {
    key,
    "Content-Type": type,
    success_action_status: "201",
    "x-goog-algorithm": "GOOG4-RSA-SHA256",
    "x-goog-credential": credential,
    "x-goog-date": basic(date),
    "x-goog-signature": signed.signature,
    policy: signed.policy,
  };
  const fields = Object.entries(hidden)
    .map(([name, value]) => `      <input type="hidden" name="${escape(name)}" value="${escape(value)}">`)
    .join("\n");
  // The file is the form's last field, as Cloud Storage asks (sources 10.8).
  return `    <form action="https://storage.googleapis.com/${escape(bucket)}/" method="post" enctype="multipart/form-data" target="_blank">
${fields}
      <label>${escape(label)} <input type="file" name="file" accept="${escape(accept)}" required></label>
      <button type="submit">Send</button>
    </form>`;
}

// The page the organizer gives the adult: no script, nothing loaded from elsewhere, and its forms
// post to Cloud Storage alone, each answer in a tab of its own.
export function pageOf({ purpose, bucket, session, expiration, samples, scans }) {
  const about = PURPOSES[purpose];
  const until = extended(expiration).replace("T", " ").replace("Z", " UTC");
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; form-action https://storage.googleapis.com">
  <meta name="referrer" content="no-referrer">
  <title>Upload: ${escape(about.what)}</title>
  <style>
    body { font: 16px/1.5 system-ui, sans-serif; max-width: 40rem; margin: 0 auto; padding: 1rem; }
    form { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin: 0.5rem 0; padding: 0.5rem; border: 1px solid #888; border-radius: 0.25rem; }
  </style>
</head>
<body>
  <h1>Upload: ${escape(about.what)}</h1>
  <p>This page works until <strong>${escape(until)}</strong>. Session <code>${escape(session)}</code>.</p>
  <p>Send each file with a form of its own. A form sends one file, once: a second sending of the same form is refused. Each answer opens in a new tab; one that names a <code>Key</code> means the file arrived.</p>
  <p>Once your files have arrived, erase them from your device.</p>
  <h2>Sample files</h2>
  <p>The files the samples page saved, ending in <code>.json</code>, up to 16 MiB each.</p>
${samples.map((form) => formOf({ bucket, ...form })).join("\n")}
  <h2>The form</h2>
  <p>The scan of ${escape(about.form)}, up to 10 MiB: send it with one of these, by its kind. A form of several pages goes as one PDF.</p>
${scans.map((form) => formOf({ bucket, ...form })).join("\n")}
</body>
</html>
`;
}

// The link of a purpose: its policies signed, its page written. `now` is when it is made.
export function link({ purpose, bucket, project, samples = 10, hours = MAX_HOURS, session = randomId(), now = new Date(), gcloud = runGcloud }) {
  if (!Object.hasOwn(PURPOSES, purpose)) refuse(`no purpose ${purpose}: one of ${Object.keys(PURPOSES).join(", ")}`);
  if (!(Number.isInteger(samples) && samples >= 1 && samples <= 100)) refuse(`--samples is a whole number from 1 to 100, not ${samples}`);
  if (!(Number.isInteger(hours) && hours >= 1 && hours <= MAX_HOURS))
    refuse(`--hours is a whole number from 1 to ${MAX_HOURS}, not ${hours}: a signature through IAM, with no key, lives at most ${MAX_HOURS} hours`);
  if (!ID.test(session)) refuse(`a session is 16 hex characters, as the tool gives one, not ${session}`);
  const date = new Date(Math.floor(now.getTime() / 1000) * 1000);
  const expiration = new Date(date.getTime() + hours * 3600 * 1000);
  const account = `${PURPOSES[purpose].account}@${project}.iam.gserviceaccount.com`;
  // The location `auto`, as Google's library writes the credential (sources 10.8).
  const credential = `${account}/${basic(date).slice(0, 8)}/auto/storage/goog4_request`;
  const common = { bucket, credential, date, expiration };

  const samplesPrefix = `${purpose}/samples/${session}/`;
  const samplesSigned = sign(policyOf({ ...common, prefix: samplesPrefix, type: SAMPLE.type, max: SAMPLE.max }), account, gcloud);
  const sampleForms = Array.from({ length: samples }, (_, i) => ({
    key: `${samplesPrefix}${randomId()}.${SAMPLE.extension}`,
    type: SAMPLE.type,
    accept: ".json,application/json",
    signed: samplesSigned,
    credential,
    date,
    label: `Sample ${i + 1}`,
  }));

  const formsPrefix = `${purpose}/forms/${session}/`;
  const scanForms = SCANS.map((scan) => ({
    key: `${formsPrefix}${randomId()}.${scan.extension}`,
    type: scan.type,
    accept: scan.accept,
    signed: sign(policyOf({ ...common, prefix: formsPrefix, type: scan.type, max: SCAN_MAX }), account, gcloud),
    credential,
    date,
    label: `The form as ${scan.label}`,
  }));

  return { session, expiration, account, page: pageOf({ purpose, bucket, session, expiration, samples: sampleForms, scans: scanForms }) };
}

// --- the Custom-Time ----------------------------------------------------------------------------

// A date of the organizer's, YYYY-MM-DD, as midnight UTC; no later than tomorrow, by UTC, for a
// session or an erasure that has happened.
export function dayOf(text, flag, now = new Date()) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text ?? "")) refuse(`--${flag} is a date, YYYY-MM-DD`);
  const day = new Date(`${text}T00:00:00Z`);
  if (Number.isNaN(day.getTime()) || extended(day).slice(0, 10) !== text) refuse(`--${flag}=${text} is no date`);
  if (day.getTime() > now.getTime() + DAY) refuse(`--${flag}=${text} has not come yet`);
  return day;
}

// An object of the operator's bucket, given by its name or as gs://<bucket>/<name>: its name.
export function objectName(given, bucket) {
  const url = `gs://${bucket}/`;
  if (given.startsWith("gs://") && !given.startsWith(url)) refuse(`${given} is not in the operator's bucket, ${url}`);
  const name = given.startsWith(url) ? given.slice(url.length) : given;
  if (name === "" || name.endsWith("/") || name.includes("*")) refuse(`${given} names no single object`);
  return name;
}

// The Custom-Time the time command gives an object, by its prefix, and the rule that reads it.
export function customTimeOf(name, day) {
  const timed = TIMED.find((t) => t.prefix.test(name)) ?? refuse(`no rule of the bucket reads the Custom-Time of ${name}: only the forms, the records and the reports have one`);
  return { time: extended(new Date(day.getTime() + timed.days * DAY)), kind: timed.kind, rule: timed.rule };
}

// A date mistyped by years would have the rule erase the object at its next pass, for good, as soft
// delete is off: a Custom-Time its rule has already reached is refused.
function refuseIfDue(name, time, rule, now) {
  if (Date.parse(time) + rule * DAY <= now.getTime())
    refuse(`${name}: with the Custom-Time ${time} its rule, ${rule} days, would erase it at once; check the date`);
}

function describe(bucket, name, gcloud) {
  const text = gcloud(["storage", "objects", "describe", `gs://${bucket}/${name}`, "--raw", "--format=json"]);
  return JSON.parse(text);
}

// Every object is read and held to the rules before any changes, so that a refusal leaves all as
// they were.
export function time({ bucket, objects, date, now = new Date(), gcloud = runGcloud, say = console.log }) {
  if (objects.length === 0) refuse("name the objects whose Custom-Time to set");
  const planned = objects.map((given) => {
    const name = objectName(given, bucket);
    return { name, ...customTimeOf(name, date) };
  });
  for (const plan of planned) {
    const { name, time: wanted, rule } = plan;
    const found = describe(bucket, name, gcloud);
    plan.current = found.customTime;
    // A withdrawal set the form's 5 years from the day its samples were erased; a session after it
    // would stretch them, and a new period takes a new form (R125 spec).
    if (found.metadata?.withdrawn) refuse(`${name}: its samples were withdrawn on ${found.metadata.withdrawn}, and its Custom-Time stays; a new session takes a new form`);
    // A Custom-Time cannot decrease (sources 10.3): a form whose samples were erased early is
    // rewritten by withdraw instead.
    if (plan.current && Date.parse(plan.current) > Date.parse(wanted))
      refuse(`${name}: its Custom-Time is ${plan.current}, later than ${wanted}, and it cannot decrease; a form whose samples were withdrawn takes withdraw`);
    refuseIfDue(name, wanted, rule, now);
  }
  for (const { name, time: wanted, kind, current } of planned) {
    if (current && Date.parse(current) === Date.parse(wanted)) {
      say(`${name}: the ${kind}'s Custom-Time is ${wanted} already`);
      continue;
    }
    gcloud(["storage", "objects", "update", `gs://${bucket}/${name}`, `--custom-time=${wanted}`]);
    say(`${name}: the ${kind}'s Custom-Time is ${wanted}`);
  }
}

// A withdrawal erases the samples before their term, and the form keeps 5 years from that day: the
// form is rewritten with the day, since only a rewrite resets a Custom-Time (section 3.7; sources
// 10.3). gcloud rewrites an object by a copy, which takes --custom-time in place of the source's,
// and copies none onto itself, nor does objects update rewrite one of the same class (sources 10.8):
// so the form moves to a name beside it and back, each move a copy and an erasure. The form keeps
// the day in its metadata, `withdrawn`, by which time refuses to move it forward again.
export function withdraw({ bucket, objects, erased, now = new Date(), gcloud = runGcloud, say = console.log }) {
  if (objects.length === 0) refuse("name the forms whose samples were erased");
  const wanted = extended(erased);
  const names = objects.map((given) => {
    const name = objectName(given, bucket);
    if (!TIMED[0].prefix.test(name)) refuse(`${name} is no form of a measurement or of a parent, measure/forms/ or child/forms/`);
    return name;
  });
  for (const name of names) {
    // The form came before its first session, so its samples were erased after it arrived; a form
    // withdrawn already was rewritten since, and its creation is that of the rewrite.
    const found = describe(bucket, name, gcloud);
    const arrived = found.metadata?.withdrawn ? undefined : found.timeCreated;
    if (arrived && Date.parse(`${arrived.slice(0, 10)}T00:00:00Z`) > erased.getTime())
      refuse(`${name} arrived on ${arrived.slice(0, 10)}, after ${wanted.slice(0, 10)}: check the day its samples were erased`);
    refuseIfDue(name, wanted, TIMED[0].rule, now);
  }
  const flags = [`--custom-time=${wanted}`, `--update-custom-metadata=withdrawn=${wanted.slice(0, 10)}`];
  for (const name of names) {
    const url = `gs://${bucket}/${name}`;
    const aside = `${url}.rewrite`;
    gcloud(["storage", "mv", url, aside, ...flags]);
    try {
      gcloud(["storage", "mv", aside, url, ...flags]);
    } catch (error) {
      // The form is whole under the name beside it, and its rule erases it there too.
      refuse(`${error.message}\nthe form lies at ${aside}, with its Custom-Time; move it back: gcloud storage mv ${aside} ${url} ${flags.join(" ")}`);
    }
    say(`${name}: rewritten, its Custom-Time is ${wanted}`);
  }
}

// The objects under a prefix, by their API's metadata, or none where none matches.
function list(url, gcloud) {
  let text;
  try {
    text = gcloud(["storage", "objects", "list", url, "--raw", "--format=json"]);
  } catch (error) {
    if (/matched no objects/i.test(error.message)) return [];
    throw error;
  }
  return JSON.parse(text || "[]");
}

// A volunteer's form by which a sample was contributed lives as long as the sample is published:
// it moves, with its record, out of the prefix whose rule erases it in 12 months (R126 spec).
export function contribute({ bucket, session, gcloud = runGcloud, say = console.log }) {
  if (!ID.test(session ?? "")) refuse(`a session is 16 hex characters, as the tool gives one, not ${session}`);
  const from = `eval-set/forms/${session}/`;
  const to = `eval-set/contributed-forms/${session}/`;
  const objects = list(`gs://${bucket}/${from}**`, gcloud).map((o) => o.name);
  if (objects.length === 0) refuse(`there is nothing under ${from}`);
  for (const name of objects) {
    // Each object to its own name, so that a destination already there does not nest the folder.
    gcloud(["storage", "mv", `gs://${bucket}/${name}`, `gs://${bucket}/${to}${name.slice(from.length)}`]);
    say(`${name} → ${to}${name.slice(from.length)}`);
  }
}

export function untimed({ bucket, gcloud = runGcloud, say = console.log }) {
  const found = UNTIMED.flatMap((prefix) => list(`gs://${bucket}/${prefix}**`, gcloud)).filter((o) => !o.customTime);
  for (const o of found) say(o.name);
  if (found.length === 0) say("every form, record and report has its Custom-Time");
  return found.map((o) => o.name);
}

// --- the command line ---------------------------------------------------------------------------

export function runGcloud(args) {
  try {
    // A listing of a prefix is an object's metadata a kilobyte: more room than Node's 1 MiB.
    return execFileSync("gcloud", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 256 * 1024 * 1024 });
  } catch (error) {
    if (error.code === "ENOENT") refuse("there is no gcloud here: run the tool where the Google Cloud CLI is, signed in as the organizer");
    throw new Refusal(`gcloud ${args.slice(0, 3).join(" ")} failed: ${(error.stderr || error.message).trim()}`);
  }
}

function parse(argv) {
  const flags = {};
  const words = [];
  for (const arg of argv) {
    const match = arg.match(/^--([a-z-]+)=(.*)$/);
    if (match) flags[match[1]] = match[2];
    else if (arg.startsWith("--")) refuse(`${arg}: a flag is --name=value`);
    else words.push(arg);
  }
  return { flags, words };
}

const whole = (text, flag) => (/^\d+$/.test(text) ? Number(text) : refuse(`--${flag} is a whole number, not ${text}`));

export function main(argv, { gcloud = runGcloud, say = console.log, cwd = process.cwd() } = {}) {
  const [command, ...rest] = argv;
  const { flags, words } = parse(rest);
  const known = { link: ["samples", "hours", "session", "out", "tfvars"], time: ["date", "tfvars"], withdraw: ["erased", "tfvars"], contribute: ["tfvars"], untimed: ["tfvars"] };
  if (!Object.hasOwn(known, command)) refuse(`a command is one of ${Object.keys(known).join(", ")}`);
  for (const flag of Object.keys(flags)) if (!known[command].includes(flag)) refuse(`${command} takes no --${flag}`);
  const here = path.dirname(fileURLToPath(import.meta.url));
  const { project, bucket } = readValues(path.resolve(cwd, flags.tfvars ?? path.join(here, "..", "..", "tofu", "production.auto.tfvars")));

  switch (command) {
    case "link": {
      if (words.length !== 1) refuse("link takes one purpose: measure, child or eval-set");
      const session = flags.session ?? randomId();
      const out = path.resolve(cwd, flags.out ?? `upload-${words[0]}-${session}.html`);
      // A page already there is not written over: it may be a link already given.
      if (fs.existsSync(out)) refuse(`${out} is there already: name another with --out=FILE`);
      const made = link({
        purpose: words[0],
        bucket,
        project,
        session,
        gcloud,
        ...(flags.samples !== undefined && { samples: whole(flags.samples, "samples") }),
        ...(flags.hours !== undefined && { hours: whole(flags.hours, "hours") }),
      });
      try {
        fs.writeFileSync(out, made.page, { flag: "wx" });
      } catch (error) {
        if (error.code === "EEXIST") refuse(`${out} is there already: name another with --out=FILE`);
        throw error;
      }
      say(`session ${made.session}, signed as ${made.account}, valid until ${extended(made.expiration)}`);
      say(`the page: ${out}`);
      return;
    }
    case "time":
      return time({ bucket, objects: words, date: dayOf(flags.date, "date"), gcloud, say });
    case "withdraw":
      return withdraw({ bucket, objects: words, erased: dayOf(flags.erased, "erased"), gcloud, say });
    case "contribute":
      if (words.length !== 1) refuse("contribute takes one session");
      return contribute({ bucket, session: words[0], gcloud, say });
    case "untimed":
      if (words.length !== 0) refuse("untimed takes nothing");
      untimed({ bucket, gcloud, say });
  }
}

if (process.argv[1] && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    if (!(error instanceof Refusal)) throw error;
    console.error(`organizer: ${error.message}`);
    process.exit(1);
  }
}
