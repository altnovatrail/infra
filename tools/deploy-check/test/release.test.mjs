// The check of a release's files on a real release of api, v0.1.5, read from GitHub and verified
// by spec's release-verify against Sigstore: its binary and Dockerfile pass, of the sha256 its
// SHA256SUMS names, and a copy with one byte changed, beside the same bundle, is refused. It needs
// the network, and when Sigstore or GitHub cannot be read it fails, as the check of a real list
// would (R77 spec). Run by `just deploy-check-release-test`.

import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { Refusal, releaseFile, verify } from "../check.mjs";

const TAG = "v0.1.5";
const BINARY = `api_${TAG}_linux_amd64`;

// What SHA256SUMS of the release names each file, read from the release itself.
async function sums() {
  const response = await fetch(`https://github.com/altnovatrail/api/releases/download/${TAG}/SHA256SUMS`);
  assert.ok(response.ok, `SHA256SUMS of api ${TAG}: ${response.status}`);
  const named = new Map();
  for (const line of (await response.text()).split("\n")) {
    const match = line.match(/^([0-9a-f]{64}) [ *]?(.+)$/);
    if (match) named.set(match[2], match[1]);
  }
  return named;
}

test(`api ${TAG}: the binary and the Dockerfile are verified, of the sha256 named, and a changed byte is refused`, async () => {
  delete process.env.DEPLOY_CHECK_RELEASES;
  delete process.env.DEPLOY_CHECK_VERIFY;
  const named = await sums();
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-check-release-"));
  try {
    const binary = await releaseFile("api", TAG, BINARY, named.get(BINARY), work);
    const dockerfile = await releaseFile("api", TAG, "Dockerfile", named.get("Dockerfile"), work);
    assert.ok(fs.statSync(binary).size > 0 && fs.statSync(dockerfile).size > 0);

    await assert.rejects(releaseFile("api", TAG, "Dockerfile", "0".repeat(64), fs.mkdtempSync(path.join(work, "again-"))), (error) => {
      assert.ok(error instanceof Refusal);
      assert.match(error.message, /Dockerfile of api v0\.1\.5 has sha256 [0-9a-f]{64}, and the list names 0{64}/);
      return true;
    });

    const changed = path.join(fs.mkdtempSync(path.join(work, "changed-")), "Dockerfile");
    const bytes = fs.readFileSync(dockerfile);
    bytes[0] ^= 1;
    fs.writeFileSync(changed, bytes);
    fs.copyFileSync(`${dockerfile}.sigstore.json`, `${changed}.sigstore.json`);
    assert.throws(() => verify("api", TAG, changed), (error) => {
      assert.ok(error instanceof Refusal);
      assert.match(error.message, /release-verify refused Dockerfile of api v0\.1\.5/);
      return true;
    });

    await assert.rejects(releaseFile("api", TAG, `api_${TAG}_linux_riscv64`, "0".repeat(64), work), /the release v0\.1\.5 of api holds no api_v0\.1\.5_linux_riscv64/);
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
});
