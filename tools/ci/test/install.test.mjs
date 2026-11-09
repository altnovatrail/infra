// tools/ci/install.sh against stand-ins for curl and docker, ahead on PATH, and archives made here:
// no network. curl hands out the file of the URL's last part from a folder; docker says the engine
// version it is told. A Dockerfile and a versions file name the archives' own sums, or a wrong one.
// Run by `just tools-install-test`.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "install.sh");
const arch = os.arch() === "arm64" ? { upper: "ARM64", arch: "arm64", gnu: "aarch64", node: "arm64", gcloud: "arm" } : { upper: "AMD64", arch: "amd64", gnu: "x86_64", node: "x64", gcloud: "x86_64" };

const made = [];
after(() => {
  for (const dir of made) fs.rmSync(dir, { recursive: true, force: true });
});

const sum = (file) => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const tar = (out, cwd, ...entries) => assert.equal(spawnSync("/usr/bin/tar", ["-czf", out, "-C", cwd, ...entries]).status, 0);

function world({ gcloudVersion = "592.0.0", engine = "28.0.4", change = {}, drop = null } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "install-test-"));
  made.push(dir);
  const served = path.join(dir, "served");
  const build = path.join(dir, "build");
  fs.mkdirSync(served);
  const program = (file, text) => {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, `#!/bin/sh\necho ${text}\n`, { mode: 0o755 });
  };

  program(path.join(build, "tofu"), "tofu");
  tar(path.join(served, "tofu_1.13.9_linux_" + arch.arch + ".tar.gz"), build, "tofu");
  program(path.join(build, "just"), "just");
  tar(path.join(served, `just-1.58.0-${arch.gnu}-unknown-linux-musl.tar.gz`), build, "just");
  program(path.join(build, "node-v24.21.0", "bin", "node"), "node");
  tar(path.join(served, `node-v24.21.0-linux-${arch.node}.tar.gz`), build, "node-v24.21.0");
  program(path.join(build, "google-cloud-sdk", "bin", "gcloud"), "gcloud");
  fs.writeFileSync(path.join(build, "google-cloud-sdk", "VERSION"), gcloudVersion);
  tar(path.join(served, `google-cloud-cli-592.0.0-linux-${arch.gcloud}.tar.gz`), build, "google-cloud-sdk");
  program(path.join(served, `jq-linux-${arch.arch}`), "jq");
  program(path.join(served, `buildx-v0.38.2.linux-${arch.arch}`), "buildx");

  const of = (name) => sum(path.join(served, name));
  const sums = {
    OPENTOFU: of(`tofu_1.13.9_linux_${arch.arch}.tar.gz`),
    JUST: of(`just-1.58.0-${arch.gnu}-unknown-linux-musl.tar.gz`),
    NODE: of(`node-v24.21.0-linux-${arch.node}.tar.gz`),
    GCLOUD: of(`google-cloud-cli-592.0.0-linux-${arch.gcloud}.tar.gz`),
    JQ: of(`jq-linux-${arch.arch}`),
    BUILDX: of(`buildx-v0.38.2.linux-${arch.arch}`),
    ...change,
  };
  const dockerfile = path.join(dir, "Dockerfile");
  fs.writeFileSync(
    dockerfile,
    [
      `ARG OPENTOFU_VERSION=${sums.OPENTOFU_VERSION ?? "1.13.9"}`,
      "ARG JUST_VERSION=1.58.0",
      "ARG NODE_VERSION=24.21.0",
      `ARG OPENTOFU_SHA256_${arch.upper}=${sums.OPENTOFU}`,
      `ARG JUST_SHA256_${arch.upper}=${sums.JUST}`,
      `ARG NODE_SHA256_${arch.upper}=${sums.NODE}`,
    ]
      .filter((line) => !drop || !line.startsWith(`ARG ${drop}`))
      .join("\n") + "\n",
  );
  const versions = path.join(dir, "versions.env");
  fs.writeFileSync(
    versions,
    [
      "GCLOUD_VERSION=592.0.0",
      `GCLOUD_SHA256_${arch.upper}=${sums.GCLOUD}`,
      "JQ_VERSION=1.8.2",
      `JQ_SHA256_${arch.upper}=${sums.JQ}`,
      "BUILDX_VERSION=0.38.2",
      `BUILDX_SHA256_${arch.upper}=${sums.BUILDX}`,
      "DOCKER_ENGINE_VERSION=28.0.4",
    ].join("\n") + "\n",
  );

  // curl: the file named by the last part of the URL, into -o; docker: the engine's version.
  const bin = path.join(dir, "stub-bin");
  fs.mkdirSync(bin);
  fs.writeFileSync(
    path.join(bin, "curl"),
    `#!/bin/sh\nout=""; url=""\nwhile [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; --proto|--proto-redir|--retry) shift 2;; -*) shift;; *) url="$1"; shift;; esac; done\necho "$url" >> "${dir}/fetched"\ncp "${served}/$(basename "$url")" "$out"\n`,
    { mode: 0o755 },
  );
  fs.writeFileSync(path.join(bin, "docker"), `#!/bin/sh\necho ${engine}\n`, { mode: 0o755 });

  return {
    dir,
    run(...tools) {
      const target = path.join(dir, "tools");
      const githubPath = path.join(dir, "github-path");
      const r = spawnSync(script, [target, ...tools], {
        encoding: "utf8",
        env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, INFRA_DOCKERFILE: dockerfile, INFRA_TOOL_VERSIONS: versions, DOCKER_CONFIG: path.join(dir, "docker"), GITHUB_PATH: githubPath },
      });
      return { ...r, target, githubPath, output: r.stdout + r.stderr };
    },
  };
}

