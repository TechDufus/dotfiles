#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
extension_path="$repo_root/roles/omp/files/extensions/commit-ui.ts"

bun --check "$extension_path"

bun - "$extension_path" <<'TS'
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const extensionPath = process.argv[2];
const mod = await import(pathToFileURL(extensionPath).href);
const calls = [];
const actions = [];
const api = {
  zod: await import("zod/v4"),
  setLabel: (...args) => calls.push(["label", ...args]),
  registerTool: (...args) => calls.push(["tool", ...args]),
  registerCommand: (...args) => calls.push(["command", ...args]),
  on: (...args) => calls.push(["event", ...args]),
  getActiveTools: () => ["read", "bash"],
  setActiveTools: async tools => actions.push(["setActiveTools", tools]),
  sendMessage: (message, options) => actions.push(["sendMessage", message, options]),
};

mod.default(api);

const command = calls.find(call => call[0] === "command" && call[1] === "commit")?.[2];
if (!command) throw new Error("commit command was not registered");
if (typeof command.handler !== "function") throw new Error("commit command missing handler");

const promptHome = await mkdtemp(join(tmpdir(), "omp-commit-ui-home-"));
const originalHome = process.env.HOME;
try {
  await mkdir(join(promptHome, ".omp", "agent", "skills", "commit"), { recursive: true });
  await writeFile(join(promptHome, ".omp", "agent", "skills", "commit", "SKILL.md"), "HOME_SKILL_SENTINEL: deployed skill text\n");
  process.env.HOME = promptHome;
  await command.handler("--dry-run --push --accept-risk --model test-model quoted context", {
    isIdle: () => true,
    waitForIdle: async () => {},
    ui: { notify: (...args) => actions.push(["notify", ...args]) },
  });
} finally {
  if (originalHome === undefined) {
    delete process.env.HOME;
  } else {
    process.env.HOME = originalHome;
  }
  await rm(promptHome, { recursive: true, force: true });
}
const setActiveTools = actions.find(action => action[0] === "setActiveTools");
if (!setActiveTools || setActiveTools[1][0] !== "omp_commit") {
  throw new Error(`commit command did not isolate active tools: ${JSON.stringify(actions)}`);
}
const sentMessage = actions.find(action => action[0] === "sendMessage");
if (!sentMessage) throw new Error("commit command did not send a hidden tool prompt");
if (sentMessage[1].display !== false) throw new Error("commit command prompt should be hidden");
if (sentMessage[2].deliverAs !== "nextTurn") throw new Error("commit command should deliver hidden prompt as next turn");
for (const expected of ["omp_commit", "existing conversation context", "nested omp process", "test-model", "HOME_SKILL_SENTINEL"]) {
  if (!sentMessage[1].content.includes(expected)) throw new Error(`commit prompt missing ${expected}`);
}

const tool = calls.find(call => call[0] === "tool" && call[1]?.name === "omp_commit")?.[1];
if (!tool) throw new Error("omp_commit tool was not registered");
if (tool.defaultInactive !== true) throw new Error("omp_commit should be default-inactive");
if (typeof tool.renderCall !== "function") throw new Error("omp_commit missing renderCall");
if (typeof tool.renderResult !== "function") throw new Error("omp_commit missing renderResult");

const theme = {
  fg: (_color, value) => value,
  bold: value => `**${value}**`,
  tree: { branch: "├─", last: "└─", vertical: "│" },
};
const callComponent = tool.renderCall(
  {
    dryRun: true,
    files: ["included.txt"],
    commitMessage: "chore(test): update included fixture",
    rationale: "test context",
  },
  {},
  theme,
);
const callRendered = callComponent.render(120).join("\n");
for (const expected of ["Commit preview", "1 file", "chore(test): update included fixture", "test context"]) {
  if (!callRendered.includes(expected)) throw new Error(`call render missing ${expected}: ${callRendered}`);
}

const resultComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "Reviewing selected diff" }],
    details: {
      id: "commit-test",
      status: "running",
      phase: "Reviewing selected diff",
      startedAt: Date.now(),
      steps: [{ label: "Reviewing selected diff", status: "running", startedAt: Date.now() }],
      toolCount: 2,
      failedToolCount: 0,
      dryRun: true,
      push: false,
      acceptRisk: false,
      commitMessage: "chore(test): update included fixture",
      selectedFiles: ["included.txt"],
      ignoredFiles: ["unrelated.txt"],
      verificationCount: 1,
      warnings: [],
    },
  },
  { expanded: false, isPartial: true, spinnerFrame: 0 },
  theme,
);
if (!resultComponent) throw new Error("renderResult returned no component");
const resultRendered = resultComponent.render(120).join("\n");
for (const expected of ["Commit preview", "Reviewing selected diff", "Internal actions", "included.txt", "unrelated.txt"]) {
  if (!resultRendered.includes(expected)) throw new Error(`result render missing ${expected}: ${resultRendered}`);
}

async function run(cwd, command, args) {
  const child = Bun.spawn({ cmd: [command, ...args], cwd, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  if (exitCode !== 0) throw new Error(`${command} ${args.join(" ")} failed\n${stderr || stdout}`);
  return { stdout, stderr };
}
const git = (cwd, args) => run(cwd, "git", args);

const tmp = await mkdtemp(join(tmpdir(), "omp-commit-ui-test-"));
try {
  await git(tmp, ["init"]);
  await git(tmp, ["config", "user.email", "commit-ui-test@example.invalid"]);
  await git(tmp, ["config", "user.name", "Commit UI Test"]);
  await writeFile(join(tmp, "included.txt"), "old\n");
  await git(tmp, ["add", "included.txt"]);
  await git(tmp, ["commit", "-m", "chore(test): initial fixture"]);

  await writeFile(join(tmp, "included.txt"), "new\n");
  await writeFile(join(tmp, "unrelated.txt"), "leave me alone\n");

  const updates = [];
  const result = await tool.execute(
    "commit-test",
    {
      files: ["included.txt"],
      commitMessage: "chore(test): update included fixture",
      rationale: "The current session changed the included fixture only.",
      verification: [{ command: "git", args: ["diff", "--check", "--", "included.txt"], description: "diff check", required: true }],
      dryRun: false,
      push: false,
      acceptRisk: false,
    },
    undefined,
    update => updates.push(update),
    { cwd: tmp },
  );
  if (result.isError) throw new Error(`commit execution failed: ${JSON.stringify(result)}`);
  if (updates.length === 0) throw new Error("tool execution did not emit live updates");
  if (!result.content[0].text.includes("Commit created")) throw new Error(`commit result missing success text: ${JSON.stringify(result)}`);
  if (result.details.selectedFiles.join(",") !== "included.txt") throw new Error(`selected files not tracked: ${JSON.stringify(result.details)}`);
  if (!result.details.ignoredFiles.includes("unrelated.txt")) throw new Error(`unrelated file not preserved in details: ${JSON.stringify(result.details)}`);

  const committed = (await git(tmp, ["diff", "--name-only", "HEAD^", "HEAD"])).stdout.trim();
  if (committed !== "included.txt") throw new Error(`unexpected committed files: ${committed}`);
  const status = (await git(tmp, ["status", "--porcelain"])).stdout;
  if (!status.includes("?? unrelated.txt")) throw new Error(`unrelated file was not left untouched: ${status}`);

  await writeFile(join(tmp, "secret.txt"), "api_key = \"" + "a".repeat(12) + "\"\n");
  const blocked = await tool.execute(
    "commit-secret-test",
    {
      files: ["secret.txt"],
      commitMessage: "chore(test): add blocked secret fixture",
      rationale: "Exercise secret blocking.",
      verification: [{ command: "git", args: ["diff", "--check", "--", "secret.txt"], description: "diff check", required: true }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (!blocked.isError || !blocked.content[0].text.includes("Potential generic secret assignment")) {
    throw new Error(`secret scan did not block generated fixture; result ${JSON.stringify(blocked)}`);
  }
} finally {
  await rm(tmp, { recursive: true, force: true });
}
TS
