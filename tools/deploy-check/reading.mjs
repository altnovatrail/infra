// The reading of a deployment configuration, /deployment.json, as section 5 of spec's
// deployment/README.md lays it out: the schema first, then the rules in the order of the text's
// table, and the first step that finds something wrong refuses the file and names every field it
// refuses, by its path. The rollout is a reader, as app is: it accepts the file so before it writes
// it (R85 spec). spec's vectors of reading hold this to the text (test/reading.test.mjs).

export const RULES = ["deployment.api-origin", "deployment.loopback"];

// The loopback hosts, as section 5 defines them: these three, written so, and nothing else — not
// another address of 127.0.0.0/8, nor a name under localhost.
export const LOOPBACK = new Set(["127.0.0.1", "localhost", "[::1]"]);

// What a reader gives file read at origin, with validate the compiled schema of the file: {} when it
// accepts it, or { refused_by, fields }, the paths in the order of code units. origin is where app
// is open, as the URL Standard serializes an origin; anything else is no case of reading.
export function readingOf(validate, origin, file) {
  if (originOf(origin) !== origin) throw new Error(`${JSON.stringify(origin)} is not an origin as the URL Standard serializes it`);
  if (!validate(file)) return { refused_by: "schema", fields: fieldsOf(validate.errors) };
  const rule = brokenRule(origin, file.api);
  return rule ? { refused_by: rule, fields: ["api"] } : {};
}

function brokenRule(origin, api) {
  if (originOf(api) !== api) return "deployment.api-origin";
  if (api.startsWith("http:") && !LOOPBACK.has(new URL(origin).hostname)) return "deployment.loopback";
  return null;
}

// The origin of a URL as the URL Standard serializes it, or null when it is no URL.
export function originOf(url) {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}

// The paths of the fields that ajv's errors name, each once: a missing or unknown field at the path
// it would have, any other error at the place it stands.
export function fieldsOf(errors) {
  const paths = new Set();
  for (const error of errors) {
    const names = error.instancePath
      .split("/")
      .slice(1)
      .map((part) => part.replaceAll("~1", "/").replaceAll("~0", "~"));
    if (error.keyword === "required") names.push(error.params.missingProperty);
    else if (error.keyword === "unevaluatedProperties") names.push(error.params.unevaluatedProperty);
    paths.add(names.join("."));
  }
  return [...paths].sort(byCodeUnits);
}

// Strings in the order of their UTF-16 code units, as section 5 orders the paths.
function byCodeUnits(a, b) {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}
