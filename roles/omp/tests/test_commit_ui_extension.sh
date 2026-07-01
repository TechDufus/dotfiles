#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
extension_path="$repo_root/roles/omp/files/extensions/commit-ui.ts"

bun --check "$extension_path"

bun - "$extension_path" <<'TS'
import { access, chmod, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const extensionPath = process.argv[2];
const mod = await import(pathToFileURL(extensionPath).href);

function schema() {
  let proxy;
  const fn = () => proxy;
  proxy = new Proxy(fn, {
    get(_target, prop) {
      if (prop === "parse") return value => value;
      if (prop === "safeParse") return value => ({ success: true, data: value });
      if (prop === "shape") return {};
      return () => proxy;
    },
    apply() {
      return proxy;
    },
  });
  return proxy;
}

const zod = new Proxy({}, { get: () => () => schema() });
const calls = [];
const actions = [];
let activeTools = ["read", "bash"];
const api = {
  zod,
  setLabel: (...args) => calls.push(["label", ...args]),
  registerTool: (...args) => calls.push(["tool", ...args]),
  registerCommand: (...args) => calls.push(["command", ...args]),
  on: (...args) => calls.push(["event", ...args]),
  getActiveTools: () => [...activeTools],
  setActiveTools: async tools => {
    activeTools = Array.from(tools ?? []);
    actions.push(["setActiveTools", [...activeTools]]);
  },
  sendMessage: (message, options) => actions.push(["sendMessage", message, options]),
};

mod.default(api);

function fail(message) {
  throw new Error(message);
}

function commandFromCall(call) {
  if (!call || call[0] !== "command") return undefined;
  if (call[1] === "commit") return call[2];
  if (call[1]?.name === "commit") return call[1];
  return undefined;
}

function toolFromCall(call) {
  if (!call || call[0] !== "tool") return undefined;
  if (call[1]?.name === "omp_commit") return call[1];
  if (call[2]?.name === "omp_commit") return call[2];
  return undefined;
}

const command = calls.map(commandFromCall).find(Boolean);
if (!command) fail("/commit command was not registered");
if (typeof command.handler !== "function") fail("/commit command missing handler");

const tool = calls.map(toolFromCall).find(Boolean);
if (!tool) fail("omp_commit tool was not registered");
if (tool.defaultInactive !== true) fail("omp_commit should be default-inactive");
for (const method of ["execute", "renderCall", "renderResult"]) {
  if (typeof tool[method] !== "function") fail(`omp_commit missing ${method}`);
}

const eventHandlers = name => calls.filter(call => call[0] === "event" && call[1] === name).map(call => call[2]);
const turnEndHandler = eventHandlers("turn_end").find(handler => typeof handler === "function");
const inputHandler = eventHandlers("input").find(handler => typeof handler === "function");

const themeBase = {
  fg: (_color, value) => String(value),
  bold: value => String(value),
  dim: value => String(value),
  italic: value => String(value),
  tree: { branch: "├─", last: "└─", vertical: "│" },
};
const theme = new Proxy(themeBase, {
  get(target, prop) {
    if (prop in target) return target[prop];
    return value => String(value);
  },
});

function textOf(result) {
  return (result?.content ?? [])
    .map(part => typeof part?.text === "string" ? part.text : "")
    .filter(Boolean)
    .join("\n");
}

function render(component, width, label) {
  if (!component || typeof component.render !== "function") fail(`${label} did not return a renderable component`);
  const lines = component.render(width);
  if (!Array.isArray(lines)) fail(`${label} render did not return lines`);
  for (const line of lines) {
    if (line.length > width) fail(`${label} render exceeded width ${width}: ${lines.join("\n")}`);
  }
  return lines.join("\n");
}

function renderResult(result, width, label, options = {}) {
  return render(tool.renderResult(result, { expanded: false, isPartial: false, spinnerFrame: 1, ...options }, theme), width, label);
}

function assertIncludes(value, expected, label) {
  if (!String(value).includes(expected)) fail(`${label} missing ${expected}: ${value}`);
}

function assertMatches(value, pattern, label) {
  if (!pattern.test(String(value))) fail(`${label} did not match ${pattern}: ${value}`);
}

function assertExcludes(value, unexpected, label) {
  if (String(value).includes(unexpected)) fail(`${label} unexpectedly included ${unexpected}: ${value}`);
}

function assertBoxed(value, label) {
  assertMatches(value, /[┌┏╭╔╒╓]/, `${label} top border`);
  assertMatches(value, /[└┗╰╚╘╙]/, `${label} bottom border`);
}

function assertCompactCallTeaser(value, label) {
  const text = String(value);
  const lines = text.split("\n");
  if (lines.length > 2) fail(`${label} should render as a one or two line teaser: ${value}`);
  for (const pattern of [
    /Waiting for tool call/i,
    /[┌┐└┘┏┓┗┛╭╮╰╯╔╗╚╝╒╕╘╛]/,
    /[│║┃├┝┠└┕┗╟╙]/,
    /[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/,
  ]) {
    if (pattern.test(text)) fail(`${label} used boxed, railed, spinner, or waiting UI ${pattern}: ${value}`);
  }
}

function assertStaticRender(rendered, rerendered, label) {
  if (rendered !== rerendered) fail(`${label} changed between spinner frames: ${JSON.stringify({ rendered, rerendered })}`);
}

function assertNoLegacyUi(value, label) {
  for (const pattern of [/\batomic\b/i, /secret findings/i, /\brisk\b/i]) {
    if (pattern.test(String(value))) fail(`${label} used legacy UI concept ${pattern}: ${value}`);
  }
}

function warningsOf(result) {
  const warnings = [];
  if (Array.isArray(result?.details?.warnings)) warnings.push(...result.details.warnings.map(String));
  for (const commit of result?.details?.commits ?? []) {
    if (Array.isArray(commit?.warnings)) warnings.push(...commit.warnings.map(String));
  }
  return warnings;
}

function selectedFilesOf(result) {
  const files = result?.details?.selectedFiles;
  if (Array.isArray(files)) return files;
  return (result?.details?.commits ?? []).flatMap(commit => commit?.selectedFiles ?? commit?.files ?? []);
}

function ignoredFilesOf(result) {
  const files = result?.details?.ignoredFiles;
  if (Array.isArray(files)) return files;
  return (result?.details?.commits ?? []).flatMap(commit => commit?.ignoredFiles ?? []);
}

function commitsOf(result) {
  return Array.isArray(result?.details?.commits) ? result.details.commits : [];
}

function hashOf(result) {
  return result?.details?.commitHash ?? commitsOf(result).find(commit => commit?.commitHash)?.commitHash;
}

function assertSucceeded(result, label) {
  if (result?.isError) fail(`${label} returned an error: ${JSON.stringify(result)}`);
  if (result?.details?.status && result.details.status !== "succeeded") {
    fail(`${label} did not finish succeeded: ${JSON.stringify(result.details)}`);
  }
}

function assertError(result, pattern, label) {
  if (!result?.isError) fail(`${label} should have failed: ${JSON.stringify(result)}`);
  assertMatches(textOf(result), pattern, label);
}

function assertSameSet(actual, expected, label) {
  const a = [...actual].sort();
  const e = [...expected].sort();
  if (a.length !== e.length || a.some((item, index) => item !== e[index])) {
    fail(`${label} mismatch: ${JSON.stringify({ actual, expected })}`);
  }
}

function parseStatusPaths(raw) {
  const parts = raw.split("\0").filter(Boolean);
  const paths = [];
  for (let index = 0; index < parts.length; index += 1) {
    const entry = parts[index];
    if (entry.length < 4) continue;
    const code = entry.slice(0, 2);
    paths.push(entry.slice(3));
    if ((code.includes("R") || code.includes("C")) && index + 1 < parts.length) index += 1;
  }
  return paths;
}

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function run(cwd, command, args, options = {}) {
  const child = Bun.spawn({ cmd: [command, ...args], cwd, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  if (exitCode !== 0 && !options.allowFailure) fail(`${command} ${args.join(" ")} failed\n${stderr || stdout}`);
  return { stdout, stderr, exitCode };
}
const git = (cwd, args, options) => run(cwd, "git", args, options);

const tempPaths = [];
async function tempDir(prefix) {
  const path = await mkdtemp(join(tmpdir(), prefix));
  tempPaths.push(path);
  return path;
}

async function makeRepo(label) {
  const repo = await tempDir(`omp-commit-ui-${label}-`);
  await git(repo, ["init"]);
  await git(repo, ["config", "user.email", "commit-ui-test@example.invalid"]);
  await git(repo, ["config", "user.name", "Commit UI Test"]);
  await writeFile(join(repo, "base.txt"), "base\n");
  await git(repo, ["add", "base.txt"]);
  await git(repo, ["commit", "-m", "chore(test): initial fixture"]);
  return repo;
}

async function execute(cwd, id, args, updates = []) {
  return await tool.execute(id, args, undefined, update => updates.push(update), { cwd });
}

async function assertCommittedFiles(repo, revisionRange, expected, label) {
  const actual = (await git(repo, ["diff", "--name-only", ...revisionRange])).stdout.trim().split("\n").filter(Boolean);
  assertSameSet(actual, expected, label);
}

const promptHome = await tempDir("omp-commit-ui-home-");
const originalHome = process.env.HOME;
try {
  await mkdir(join(promptHome, ".omp", "agent", "skills", "commit"), { recursive: true });
  await writeFile(join(promptHome, ".omp", "agent", "skills", "commit", "SKILL.md"), "HOME_SKILL_SENTINEL: old commit skill text\n");
  process.env.HOME = promptHome;

  const idleCtx = {
    isIdle: () => true,
    waitForIdle: async () => {},
    ui: { notify: (...args) => actions.push(["notify", ...args]) },
  };

  const commandContext = "Current context: commit the focused test refactor only.";
  await command.handler(`--dry-run --push --split ${commandContext}`, idleCtx);
  const isolated = actions.find(action => action[0] === "setActiveTools");
  if (!isolated || isolated[1].join(",") !== "omp_commit") {
    fail(`commit command did not isolate active tools: ${JSON.stringify(actions)}`);
  }
  const sent = actions.find(action => action[0] === "sendMessage");
  if (!sent) fail("commit command did not send a hidden prompt");
  const prompt = sent[1] ?? {};
  const promptText = String(prompt.content ?? prompt.text ?? "");
  const promptEnvelope = `${promptText}\n${JSON.stringify(prompt.details ?? {})}`;
  if (prompt.display !== false) fail("commit command prompt should be hidden");
  if (sent[2]?.deliverAs !== "nextTurn") fail(`commit command should deliver prompt as next turn: ${JSON.stringify(sent[2])}`);
  assertMatches(promptEnvelope, /omp_commit/, "hidden prompt tool name");
  assertMatches(promptEnvelope, /exactly once|call\s+omp_commit\s+once|one\s+omp_commit\s+call/i, "hidden prompt one tool call");
  assertMatches(promptEnvelope, /current (conversation|session|context)|existing conversation context/i, "hidden prompt current context");
  assertMatches(promptEnvelope, /no other tools|do not (?:call|use) any other tools|do not use other tools|only tool/i, "hidden prompt tool isolation");
  assertIncludes(promptEnvelope, commandContext, "hidden prompt context text");
  if (prompt.details?.dryRun !== true || prompt.details?.push !== true || prompt.details?.multiCommit !== true) {
    fail(`commit command did not parse dry-run/push/split details: ${JSON.stringify(prompt.details)}`);
  }
  for (const forbidden of ["HOME_SKILL_SENTINEL", "verificationEvidence", "acceptRisk", "50 characters", "72 characters", "./scripts/check.sh"]) {
    assertExcludes(promptEnvelope, forbidden, "hidden prompt");
  }

  if (!turnEndHandler) fail("commit command did not register turn_end active-tool restoration");
  actions.length = 0;
  await turnEndHandler();
  const restored = actions.find(action => action[0] === "setActiveTools");
  if (!restored || restored[1].join(",") !== "read,bash") {
    fail(`commit command did not restore previous active tools: ${JSON.stringify(actions)}`);
  }

  if (inputHandler) {
    actions.length = 0;
    const inputResult = await inputHandler(
      { type: "input", text: "draft a commit message for this change", source: "interactive" },
      idleCtx,
    );
    if (inputResult?.handled || actions.length !== 0) {
      fail(`natural-language commit-message discussion should not be required or routed: ${JSON.stringify({ inputResult, actions })}`);
    }
  }
} finally {
  if (originalHome === undefined) delete process.env.HOME;
  else process.env.HOME = originalHome;
}

const singleCommitCall = {
  dryRun: true,
  push: false,
  files: ["roles/omp/tests/test_commit_ui_extension.sh"],
  message: "exercise compact commit card rendering",
  rationale: "current session test coverage",
};
const callRendered = render(tool.renderCall(singleCommitCall, { spinnerFrame: 0 }, theme), 58, "single commit call");
const callRerendered = render(tool.renderCall(singleCommitCall, { spinnerFrame: 7 }, theme), 58, "single commit call rerender");
assertCompactCallTeaser(callRendered, "single commit call");
assertStaticRender(callRendered, callRerendered, "single commit call");
assertIncludes(callRendered, "exercise compact", "single commit call");
assertMatches(callRendered, /test_commit_ui_extension\.sh|1\s+files?/i, "single commit call file summary");
assertNoLegacyUi(callRendered, "single commit call");

const splitCommitCall = {
  dryRun: false,
  push: true,
  commits: [
    { files: ["alpha.txt"], message: "split alpha", rationale: "alpha" },
    { files: ["beta.txt"], commitMessage: "split beta", rationale: "beta" },
  ],
};
const groupedCallRendered = render(tool.renderCall(splitCommitCall, { spinnerFrame: 0 }, theme), 64, "split commit call");
const groupedCallRerendered = render(tool.renderCall(splitCommitCall, { spinnerFrame: 7 }, theme), 64, "split commit call rerender");
assertCompactCallTeaser(groupedCallRendered, "split commit call");
assertStaticRender(groupedCallRendered, groupedCallRerendered, "split commit call");
assertMatches(groupedCallRendered, /2\s+(commits?|split)|split/i, "split commit call rows");
assertMatches(groupedCallRendered, /split alpha|split beta|2\s+commits?/i, "split commit call summary");
assertNoLegacyUi(groupedCallRendered, "split commit call");

const runningResult = {
  content: [{ type: "text", text: "Inspecting working tree" }],
  details: {
    id: "render-running",
    status: "running",
    phase: "Inspecting working tree",
    dryRun: true,
    push: false,
    selectedFiles: ["src/very/long/path/that/should/wrap-cleanly.ts"],
    ignoredFiles: [],
    commits: [{ status: "running", selectedFiles: ["src/very/long/path/that/should/wrap-cleanly.ts"], message: "render running" }],
    warnings: [],
  },
};
const runningRendered = renderResult(runningResult, 54, "running result", { isPartial: true, spinnerFrame: 2 });
const runningRerendered = renderResult(runningResult, 54, "running result rerender", { isPartial: true, spinnerFrame: 3 });
assertBoxed(runningRendered, "running result");
if (runningRendered === runningRerendered) fail(`running result did not animate between spinner frames: ${runningRendered}`);
assertMatches(runningRendered, /[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏●•]|running|progress/i, "running result spinner or rail");
assertNoLegacyUi(runningRendered, "running result");

const completedRendered = renderResult(
  {
    content: [{ type: "text", text: "Commit preview complete." }],
    details: {
      id: "render-complete",
      status: "succeeded",
      phase: "Commit preview complete",
      dryRun: true,
      push: false,
      selectedFiles: ["kept-file-with-a-long-name.txt"],
      ignoredFiles: ["stale-file-that-should-wrap.txt"],
      warnings: ["stale-file-that-should-wrap.txt is not changed and was ignored"],
      commits: [{ status: "succeeded", selectedFiles: ["kept-file-with-a-long-name.txt"], message: "preview compact card" }],
      finalText: "Commit preview complete.",
    },
  },
  54,
  "completed result",
);
assertBoxed(completedRendered, "completed result");
assertMatches(completedRendered, /✓/, "completed result visible success checkmark");
assertMatches(completedRendered, /Commit preview complete|Outcome|succeeded|success/i, "completed result success status");
assertMatches(completedRendered, /stale-file|warnings?|ignored/i, "completed result warnings and ignored files");
assertNoLegacyUi(completedRendered, "completed result");

try {
  const emptyRepo = await makeRepo("empty-");
  const empty = await execute(emptyRepo, "empty-tree", {
    commitMessage: "chore(test): clean tree",
    dryRun: true,
    push: false,
  });
  assertError(empty, /No working tree changes to commit/i, "empty working tree");

  const selectedRepo = await makeRepo("selected-");
  await writeFile(join(selectedRepo, "included.txt"), "include me\n");
  await writeFile(join(selectedRepo, "unrelated.txt"), "leave me alone\n");
  const updates = [];
  const selected = await execute(selectedRepo, "selected-file", {
    files: ["included.txt"],
    commitMessage: "chore(test): update included fixture",
    rationale: "Only the selected file belongs in this commit.",
    dryRun: false,
    push: false,
  }, updates);
  assertSucceeded(selected, "selected-file commit");
  if (updates.length === 0) fail("selected-file commit did not emit live updates");
  if (!hashOf(selected)) fail(`selected-file commit did not record a short hash: ${JSON.stringify(selected.details)}`);
  assertSameSet(selectedFilesOf(selected), ["included.txt"], "selected-file details");
  if (!ignoredFilesOf(selected).includes("unrelated.txt")) fail(`selected-file commit did not report ignored unrelated change: ${JSON.stringify(selected.details)}`);
  await assertCommittedFiles(selectedRepo, ["HEAD^", "HEAD"], ["included.txt"], "selected-file committed files");
  const selectedStatus = (await git(selectedRepo, ["status", "--porcelain"])).stdout;
  assertIncludes(selectedStatus, "?? unrelated.txt", "selected-file preserved unrelated change");
  if (commitsOf(selected)[0]?.status !== "succeeded") fail(`selected-file normalized commit did not succeed: ${JSON.stringify(selected.details)}`);


  const dryRunRepo = await makeRepo("dry-run-");
  await writeFile(join(dryRunRepo, "base.txt"), "base changed\n");
  await writeFile(join(dryRunRepo, "new-a.txt"), "a\n");
  await writeFile(join(dryRunRepo, "new-b.txt"), "b\n");
  const expectedDryRunPaths = parseStatusPaths((await git(dryRunRepo, ["status", "--porcelain=v1", "-z", "--untracked-files=all"])).stdout);
  const dryRunHead = (await git(dryRunRepo, ["rev-parse", "HEAD"])).stdout.trim();
  const dryRun = await execute(dryRunRepo, "status-derived-dry-run", {
    files: [],
    commitMessage: "chore(test): preview status-derived files",
    dryRun: true,
    push: false,
  });
  assertSucceeded(dryRun, "status-derived dry-run");
  if (dryRun.details?.dryRun !== true) fail(`status-derived result lost dryRun flag: ${JSON.stringify(dryRun.details)}`);
  assertSameSet(selectedFilesOf(dryRun), expectedDryRunPaths, "status-derived dry-run selection");
  const dryRunHeadAfter = (await git(dryRunRepo, ["rev-parse", "HEAD"])).stdout.trim();
  if (dryRunHeadAfter !== dryRunHead) fail("status-derived dry-run created a commit");

  const staleRepo = await makeRepo("stale-");
  await writeFile(join(staleRepo, "changed.txt"), "changed\n");
  const stale = await execute(staleRepo, "stale-path", {
    files: ["changed.txt", "stale.txt"],
    commitMessage: "chore(test): preview stale path warning",
    dryRun: true,
    push: false,
  });
  assertSucceeded(stale, "stale path preview");
  assertSameSet(selectedFilesOf(stale), ["changed.txt"], "stale path selection");
  if (!ignoredFilesOf(stale).includes("stale.txt")) fail(`stale path was not ignored: ${JSON.stringify(stale.details)}`);
  if (!warningsOf(stale).some(warning => /stale\.txt/i.test(warning))) fail(`stale path warning missing: ${JSON.stringify(warningsOf(stale))}`);

  const renameRepo = await makeRepo("rename-");
  await writeFile(join(renameRepo, "rename-source.txt"), "rename me\n");
  await git(renameRepo, ["add", "rename-source.txt"]);
  await git(renameRepo, ["commit", "-m", "chore(test): add rename source"]);
  await git(renameRepo, ["mv", "rename-source.txt", "rename-destination.txt"]);
  const renameStatusPaths = parseStatusPaths((await git(renameRepo, ["status", "--porcelain=v1", "-z", "--untracked-files=all"])).stdout);
  assertSameSet(renameStatusPaths, ["rename-destination.txt"], "rename porcelain status destination");
  const renameResult = await execute(renameRepo, "rename-destination-selection", {
    files: ["rename-destination.txt"],
    commitMessage: "chore(test): commit rename destination",
    dryRun: false,
    push: false,
  });
  assertSucceeded(renameResult, "rename destination commit");
  assertSameSet(selectedFilesOf(renameResult), ["rename-destination.txt"], "rename destination selection");
  if (selectedFilesOf(renameResult).includes("rename-source.txt")) {
    fail(`rename source path should not be selected: ${JSON.stringify(renameResult.details)}`);
  }
  const renameNameStatus = (await git(renameRepo, ["diff", "--name-status", "HEAD^", "HEAD"])).stdout.trim();
  if (!/^R\d*\s+rename-source\.txt\s+rename-destination\.txt$/m.test(renameNameStatus)) {
    fail(`rename destination commit did not preserve the rename: ${renameNameStatus}`);
  }
  const renameFinalStatus = (await git(renameRepo, ["status", "--porcelain"])).stdout.trim();
  if (renameFinalStatus) fail(`rename destination commit left working tree changes: ${renameFinalStatus}`);

  const splitRepo = await makeRepo("split-");
  await writeFile(join(splitRepo, "alpha.txt"), "alpha\n");
  await writeFile(join(splitRepo, "beta.txt"), "beta\n");
  const split = await execute(splitRepo, "split-execution", {
    commits: [
      { files: ["alpha.txt"], message: "chore(test): split alpha fixture", rationale: "alpha only" },
      { files: ["beta.txt"], commitMessage: "chore(test): split beta fixture", rationale: "beta only" },
    ],
    dryRun: false,
    push: false,
  });
  assertSucceeded(split, "split execution");
  if (commitsOf(split).length !== 2) fail(`split execution did not retain two normalized commits: ${JSON.stringify(split.details)}`);
  if (!commitsOf(split).every(commit => commit.commitHash && commit.status === "succeeded")) {
    fail(`split execution did not record successful hashes: ${JSON.stringify(split.details)}`);
  }
  await assertCommittedFiles(splitRepo, ["HEAD~2", "HEAD^"], ["alpha.txt"], "first split commit");
  await assertCommittedFiles(splitRepo, ["HEAD^", "HEAD"], ["beta.txt"], "second split commit");

  const splitEmptyRepo = await makeRepo("split-empty-");
  await writeFile(join(splitEmptyRepo, "split-empty.txt"), "split empty\n");
  const splitEmpty = await execute(splitEmptyRepo, "split-empty-selection", {
    commits: [
      { files: [], commitMessage: "chore(test): block empty split selection" },
      { files: ["split-empty.txt"], commitMessage: "chore(test): split sibling" },
    ],
    dryRun: true,
    push: false,
  });
  assertError(splitEmpty, /no files? (were )?selected|empty.*selection/i, "split empty selection");

  const pushRepo = await makeRepo("push-");
  const remote = await tempDir("omp-commit-ui-remote-");
  await git(remote, ["init", "--bare"]);
  await git(pushRepo, ["remote", "add", "origin", remote]);
  await git(pushRepo, ["push", "-u", "origin", "HEAD"]);
  await writeFile(join(pushRepo, "push.txt"), "push me\n");
  const pushed = await execute(pushRepo, "push-success", {
    files: ["push.txt"],
    commitMessage: "chore(test): push selected file",
    dryRun: false,
    push: true,
  });
  assertSucceeded(pushed, "push success");
  const localPushedHead = (await git(pushRepo, ["rev-parse", "--short", "HEAD"])).stdout.trim();
  const remotePushedHead = (await git(remote, ["rev-parse", "--short", "HEAD"])).stdout.trim();
  if (remotePushedHead !== localPushedHead || hashOf(pushed) !== localPushedHead) {
    fail(`push success did not update remote and record hash: ${JSON.stringify({ remotePushedHead, localPushedHead, details: pushed.details })}`);
  }

  await git(pushRepo, ["remote", "set-url", "origin", join(pushRepo, "missing-remote.git")]);
  await writeFile(join(pushRepo, "push-fail.txt"), "push failure leaves local commit\n");
  const pushFailed = await execute(pushRepo, "push-failure", {
    files: ["push-fail.txt"],
    commitMessage: "chore(test): keep local commit on push failure",
    dryRun: false,
    push: true,
  });
  assertSucceeded(pushFailed, "push failure");
  if (!hashOf(pushFailed)) fail(`push failure did not keep a local commit hash: ${JSON.stringify(pushFailed.details)}`);
  if (!warningsOf(pushFailed).some(warning => /push/i.test(warning) && /fail|could not|rejected|fatal/i.test(warning))) {
    fail(`push failure warning missing: ${JSON.stringify(warningsOf(pushFailed))}`);
  }
  await assertCommittedFiles(pushRepo, ["HEAD^", "HEAD"], ["push-fail.txt"], "push failure local commit");

  const longRepo = await makeRepo("long-message-");
  await writeFile(join(longRepo, "long-message.txt"), "long message\n");
  const longMessage = [
    "this is not conventional and it is intentionally much longer than fifty characters",
    "",
    "This body line is intentionally much longer than seventy-two characters and must be preserved exactly as supplied by the current session agent.",
  ].join("\n");
  const long = await execute(longRepo, "long-non-conventional-message", {
    files: ["long-message.txt"],
    message: longMessage,
    dryRun: false,
    push: false,
  });
  assertSucceeded(long, "long non-conventional message");
  const loggedLongMessage = (await git(longRepo, ["log", "-1", "--pretty=%B"])).stdout.trimEnd();
  if (loggedLongMessage !== longMessage) fail(`long non-conventional message was not preserved: ${JSON.stringify({ loggedLongMessage, longMessage, details: long.details })}`);

  const legacyRepo = await makeRepo("legacy-metadata-");
  await mkdir(join(legacyRepo, "scripts"), { recursive: true });
  const verifier = join(legacyRepo, "scripts", "should-not-run.sh");
  await writeFile(verifier, "#!/bin/sh\necho ran > verification-ran.txt\nexit 42\n");
  await chmod(verifier, 0o755);
  await writeFile(join(legacyRepo, "legacy.txt"), "legacy metadata\n");
  const legacy = await execute(legacyRepo, "legacy-metadata-ignored", {
    files: ["legacy.txt"],
    commitMessage: "legacy metadata is ignored without checks",
    rationale: "old metadata should be accepted as inert compatibility input",
    verification: [{ command: "./scripts/should-not-run.sh", args: [], description: "must not run", required: true }],
    verificationEvidence: [{ description: "pretend evidence", source: "observed" }],
    acceptRisk: false,
    dryRun: false,
    push: false,
  });
  assertSucceeded(legacy, "legacy metadata ignored");
  if (await exists(join(legacyRepo, "verification-ran.txt"))) fail("legacy verification command was executed");
  const legacyRendered = renderResult(legacy, 80, "legacy metadata result", { expanded: true });
  if (/verification|risk/i.test(`${JSON.stringify(legacy)}\n${legacyRendered}`)) {
    fail(`legacy metadata leaked into result/render: ${JSON.stringify({ text: textOf(legacy), legacyRendered })}`);
  }

  const secretRepo = await makeRepo("secret-looking-");
  const rawSecret = ["sk", "proj", "test", "x".repeat(32)].join("-");
  await writeFile(join(secretRepo, "secretish.txt"), `export const apiKey = "${rawSecret}";\n`);
  const secret = await execute(secretRepo, "secret-looking-fixture", {
    files: ["secretish.txt"],
    commitMessage: "secret-looking fixture text is allowed",
    dryRun: true,
    push: false,
  });
  assertSucceeded(secret, "secret-looking fixture");
  const secretRendered = renderResult(secret, 90, "secret-looking result", { expanded: true });
  const secretOutput = `${JSON.stringify(secret)}\n${secretRendered}`;
  assertExcludes(secretOutput, rawSecret, "secret-looking fixture output");
  if (/secret findings/i.test(secretOutput)) fail(`secret-looking fixture used old secret findings UI: ${secretOutput}`);
  if (Array.isArray(secret.details?.secretFindings) && secret.details.secretFindings.length > 0) {
    fail(`secret-looking fixture should not report blocking secret findings: ${JSON.stringify(secret.details.secretFindings)}`);
  }
} finally {
  await Promise.all(tempPaths.map(path => rm(path, { recursive: true, force: true })));
}
TS
