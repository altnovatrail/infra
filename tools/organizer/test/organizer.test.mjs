// The test of tools/organizer/organizer.mjs, with no cloud: gcloud-stub.mjs stands in for gcloud,
// named to the tool by ORGANIZER_GCLOUD, and signs with a key made here, so that each form's
// signature is checked as Cloud Storage would check it. It holds the link to R28 — the purpose's own prefixes and upload service
// account, at most 12 hours, the type and size of each file, a random name for each — and the
// Custom-Time to section 3.7 of docs/architecture.md. Run by `just organizer-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";


const here = path.dirname(fileURLToPath(import.meta.url));
const tool = path.join(here, "..", "organizer.mjs");
const stub = path.join(here, "gcloud-stub.mjs");

const made = [];
after(() => {
  for (const dir of made) fs.rmSync(dir, { recursive: true, force: true });
});

// What R28 and section 3.7 set, written here and not taken from the tool, so that a tool that drifts
// from them fails: at most 12 hours; each purpose's prefixes and upload service account; a sample
// of the samples page, and a scan as api takes one (sources 10.5, 10.8).
const MAX_HOURS = 12;
const ACCOUNTS = { measure: "upload-measure", child: "upload-measure", "eval-set": "upload-eval-set" };
const SAMPLE = { type: "application/json", max: 16 * 1024 * 1024 };
const SCANS = [{ type: "application/pdf" }, { type: "image/jpeg" }, { type: "image/png" }];
const SCAN_MAX = 10 * 1024 * 1024;

const project = "novatrail-test-0";
const bucket = "novatrail-test-0-operator";
const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });

// A folder with the values' file, the stand-in on PATH and its state: the bucket's objects.
function world(objects = {}, { tfvars = `project_id = "${project}"\noperator_bucket = "${bucket}"\n`, signError } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "organizer-test-"));
  made.push(dir);
  fs.mkdirSync(path.join(dir, "bin"));
  fs.writeFileSync(path.join(dir, "bin", "gcloud"), `#!/bin/sh\nexec node ${JSON.stringify(stub)} "$@"\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, "key.pem"), privateKey.export({ type: "pkcs8", format: "pem" }));
  fs.writeFileSync(path.join(dir, "values.tfvars"), tfvars);
  fs.writeFileSync(path.join(dir, "state.json"), JSON.stringify({ bucket, objects, signError }));
  fs.writeFileSync(path.join(dir, "log"), "");
  const runWith = (gcloud, ...args) => {
    const result = spawnSync("node", [tool, ...args, "--tfvars=values.tfvars"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, ORGANIZER_GCLOUD: gcloud, STUB_STATE: path.join(dir, "state.json"), STUB_KEY: path.join(dir, "key.pem"), STUB_LOG: path.join(dir, "log") },
    });
    return { ...result, output: result.stdout + result.stderr };
  };
  const run = (...args) => runWith(path.join(dir, "bin", "gcloud"), ...args);
  const calls = () =>
    fs
      .readFileSync(path.join(dir, "log"), "utf8")
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  const objectsNow = () => JSON.parse(fs.readFileSync(path.join(dir, "state.json"), "utf8")).objects;
  return { dir, run, runWith, calls, objects: objectsNow };
}

// The forms of a page: each one's action, target, hidden fields in order, and its file input.
function formsOf(page) {
  return [...page.matchAll(/<form ([^>]*)>([\s\S]*?)<\/form>/g)].map(([, attributes, body]) => {
    const inputs = [...body.matchAll(/<input ([^>]*)>/g)].map(([, a]) => Object.fromEntries([...a.matchAll(/([a-z-]+)="([^"]*)"/g)].map(([, k, v]) => [k, v.replaceAll("&quot;", '"').replaceAll("&amp;", "&")])));
    const attrs = Object.fromEntries([...attributes.matchAll(/([a-z-]+)="([^"]*)"/g)].map(([, k, v]) => [k, v]));
    const fields = Object.fromEntries(inputs.filter((i) => i.type === "hidden").map((i) => [i.name, i.value]));
    return { attrs, inputs, fields };
  });
}

// What Cloud Storage would take of a form: its policy, decoded, by the signature of the service
// account the credential names, and each field the form sends held to its condition (sources 10.8).
function accepted(form) {
  const { fields } = form;
  assert.ok(crypto.verify("sha256", Buffer.from(fields.policy), publicKey, Buffer.from(fields["x-goog-signature"], "hex")), "the signature holds");
  const policy = JSON.parse(Buffer.from(fields.policy, "base64").toString("utf8"));
  const sent = { bucket, ...fields };
  delete sent.policy;
  delete sent["x-goog-signature"];
  const named = new Set();
  let range;
  for (const condition of policy.conditions) {
    if (Array.isArray(condition) && condition[0] === "content-length-range") {
      range = condition.slice(1);
    } else if (Array.isArray(condition)) {
      const [op, field, value] = condition;
      named.add(field.slice(1));
      if (op === "starts-with") assert.ok(sent[field.slice(1)].startsWith(value), `${field} starts with ${value}`);
      else assert.equal(sent[field.slice(1)], value);
    } else {
      const [[field, value]] = Object.entries(condition);
      named.add(field);
      assert.equal(sent[field], value, `the form's ${field}`);
    }
  }
  assert.deepEqual([...named].sort(), Object.keys(sent).sort(), "every field the form sends has its condition");
  return { policy, range };
}

