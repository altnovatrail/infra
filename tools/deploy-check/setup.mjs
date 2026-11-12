// The files of a copy's setup — what bootstrap.sh prints into tofu/ci.env, and the values of
// tofu/production.auto.tfvars — as more than one tool reads them: the deployment's target
// (tools/deploy/target.mjs), which runs in steps of the workflow Deploy that install no package, and
// the pull request's check of the list (check.mjs). So this file imports nothing (R13, R14).

// The provider of the federated pool, as GCP_WORKLOAD_IDENTITY_PROVIDER names it: the project is
// named by its number, the pattern's one group, which is how api's service's address names it too
// (the output api_origin; R05).
export const PROVIDER = /^projects\/([0-9]+)\/locations\/global\/workloadIdentityPools\/[a-z0-9-]+\/providers\/[a-z0-9-]+$/;

// The lines KEY=value of a file of tofu/ci.env's form, each trimmed, with blank lines and comments
// left out: the values, and the first line that is not one KEY=value of its own, or null, for the
// reader to refuse in its own words.
export function envValues(text) {
  const values = {};
  for (const line of text.split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#"))) {
    const found = /^([A-Z_]+)=(.*)$/.exec(line);
    if (!found || Object.hasOwn(values, found[1])) return { values, wrong: line };
    values[found[1]] = found[2];
  }
  return { values, wrong: null };
}

// What the line `<name> = <value>` of a file of values gives the variable, the text after "="
// trimmed, or null: line by line, with no regular expression over the whole text, which would
// backtrack (S8786). The line starts at the name, as tofu fmt writes a variable's line; an indented
// one is a key inside the value of another.
export function tfvarsValue(lines, name) {
  for (const line of lines ?? []) {
    const at = line.indexOf("=");
    if (at > 0 && line.slice(0, at).trimEnd() === name) return line.slice(at + 1).trim();
  }
  return null;
}