test("every tool lands where its job finds it, and its folder goes on the job's PATH", () => {
  const w = world();
  const r = w.run("tofu", "just", "node", "gcloud", "jq", "buildx", "docker");
  assert.equal(r.status, 0, r.output);
  for (const program of ["bin/tofu", "bin/just", "bin/jq", "node/bin/node", "google-cloud-sdk/bin/gcloud"]) {
    assert.ok(fs.statSync(path.join(r.target, program)).mode & 0o111, program);
  }
  assert.ok(fs.statSync(path.join(w.dir, "docker", "cli-plugins", "docker-buildx")).mode & 0o111);
  assert.deepEqual(fs.readFileSync(r.githubPath, "utf8").trim().split("\n"), [path.join(r.target, "bin"), path.join(r.target, "node", "bin"), path.join(r.target, "google-cloud-sdk", "bin")]);
  assert.match(r.stderr, /the Docker engine 28\.0\.4, the runner's/);
  const fetched = fs.readFileSync(path.join(w.dir, "fetched"), "utf8");
  assert.match(fetched, /^https:\/\/storage\.googleapis\.com\/cloud-sdk-release\/google-cloud-cli-592\.0\.0-linux-/m);
  assert.match(fetched, /^https:\/\/github\.com\/opentofu\/opentofu\/releases\/download\/v1\.13\.9\//m);
});

test("refusals", async (t) => {
  const cases = [
    ["an archive of another sum, before anything of it is unpacked", { change: { OPENTOFU: "0".repeat(64) } }, ["tofu"], /tofu\.tar\.gz is not of the sha256 written down, 0{64}: nothing of it is unpacked/, "bin/tofu"],
    ["a sum that is not one", { change: { JQ: "latest" } }, ["jq"], /the sha256 of jq is not one: latest/, "bin/jq"],
    ["a sum the Dockerfile does not name, by the ARG it misses", { drop: "OPENTOFU_SHA256" }, ["tofu"], new RegExp(`names no single ARG OPENTOFU_SHA256_${arch.upper}`), "bin/tofu"],
    ["a version that is not exact", { change: { OPENTOFU_VERSION: "latest" } }, ["tofu"], /OpenTofu is latest, not an exact version/, "bin/tofu"],
    ["a Google Cloud CLI whose archive holds another version", { gcloudVersion: "591.0.0" }, ["gcloud"], /holds another version than 592\.0\.0/, null],
    ["a Docker engine of another version", { engine: "29.0.0" }, ["docker"], /the runner's Docker engine is 29\.0\.0, and tools\/ci\/versions\.env names 28\.0\.4/, null],
    ["a tool it does not know", {}, ["helm"], /no tool helm/, null],
  ];
  for (const [name, setup, tools, message, absent] of cases) {
    await t.test(name, () => {
      const r = world(setup).run(...tools);
      assert.notEqual(r.status, 0, r.output);
      assert.match(r.stderr, message);
      if (absent) assert.ok(!fs.existsSync(path.join(r.target, absent)), `${absent} is not there`);
    });
  }
});