// A form's x-goog-date, 20261113T090000Z, in milliseconds.
const dateOf = (form) => Date.parse(form.fields["x-goog-date"].replace(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/, "$1-$2-$3T$4:$5:$6Z"));

function prefixOf(policy) {
  return policy.conditions.find((c) => Array.isArray(c) && c[0] === "starts-with" && c[1] === "$key")[2];
}

function linkOf(w, purpose, ...flags) {
  const result = w.run("link", purpose, "--out=page.html", ...flags);
  assert.equal(result.status, 0, result.output);
  const page = fs.readFileSync(path.join(w.dir, "page.html"), "utf8");
  return { page, forms: formsOf(page), output: result.output };
}

for (const purpose of Object.keys(ACCOUNTS)) {
  test(`a link of ${purpose}: its own prefixes, its own upload service account, no longer than ${MAX_HOURS} hours`, () => {
    const w = world();
    const before = Date.now();
    const { page, forms } = linkOf(w, purpose, "--samples=3");
    const account = `${ACCOUNTS[purpose]}@${project}.iam.gserviceaccount.com`;
    const session = page.match(/Session <code>([0-9a-f]{16})<\/code>/)[1];

    assert.equal(forms.length, 3 + SCANS.length);
    const keys = new Set();
    for (const [i, form] of forms.entries()) {
      const { policy, range } = accepted(form);
      const sample = i < 3;
      const prefix = sample ? `${purpose}/samples/${session}/` : `${purpose}/forms/${session}/`;
      // Another purpose's prefix, or another kind's, fails here.
      assert.equal(prefixOf(policy), prefix);
      assert.match(form.fields.key, new RegExp(`^${prefix}[0-9a-f]{16}\\.(json|pdf|jpg|png)$`));
      keys.add(form.fields.key);
      assert.equal(form.fields["Content-Type"], sample ? SAMPLE.type : SCANS[i - 3].type);
      assert.deepEqual(range, [1, sample ? SAMPLE.max : SCAN_MAX]);
      assert.equal(form.fields["x-goog-credential"].split("/")[0], account);
      assert.match(form.fields["x-goog-credential"], /^[^/]+\/\d{8}\/auto\/storage\/goog4_request$/);
      // The expiration: no later than 12 hours from the signature's date, and that date now.
      const date = dateOf(form);
      assert.ok(date >= before - 1000 && date <= Date.now(), "the date is when the link was made");
      assert.ok(Date.parse(policy.expiration) - date <= MAX_HOURS * 3600 * 1000, `expires within ${MAX_HOURS} hours: ${policy.expiration}`);
      assert.equal(Date.parse(policy.expiration) - date, MAX_HOURS * 3600 * 1000, "by default, the longest");
      assert.equal(form.attrs.action, `https://storage.googleapis.com/${bucket}/`);
      assert.equal(form.attrs.method, "post");
      assert.equal(form.attrs.enctype, "multipart/form-data");
      // The file is the form's last field.
      assert.equal(form.inputs.at(-1).type, "file");
      assert.equal(form.inputs.at(-1).name, "file");
    }
    assert.equal(keys.size, forms.length, "each form its own object");
    // Signed as the purpose's account alone, once for the samples and once a type of scan.
    const signs = w.calls().filter((c) => c.slice(0, 3).join(" ") === "iam service-accounts sign-blob");
    assert.equal(signs.length, 1 + SCANS.length);
    for (const call of signs) assert.equal(call[3], `--iam-account=${account}`);
    // A page with no script and nothing from elsewhere.
    assert.doesNotMatch(page, /<script|src=|<link /i);
    assert.match(page, /form-action https:\/\/storage\.googleapis\.com"/);
  });
}

test("a link shorter than 12 hours, and none longer", () => {
  const w = world();
  const { forms } = linkOf(w, "measure", "--hours=2", "--samples=1");
  const { policy } = accepted(forms[0]);
  assert.equal(Date.parse(policy.expiration) - dateOf(forms[0]), 2 * 3600 * 1000);
  for (const hours of ["13", "0", "24"]) {
    const result = w.run("link", "measure", `--hours=${hours}`, `--out=h${hours}.html`);
    assert.equal(result.status, 1);
    assert.match(result.output, /--hours is a whole number from 1 to 12/);
  }
  assert.equal(w.calls().length, 1 + SCANS.length, "a refused link signs nothing");
});

test("refusals of link: a purpose, a session, a page already there, a failed signature", () => {
  const w = world();
  for (const [args, reason] of [
    [["link", "measures"], /no purpose measures/],
    [["link", "measure", "--session=Ab-12"], /a session is 16 hex characters/],
    [["link", "measure", "--samples=0"], /--samples is a whole number from 1 to 100/],
    [["link", "measure", "--samples=x"], /--samples is a whole number/],
    [["link", "measure", "--date=2026-11-13"], /link takes no --date/],
    [["link"], /link takes one purpose/],
  ]) {
    const result = w.run(...args);
    assert.equal(result.status, 1, args.join(" "));
    assert.match(result.output, reason);
  }
  fs.writeFileSync(path.join(w.dir, "given.html"), "a link already given");
  const result = w.run("link", "child", "--out=given.html");
  assert.match(result.output, /is there already/);
  assert.equal(fs.readFileSync(path.join(w.dir, "given.html"), "utf8"), "a link already given");
  assert.equal(w.calls().length, 0, "nothing signed");

  const failing = world({}, { signError: "PERMISSION_DENIED: iam.serviceAccounts.signBlob" });
  const failed = failing.run("link", "eval-set", "--out=page.html");
  assert.equal(failed.status, 1);
  assert.match(failed.output, /gcloud iam service-accounts sign-blob failed: .*PERMISSION_DENIED/);
  assert.equal(fs.existsSync(path.join(failing.dir, "page.html")), false, "a link not signed leaves no page");
});

test("gcloud by its absolute path alone, never by PATH", () => {
  const w = world();
  const relative = w.runWith("bin/gcloud", "link", "measure", "--out=page.html");
  assert.equal(relative.status, 1);
  assert.match(relative.output, /ORGANIZER_GCLOUD is bin\/gcloud, and it must be an absolute path/);
  const missing = w.runWith(path.join(w.dir, "none", "gcloud"), "link", "measure", "--out=page.html");
  assert.equal(missing.status, 1);
  assert.match(missing.output, /there is no .*none\/gcloud: set ORGANIZER_GCLOUD/);
  assert.equal(fs.existsSync(path.join(w.dir, "page.html")), false);
});

test("a second link of the same session: the same folders, new names", () => {
  const w = world();
  const first = linkOf(w, "child", "--samples=1", "--session=0123456789abcdef");
  fs.renameSync(path.join(w.dir, "page.html"), path.join(w.dir, "first.html"));
  const second = linkOf(w, "child", "--samples=1", "--session=0123456789abcdef");
  for (const { forms } of [first, second]) assert.ok(forms[0].fields.key.startsWith("child/samples/0123456789abcdef/"));
  assert.notEqual(first.forms[0].fields.key, second.forms[0].fields.key);
});

test("the values' file names the project and the bucket", () => {
  for (const tfvars of [`operator_bucket = "${bucket}"\n`, `project_id = "${project}"\n`, `project_id = "X"\noperator_bucket = "${bucket}"\n`]) {
    const result = world({}, { tfvars }).run("untimed");
    assert.equal(result.status, 1);
    assert.match(result.output, /names no (project_id|operator_bucket)/);
  }
  const result = world().run("unknown");
  assert.match(result.output, /a command is one of link, time, withdraw, contribute, untimed/);
});

const forms = {
  "measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf": {},
  "child/forms/0123456789abcdef/bbbbbbbbbbbbbbbb.jpg": { customTime: "2028-11-10T00:00:00Z" },
  "measure/records/session-0123456789abcdef.json": {},
  "child/reports/run-1.json": {},
  "eval-set/forms/fedcba9876543210/cccccccccccccccc.pdf": {},
  "eval-set/forms/fedcba9876543210/record.json": {},
  "measure/samples/0123456789abcdef/dddddddddddddddd.json": {},
  "eval-set/contributed-forms/1111111111111111/form.pdf": {},
  "measure/forms/0123456789abcdef/withdrawn.pdf": { customTime: "2026-11-05T00:00:00Z", metadata: { withdrawn: "2026-11-05" } },
};

test("time: a form keeps 730 days past its session, a record and a report the session's date", () => {
  const w = world(structuredClone(forms));
  const result = w.run("time", "measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf", `gs://${bucket}/measure/records/session-0123456789abcdef.json`, "child/reports/run-1.json", "eval-set/forms/fedcba9876543210/record.json", "--date=2026-11-13");
  assert.equal(result.status, 0, result.output);
  const objects = w.objects();
  assert.equal(objects["measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf"].customTime, "2028-11-12T00:00:00Z");
  assert.equal(objects["measure/records/session-0123456789abcdef.json"].customTime, "2026-11-13T00:00:00Z");
  assert.equal(objects["child/reports/run-1.json"].customTime, "2026-11-13T00:00:00Z");
  assert.equal(objects["eval-set/forms/fedcba9876543210/record.json"].customTime, "2026-11-13T00:00:00Z");

  // A new session moves a form forward; the same date changes nothing.
  const again = w.run("time", "child/forms/0123456789abcdef/bbbbbbbbbbbbbbbb.jpg", "--date=2026-11-11");
  assert.equal(again.status, 0, again.output);
  assert.match(again.output, /Custom-Time is 2028-11-10T00:00:00Z already/);
  const updates = w.calls().filter((c) => c[2] === "update");
  assert.equal(updates.length, 4);
});

test("time refuses what no rule reads, a Custom-Time made earlier, a date to come and another bucket", () => {
  const w = world(structuredClone(forms));
  for (const [args, reason] of [
    [["measure/samples/0123456789abcdef/dddddddddddddddd.json", "--date=2026-11-13"], /no rule of the bucket reads the Custom-Time/],
    [["eval-set/contributed-forms/1111111111111111/form.pdf", "--date=2026-11-13"], /no rule of the bucket reads the Custom-Time/],
    [["child/forms/0123456789abcdef/bbbbbbbbbbbbbbbb.jpg", "--date=2026-11-01"], /later than 2028-10-31T00:00:00Z, and it cannot decrease; .* withdraw/],
    [["measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf", "--date=2999-01-01"], /has not come yet/],
    [["measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf", "--date=2026-02-30"], /is no date/],
    [["measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf"], /--date is a date/],
    [["gs://another/measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf", "--date=2026-11-13"], /is not in the operator's bucket/],
    [["measure/forms/*", "--date=2026-11-13"], /names no single object/],
    // A year mistyped: the rule would erase the record at its next pass.
    [["measure/records/session-0123456789abcdef.json", "--date=2024-11-13"], /its rule, 728 days, would erase it at once; check the date/],
    [["measure/forms/0123456789abcdef/withdrawn.pdf", "--date=2026-11-13"], /its samples were withdrawn on 2026-11-05, and its Custom-Time stays; a new session takes a new form/],
    // One object refused, none changed.
    [["measure/records/session-0123456789abcdef.json", "child/forms/0123456789abcdef/bbbbbbbbbbbbbbbb.jpg", "--date=2026-11-01"], /cannot decrease/],
  ]) {
    const result = w.run("time", ...args);
    assert.equal(result.status, 1, args.join(" "));
    assert.match(result.output, reason);
  }
  assert.equal(w.calls().filter((c) => c[2] === "update").length, 0);
});

test("withdraw rewrites a form with the day its samples were erased, under its own name", () => {
  const name = "child/forms/0123456789abcdef/bbbbbbbbbbbbbbbb.jpg";
  const w = world(structuredClone(forms));
  const result = w.run("withdraw", name, "--erased=2026-11-13");
  assert.equal(result.status, 0, result.output);
  assert.equal(w.objects()[name].customTime, "2026-11-13T00:00:00Z", "earlier than the Custom-Time it had, 2028-11-10");
  assert.equal(w.objects()[`${name}.rewrite`], undefined);
  assert.deepEqual(w.objects()[name].metadata, { withdrawn: "2026-11-13" });
  const flags = ["--custom-time=2026-11-13T00:00:00Z", "--update-custom-metadata=withdrawn=2026-11-13"];
  assert.deepEqual(w.calls(), [
    ["storage", "objects", "describe", `gs://${bucket}/${name}`, "--raw", "--format=json"],
    ["storage", "mv", `gs://${bucket}/${name}`, `gs://${bucket}/${name}.rewrite`, ...flags],
    ["storage", "mv", `gs://${bucket}/${name}.rewrite`, `gs://${bucket}/${name}`, ...flags],
  ]);
  // A form withdrawn already may take another day, though its creation is now the rewrite's.
  assert.equal(w.run("withdraw", name, "--erased=2026-11-12").status, 0);
  assert.equal(w.objects()[name].customTime, "2026-11-12T00:00:00Z");
  for (const [args, reason] of [
    [["eval-set/forms/fedcba9876543210/cccccccccccccccc.pdf", "--erased=2026-11-13"], /is no form of a measurement or of a parent/],
    // The form arrived 2026-11-01: its samples were not erased before.
    [["measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf", "--erased=2026-10-20"], /arrived on 2026-11-01, after 2026-10-20: check the day/],
  ]) {
    const refused = w.run("withdraw", ...args);
    assert.equal(refused.status, 1, args.join(" "));
    assert.match(refused.output, reason);
  }

  // A move back that fails names where the form lies and how to finish.
  const broken = world(structuredClone(forms));
  const state = path.join(broken.dir, "state.json");
  fs.writeFileSync(state, JSON.stringify({ ...JSON.parse(fs.readFileSync(state, "utf8")), failMove: name }));
  const failed = broken.run("withdraw", name, "--erased=2026-11-13");
  assert.equal(failed.status, 1);
  assert.match(failed.output, new RegExp(`the form lies at gs://${bucket}/${name}\\.rewrite, with its Custom-Time; move it back: gcloud storage mv`));
  assert.equal(broken.objects()[`${name}.rewrite`].customTime, "2026-11-13T00:00:00Z");
});

test("contribute moves a volunteer's form with its record, each to its own name", () => {
  const w = world(structuredClone(forms));
  const result = w.run("contribute", "fedcba9876543210");
  assert.equal(result.status, 0, result.output);
  const names = Object.keys(w.objects());
  assert.ok(names.includes("eval-set/contributed-forms/fedcba9876543210/cccccccccccccccc.pdf"));
  assert.ok(names.includes("eval-set/contributed-forms/fedcba9876543210/record.json"));
  assert.ok(!names.some((n) => n.startsWith("eval-set/forms/")));
  assert.match(w.run("contribute", "fedcba9876543210").output, /there is nothing under eval-set\/forms\/fedcba9876543210\//);
  assert.match(w.run("contribute", "../x").output, /a session is 16 hex characters/);
});

test("untimed lists the forms, records and reports with no Custom-Time, which no rule erases", () => {
  const w = world(structuredClone(forms));
  const result = w.run("untimed");
  assert.equal(result.status, 0, result.output);
  assert.deepEqual(result.stdout.trim().split("\n").sort(), ["child/reports/run-1.json", "measure/forms/0123456789abcdef/aaaaaaaaaaaaaaaa.pdf", "measure/records/session-0123456789abcdef.json"]);
  const lists = w.calls().filter((c) => c[2] === "list").map((c) => c[3]);
  assert.deepEqual(lists, ["measure", "child"].flatMap((p) => ["forms", "records", "reports"].map((k) => `gs://${bucket}/${p}/${k}/**`)), "only the prefixes no other rule erases");
  const empty = world({}).run("untimed");
  assert.equal(empty.status, 0, empty.output);
  assert.match(empty.stdout, /every form, record and report has its Custom-Time/);
});
