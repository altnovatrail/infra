// fetch: one file of a release, downloaded with its bundle from the release on GitHub into <dir>,
// of the sha256 the list names and accepted by spec's release-verify, as check.mjs takes it. The
// deployment runs it again before it builds an image, so that what reaches production is the file
// verified (R05, R15). Prints the file's path; a refusal is an error.
//
//   node tools/deploy-check/fetch.mjs <repository> <tag> <file> <sha256> <dir>

import fs from "node:fs";
import path from "node:path";
import { Refusal, releaseFile } from "./check.mjs";

const USAGE = "usage: fetch <repository> <tag> <file> <sha256> <dir>";

async function main(argv) {
  if (argv.length !== 5) throw new Refusal(USAGE);
  const [repository, tag, file, sha256, dir] = argv;
  if (!/^[0-9a-f]{64}$/.test(sha256)) throw new Refusal(`${sha256} is not a sha256`);
  fs.mkdirSync(dir, { recursive: true });
  console.log(await releaseFile(repository, tag, file, sha256, path.resolve(dir)));
}

main(process.argv.slice(2)).catch((error) => {
  console.error(error instanceof Refusal ? `fetch: ${error.message}` : error);
  process.exit(1);
});
