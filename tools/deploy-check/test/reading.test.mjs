// The reading of /deployment.json against spec's vectors of reading at the tag of the submodule:
// each case read at its origin gives exactly what the vector says (section 7 of spec's
// deployment/README.md). Run by `just deploy-check-test`.

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { parse } from "yaml";
import { ROOT, specDeployment } from "../check.mjs";
import { readingOf, RULES } from "../reading.mjs";

const DEPLOYMENT = path.join(ROOT, "spec", "deployment");
const VECTORS = path.join(DEPLOYMENT, "vectors", "reading");

// spec's schema compiled as the checks compile it, so that the vectors hold what they run.
const validator = () => specDeployment().validate;

const vectors = fs
  .readdirSync(VECTORS)
  .filter((name) => name.endsWith(".yaml"))
  .sort((a, b) => a.localeCompare(b));

test("spec's vectors of reading are there, and refuse by the schema and by every rule", () => {
  assert.ok(vectors.length > 0, `no vector under ${VECTORS}`);
  const steps = new Set();
  for (const name of vectors) {
    for (const c of parse(fs.readFileSync(path.join(VECTORS, name), "utf8")).cases) steps.add(c.refused_by ?? "accepted");
  }
  assert.deepEqual([...steps].sort((a, b) => a.localeCompare(b)), ["accepted", "schema", ...RULES].sort((a, b) => a.localeCompare(b)));
});

for (const name of vectors) {
  test(`spec's vector ${name}: each case reads as it says`, () => {
    const validate = validator();
    const { cases } = parse(fs.readFileSync(path.join(VECTORS, name), "utf8"));
    for (const [i, c] of cases.entries()) {
      const want = c.refused_by ? { refused_by: c.refused_by, fields: c.fields } : {};
      assert.deepEqual(readingOf(validate, c.origin, c.file), want, `${name}, case ${i + 1} at ${c.origin}`);
    }
  });
}

test("an origin not written as the URL Standard serializes it is no case of reading", () => {
  assert.throws(() => readingOf(validator(), "https://app.example.org/", {}), /is not an origin as the URL Standard serializes it/);
});
