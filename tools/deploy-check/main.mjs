// deploy-check: the checks of the deployment's list that CI runs on a pull request (R05, R14), in
// check.mjs.
//
//   node tools/deploy-check/main.mjs [--base <ref>] [<deploy dir>]
//
// <deploy dir> is deploy/ by default, and --base names the commit whose list api's tag is held
// to, the main a pull request merges into.

import path from "node:path";
import { ROOT, Refusal, run } from "./check.mjs";

const USAGE = "usage: deploy-check [--base <ref>] [<deploy dir>]";

async function main(argv) {
  let base = null;
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--base") {
      base = argv[++i];
      if (!base) throw new Refusal(USAGE);
    } else {
      rest.push(argv[i]);
    }
  }
  if (rest.length > 1) throw new Refusal(USAGE);
  const { lines, refusals } = await run(path.resolve(rest[0] ?? path.join(ROOT, "deploy")), base);
  for (const line of lines) console.log(line.startsWith("deploy-check:") ? line : `deploy-check: ${line}`);
  if (refusals.length) {
    for (const refusal of refusals) console.error(`deploy-check: ${refusal}`);
    process.exit(1);
  }
}

main(process.argv.slice(2)).catch((error) => {
  console.error(error instanceof Refusal ? `deploy-check: ${error.message}` : error);
  process.exit(1);
});
