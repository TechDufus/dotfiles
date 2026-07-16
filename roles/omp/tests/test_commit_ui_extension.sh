#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
extension_path="$repo_root/roles/omp/files/extensions/commit-ui.ts"
watchdog_path="$repo_root/roles/omp/files/WATCHDOG.md"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/omp-commit-ui.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

bun --check "$extension_path"

bun - "$extension_path" "$watchdog_path" "$test_root" <<'TS'
import { chmod, mkdir, readFile, realpath, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

const extensionPath = process.argv[2];
const watchdogPath = process.argv[3];
const testRoot = process.argv[4];
const extension = (await import(pathToFileURL(extensionPath).href)).default;

function fail(message) {
  throw new Error(message);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function equal(actual, expected, label) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function matches(value, pattern, label) {
  if (!pattern.test(String(value))) fail(`${label}: ${String(value)}`);
}

function excludes(value, pattern, label) {
  if (pattern.test(String(value))) fail(`${label}: ${String(value)}`);
}

function sameSet(actual, expected, label) {
  equal([...actual].sort(), [...expected].sort(), label);
}

function resultText(result) {
  return result?.content?.map(item => item?.text ?? "").join("\n") ?? "";
}

function assertSuccess(result, label) {
  if (result?.isError) fail(`${label} failed: ${resultText(result)}`);
}

function assertError(result, pattern, label) {
  if (!result?.isError) fail(`${label} unexpectedly succeeded: ${resultText(result)}`);
  matches(resultText(result), pattern, label);
}

class MockSchema {
  constructor(kind, value) {
    this.kind = kind;
    this.value = value;
    this.required = true;
    this.minimum = undefined;
    this.refinements = [];
  }
  optional() {
    this.required = false;
    return this;
  }
  min(value) {
    this.minimum = value;
    return this;
  }
  refine(predicate, message) {
    this.refinements.push({ predicate, message });
    return this;
  }
  describe(description) {
    this.description = description;
    return this;
  }
}

const zod = {
  string: () => new MockSchema("string"),
  array: item => new MockSchema("array", item),
  object: shape => new MockSchema("object", shape),
};

async function spawn(command, args, options = {}) {
  const child = Bun.spawn([command, ...args], {
    cwd: options.cwd,
    stdout: "pipe",
    stderr: "pipe",
    detached: process.platform !== "win32",
  });
  let killed = false;
  const terminate = () => {
    if (killed) return;
    killed = true;
    try {
      if (process.platform !== "win32") process.kill(-child.pid, "SIGKILL");
      else child.kill();
    } catch {
      try { child.kill(); } catch {}
    }
  };
  const timer = options.timeout ? setTimeout(terminate, options.timeout) : undefined;
  const abort = () => terminate();
  options.signal?.addEventListener("abort", abort, { once: true });
  if (options.signal?.aborted) terminate();
  try {
    const stdout = new Response(child.stdout).text();
    const stderr = new Response(child.stderr).text();
    const code = await child.exited;
    return { stdout: await stdout, stderr: await stderr, code, killed };
  } finally {
    if (timer) clearTimeout(timer);
    options.signal?.removeEventListener("abort", abort);
  }
}

async function git(cwd, args, allowFailure = false) {
  const result = await spawn("git", args, { cwd, timeout: 30_000 });
  if (!allowFailure && (result.code !== 0 || result.killed)) {
    fail(`git ${args.join(" ")} failed in ${cwd}: ${result.stderr || result.stdout}`);
  }
  return result;
}

let repoSequence = 0;
async function makeRepo(label, initialFiles = { "baseline.txt": "baseline\n" }) {
  const repo = join(testRoot, `${String(++repoSequence).padStart(2, "0")}-${label}`);
  await mkdir(repo, { recursive: true });
  await git(repo, ["init", "--quiet"]);
  await git(repo, ["config", "user.name", "Commit UI Test"]);
  await git(repo, ["config", "user.email", "commit-ui@example.invalid"]);
  await git(repo, ["config", "commit.gpgsign", "false"]);
  await git(repo, ["config", "core.hooksPath", ".git/hooks"]);
  if (initialFiles) {
    for (const [pathname, content] of Object.entries(initialFiles)) await writeRepo(repo, pathname, content);
    await git(repo, ["add", "--", "."]);
    await git(repo, ["commit", "--quiet", "-m", "chore(test): baseline"]);
  }
  return repo;
}

async function writeRepo(repo, pathname, content) {
  const target = join(repo, pathname);
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, content);
}

async function installHook(repo, name, script) {
  const hook = join(repo, ".git", "hooks", name);
  await writeFile(hook, `#!/bin/sh\nset -eu\n${script}\n`);
  await chmod(hook, 0o755);
}

async function head(repo) {
  const result = await git(repo, ["rev-parse", "--verify", "--quiet", "HEAD"], true);
  return result.code === 0 ? result.stdout.trim() : undefined;
}

async function indexTree(repo) {
  return (await git(repo, ["write-tree"])).stdout.trim();
}

async function committedPaths(repo, revision = "HEAD") {
  const result = await git(repo, ["diff-tree", "--root", "--no-commit-id", "--name-only", "--no-renames", "-r", "-z", revision]);
  return result.stdout.split("\0").filter(Boolean);
}

async function waitForFile(pathname, label) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    try {
      await readFile(pathname);
      return;
    } catch {
      await Bun.sleep(20);
    }
  }
  fail(`${label} did not start`);
}

const registrations = { tools: [], commands: [], events: [] };
const dispatches = [];
const activeTools = ["read", "bash", "grep"];
const activeToolMutations = [];
const execCalls = [];
let execImplementation = spawn;
const pi = {
  zod,
  registerTool: tool => registrations.tools.push(tool),
  registerCommand: (name, command) => registrations.commands.push({ name, command }),
  on: (...args) => registrations.events.push(args),
  getActiveTools: () => [...activeTools],
  setActiveTools: async tools => activeToolMutations.push([...tools]),
  sendMessage: (message, options) => dispatches.push({ message, options }),
  exec: async (command, args, options) => {
    execCalls.push({ command, args: [...args], options });
    return await execImplementation(command, args, options);
  },
};

extension(pi);
equal(registrations.tools.length, 1, "registered tool count");
equal(registrations.commands.length, 1, "registered command count");
equal(registrations.events.length, 0, "event hook count");
const tool = registrations.tools[0];
const command = registrations.commands[0];
equal(tool.name, "omp_commit", "tool name");
equal(command.name, "commit", "command name");
assert(!Object.hasOwn(tool, "defaultInactive"), "tool must be active by default");
for (const key of ["hidden", "renderCall", "renderResult", "onUpdate"]) {
  assert(!Object.hasOwn(tool, key), `tool unexpectedly defines ${key}`);
}
equal(Object.keys(tool.parameters.value).sort(), ["commitMessage", "files"], "tool schema fields");
const filesSchema = tool.parameters.value.files;
const messageSchema = tool.parameters.value.commitMessage;
assert(filesSchema.required && filesSchema.minimum === 1, "files schema must be required and non-empty");
assert(filesSchema.value.required && filesSchema.value.minimum === 1, "file elements must be required and non-empty");
assert(filesSchema.value.refinements.length === 1, "file schema must reject NUL");
assert(messageSchema.required && messageSchema.refinements.length === 1, "commitMessage must be required and refined");
assert(filesSchema.value.refinements[0].predicate("ok"), "valid path rejected by schema");
assert(!filesSchema.value.refinements[0].predicate("bad\0path"), "NUL path accepted by schema");
assert(messageSchema.refinements[0].predicate("fix(test): valid"), "valid message rejected by schema");
assert(!messageSchema.refinements[0].predicate("   "), "blank message accepted by schema");
assert(!messageSchema.refinements[0].predicate("bad\0message"), "NUL message accepted by schema");

matches(tool.description, /local checkpoint commit.*coherent, verified atomic unit/i, "tool checkpoint contract");
matches(tool.description, /supplied paths.*selected content.*unrelated changes.*secrets.*verification evidence/i, "tool review safeguards");
excludes(tool.description, /only after|requires? an explicit request/i, "tool obsolete request gate");

const watchdog = await readFile(watchdogPath, "utf8");
matches(watchdog, /do not flag the absence of a local checkpoint commit by itself/i, "watchdog commit non-objection");
matches(watchdog, /when a coherent, verified unit is about to move into distinct work, you may suggest one concise checkpoint/i, "watchdog checkpoint suggestion");
excludes(watchdog, /\[commit-authorization\]|one-use-marker/i, "watchdog obsolete protocol");

async function exerciseCommand(isIdle, rawContext) {
  const actions = [];
  const before = JSON.stringify(activeTools);
  const start = dispatches.length;
  await command.command.handler(rawContext, {
    isIdle: () => isIdle,
    waitForIdle: async () => actions.push("waitForIdle"),
    ui: {
      notify: (...args) => actions.push(["notify", ...args]),
      setWorkingMessage: (...args) => actions.push(["setWorkingMessage", ...args]),
      setWidget: (...args) => actions.push(["setWidget", ...args]),
    },
  });
  equal(dispatches.length, start + 1, "command dispatch count");
  equal(JSON.stringify(activeTools), before, "command active tools");
  return { actions, dispatch: dispatches.at(-1) };
}

const idleContext = "  --not-a-flag keep\\ spaces  ";
const idleCommand = await exerciseCommand(true, idleContext);
equal(idleCommand.actions, [], "idle command side effects");
const queuedContext = "context preserved --push --split";
const queuedCommand = await exerciseCommand(false, queuedContext);
equal(queuedCommand.actions, ["waitForIdle"], "queued command waiting");
for (const [label, rawContext, observed] of [
  ["idle", idleContext, idleCommand],
  ["queued", queuedContext, queuedCommand],
]) {
  const { message, options } = observed.dispatch;
  equal(message.customType, "commit-request", `${label} custom type`);
  equal(message.display, false, `${label} hidden request`);
  equal(message.attribution, "user", `${label} attribution`);
  equal(message.details.context, rawContext, `${label} raw command context`);
  equal(options, { triggerTurn: true, deliverAs: "nextTurn" }, `${label} delivery options`);
  const prompt = message.content;
  matches(prompt, /commit skill\/playbook.*file-selection.*secret-review.*verification evidence/is, `${label} prior evidence clause`);
  matches(prompt, /no tool other than omp_commit.*at most once/is, `${label} at-most-once clause`);
  matches(prompt, /both the old and new paths.*rename/is, `${label} rename clause`);
  matches(prompt, /exact path '\.'.*every current change/is, `${label} whole-repository clause`);
  matches(prompt, /50 characters.*72 characters/is, `${label} message format clause`);
  matches(prompt, /does not establish.*call no tools.*normal commit skill\/review/is, `${label} blocking clause`);
  assert(prompt.includes(JSON.stringify(rawContext)), `${label} prompt did not preserve raw context`);
}
equal(activeToolMutations, [], "active tool mutations");

async function execute(params, cwd, signal) {
  return await tool.execute("test-call", params, signal, () => fail("unexpected partial update"), { cwd });
}

function resetExec() {
  execCalls.length = 0;
  execImplementation = spawn;
}

function assertExecContract(calls, invokingCwd, root, selectedPaths) {
  assert(calls.length > 0, "no exec calls recorded");
  equal(calls[0].command, "git", "root probe command");
  equal(calls[0].args, ["rev-parse", "--show-toplevel"], "root probe argv");
  equal(calls[0].options.cwd, invokingCwd, "root probe cwd");
  for (const [index, call] of calls.entries()) {
    equal(call.command, "git", `exec ${index} command`);
    assert(Array.isArray(call.args), `exec ${index} did not receive argv array`);
    assert(Object.hasOwn(call.options, "cwd") && Object.hasOwn(call.options, "timeout") && Object.hasOwn(call.options, "signal"), `exec ${index} options contract`);
    if (index > 0) equal(call.options.cwd, root, `exec ${index} resolved cwd`);
    const subcommand = call.args[0] === "--literal-pathspecs" ? call.args[1] : call.args[0];
    if (["status", "add", "commit"].includes(subcommand)) {
      equal(call.args[0], "--literal-pathspecs", `${subcommand} global literal option`);
      const separator = call.args.indexOf("--");
      assert(separator > 0, `${subcommand} missing path separator`);
      equal(call.args.slice(separator + 1), selectedPaths, `${subcommand} selected paths`);
      equal(call.options.timeout, subcommand === "commit" ? 300_000 : 30_000, `${subcommand} timeout`);
    }
  }
}

resetExec();
const selectedRepo = await makeRepo("selected", {
  "selected-tracked.txt": "tracked baseline\n",
  "selected-deleted.txt": "delete baseline\n",
  "unrelated-modified.txt": "unrelated baseline\n",
  "unrelated-staged.txt": "staged baseline\n",
});
await writeRepo(selectedRepo, "selected-tracked.txt", "tracked current\n");
await Bun.file(join(selectedRepo, "selected-deleted.txt")).delete();
await writeRepo(selectedRepo, "selected-new.txt", "new current\n");
await writeRepo(selectedRepo, "unrelated-modified.txt", "unrelated current\n");
await writeRepo(selectedRepo, "unrelated-untracked.txt", "leave untracked\n");
await writeRepo(selectedRepo, "unrelated-staged.txt", "staged version\n");
await git(selectedRepo, ["add", "--", "unrelated-staged.txt"]);
const unrelatedCachedBefore = (await git(selectedRepo, ["show", ":unrelated-staged.txt"])).stdout;
await writeRepo(selectedRepo, "unrelated-staged.txt", "unstaged version\n");
const selectedMessage = "fix(test): selected paths\n\nPreserve unrelated state.";
const selectedPaths = ["selected-tracked.txt", "selected-deleted.txt", "selected-new.txt"];
const selectedResult = await execute({ files: selectedPaths, commitMessage: selectedMessage }, selectedRepo);
assertSuccess(selectedResult, "selected-path commit");
sameSet(await committedPaths(selectedRepo), selectedPaths, "selected committed paths");
equal((await git(selectedRepo, ["log", "-1", "--format=%B"])).stdout.trimEnd(), selectedMessage, "exact commit message");
equal((await git(selectedRepo, ["show", ":unrelated-staged.txt"])).stdout, unrelatedCachedBefore, "unrelated cached blob");
equal(await readFile(join(selectedRepo, "unrelated-staged.txt"), "utf8"), "unstaged version\n", "unrelated unstaged edit");
equal((await git(selectedRepo, ["show", "HEAD:unrelated-staged.txt"])).stdout, "staged baseline\n", "unrelated file excluded from HEAD");
sameSet((await git(selectedRepo, ["diff", "--cached", "--name-only"])).stdout.trim().split("\n").filter(Boolean), ["unrelated-staged.txt"], "unrelated staged path preserved");
sameSet((await git(selectedRepo, ["diff", "--name-only"])).stdout.trim().split("\n").filter(Boolean), ["unrelated-modified.txt", "unrelated-staged.txt"], "unrelated unstaged paths preserved");
matches((await git(selectedRepo, ["status", "--porcelain"])).stdout, /\?\? unrelated-untracked\.txt/, "unrelated untracked path preserved");
assertExecContract(execCalls, selectedRepo, await realpath(selectedRepo), selectedPaths);

resetExec();
const renameRepo = await makeRepo("rename", { "old-name.txt": "rename me\n" });
await rename(join(renameRepo, "old-name.txt"), join(renameRepo, "new-name.txt"));
const renameResult = await execute({ files: ["old-name.txt", "new-name.txt"], commitMessage: "fix(test): rename selected file" }, renameRepo);
assertSuccess(renameResult, "rename commit");
sameSet(await committedPaths(renameRepo), ["old-name.txt", "new-name.txt"], "rename endpoints");

resetExec();
const subdirRepo = await makeRepo("subdirectory", { "root.txt": "root baseline\n" });
await mkdir(join(subdirRepo, "nested", "directory"), { recursive: true });
await writeRepo(subdirRepo, "root.txt", "root current\n");
const invokingSubdir = join(subdirRepo, "nested", "directory");
const subdirResult = await execute({ files: ["root.txt"], commitMessage: "fix(test): resolve repository root" }, invokingSubdir);
assertSuccess(subdirResult, "subdirectory invocation");
assertExecContract(execCalls, invokingSubdir, await realpath(subdirRepo), ["root.txt"]);

if (process.platform !== "win32") {
  resetExec();
  const literalRepo = await makeRepo("literal-paths");
  const literalPaths = [":(glob)*.txt", "-leading.txt", "space name.txt", "back\\slash.txt"];
  for (const pathname of literalPaths) await writeRepo(literalRepo, pathname, `selected ${pathname}\n`);
  await writeRepo(literalRepo, "decoy.txt", "must remain untracked\n");
  const literalResult = await execute({ files: literalPaths, commitMessage: "fix(test): preserve literal paths" }, literalRepo);
  assertSuccess(literalResult, "literal path commit");
  sameSet(await committedPaths(literalRepo), literalPaths, "literal committed paths");
  matches((await git(literalRepo, ["status", "--porcelain"])).stdout, /\?\? decoy\.txt/, "literal glob decoy preserved");
  assertExecContract(execCalls, literalRepo, await realpath(literalRepo), literalPaths);
}

resetExec();
const tokenFixtureRepo = await makeRepo("token-fixture");
const fixtureToken = "github_pat_abcdefghijklmnopqrstuvwxyz0123456789";
await writeRepo(tokenFixtureRepo, "fixture.txt", `${fixtureToken}\n`);
const tokenFixtureResult = await execute({ files: ["fixture.txt"], commitMessage: "test(commit): accept reviewed fixture" }, tokenFixtureRepo);
assertSuccess(tokenFixtureResult, "token-shaped reviewed fixture");
assert(execCalls.every(call => call.command === "git"), "token fixture invoked a non-Git process");
equal((await git(tokenFixtureRepo, ["show", "HEAD:fixture.txt"])).stdout.trim(), fixtureToken, "token-shaped fixture content");

const rejectionRepo = await makeRepo("rejections", { "selected.txt": "baseline\n", "unchanged.txt": "unchanged\n" });
await writeRepo(rejectionRepo, "selected.txt", "pending\n");
const rejectionCases = [
  { params: { files: [], commitMessage: "fix(test): empty files" }, label: "empty files" },
  { params: { files: [""], commitMessage: "fix(test): empty path" }, label: "empty path" },
  { params: { files: ["bad\0path"], commitMessage: "fix(test): NUL path" }, label: "NUL path" },
  { params: { files: [join(rejectionRepo, "selected.txt")], commitMessage: "fix(test): absolute path" }, label: "absolute path" },
  { params: { files: ["../selected.txt"], commitMessage: "fix(test): escaping path" }, label: "escaping path" },
  { params: { files: ["src/../selected.txt"], commitMessage: "fix(test): internal parent" }, label: "internal parent segment" },
  { params: { files: ["./"], commitMessage: "fix(test): slash root" }, label: "slash root" },
  { params: { files: ["./."], commitMessage: "fix(test): dotted root" }, label: "dotted root" },
  { params: { files: ["selected.txt"], commitMessage: "" }, label: "empty message" },
  { params: { files: ["selected.txt"], commitMessage: "   " }, label: "blank message" },
  { params: { files: ["selected.txt"], commitMessage: "bad\0message" }, label: "NUL message" },
  { params: { files: ["unchanged.txt"], commitMessage: "fix(test): no selected change" }, label: "unchanged selection" },
];
for (const rejection of rejectionCases) {
  resetExec();
  const beforeHead = await head(rejectionRepo);
  const beforeIndex = await indexTree(rejectionRepo);
  const result = await execute(rejection.params, rejectionRepo);
  assert(result.isError, `${rejection.label} should fail`);
  equal(await head(rejectionRepo), beforeHead, `${rejection.label} HEAD`);
  equal(await indexTree(rejectionRepo), beforeIndex, `${rejection.label} index`);
  assert(!execCalls.some(call => call.args.includes("add") || call.args.includes("commit")), `${rejection.label} reached mutation`);
}

resetExec();
const dotRepo = await makeRepo("dot-selection", { "one.txt": "one\n", "two.txt": "two\n" });
await writeRepo(dotRepo, "one.txt", "one current\n");
await writeRepo(dotRepo, "two.txt", "two current\n");
const dotResult = await execute({ files: ["."], commitMessage: "fix(test): select every change" }, dotRepo);
assertSuccess(dotResult, "exact dot selection");
sameSet(await committedPaths(dotRepo), ["one.txt", "two.txt"], "exact dot committed paths");

resetExec();
const partialRepo = await makeRepo("partial-stage", { "partial.txt": "first baseline\nsecond baseline\n" });
await writeRepo(partialRepo, "partial.txt", "first staged\nsecond baseline\n");
await git(partialRepo, ["add", "--", "partial.txt"]);
await writeRepo(partialRepo, "partial.txt", "first staged\nsecond working\n");
const partialResult = await execute({ files: ["partial.txt"], commitMessage: "fix(test): commit whole selected path" }, partialRepo);
assertSuccess(partialResult, "partial staged selected path");
equal((await git(partialRepo, ["show", "HEAD:partial.txt"])).stdout, "first staged\nsecond working\n", "selected path complete working state");

resetExec();
const failedHookRepo = await makeRepo("failing-hook", { "selected.txt": "baseline\n" });
await writeRepo(failedHookRepo, "selected.txt", "pending\n");
const hookToken = "github_pat_hookabcdefghijklmnopqrstuvwxyz";
await installHook(failedHookRepo, "pre-commit", `printf '%s\\n' '${hookToken}' >&2\nprintf '%s\\n' '-----BEGIN PRIVATE KEY-----' 'private material without an end marker' >&2\nprintf '%1600s\\n' 'bounded output' >&2\nexit 1`);
const failedHookHead = await head(failedHookRepo);
const failedHookResult = await execute({ files: ["selected.txt"], commitMessage: "fix(test): rejected by hook" }, failedHookRepo);
assertError(failedHookResult, /failed during commit/i, "failing pre-commit hook phase");
matches(resultText(failedHookResult), /Selected paths may remain staged/i, "failing hook staged warning");
excludes(resultText(failedHookResult), new RegExp(hookToken), "hook token redaction");
excludes(resultText(failedHookResult), /BEGIN PRIVATE KEY|private material|bounded output/, "incomplete hook private key redaction");
assert(resultText(failedHookResult).length <= 1_600, "hook error output was not bounded");
equal(await head(failedHookRepo), failedHookHead, "failing hook HEAD");

resetExec();
const rewriteRepo = await makeRepo("rewrite-message", { "selected.txt": "baseline\n" });
await writeRepo(rewriteRepo, "selected.txt", "pending\n");
await installHook(rewriteRepo, "commit-msg", `printf '%s\\n' 'fix(test): rewritten by hook' > "$1"`);
const rewriteResult = await execute({ files: ["selected.txt"], commitMessage: "fix(test): requested subject" }, rewriteRepo);
assertSuccess(rewriteResult, "commit-msg rewrite");
matches(resultText(rewriteResult), /Subject: fix\(test\): rewritten by hook/, "actual rewritten subject");
const rewriteOid = (await git(rewriteRepo, ["rev-parse", "HEAD"])).stdout.trim();
const postOidCalls = execCalls.filter(call => JSON.stringify(call.args) === JSON.stringify(["rev-parse", "HEAD"]));
equal(postOidCalls.length, 1, "immutable OID resolution count");
assert(execCalls.some(call => JSON.stringify(call.args) === JSON.stringify(["rev-parse", "--short", rewriteOid])), "short hash did not use immutable OID");
assert(execCalls.some(call => JSON.stringify(call.args) === JSON.stringify(["show", "-s", "--format=%s", rewriteOid])), "subject did not use immutable OID");
assert(execCalls.some(call => call.args[0] === "diff-tree" && call.args.at(-1) === rewriteOid), "path inspection did not use immutable OID");

resetExec();
const redactedSuccessRepo = await makeRepo("redacted-success");
const successToken = "github_pat_successabcdefghijklmnopqrstuvwxyz";
await writeRepo(redactedSuccessRepo, successToken, "reviewed fixture\n");
await installHook(redactedSuccessRepo, "commit-msg", `printf '%s\\n' '${successToken}' > "$1"`);
const redactedSuccess = await execute({ files: [successToken], commitMessage: "test(commit): requested safe subject" }, redactedSuccessRepo);
assertSuccess(redactedSuccess, "redacted success result");
excludes(resultText(redactedSuccess), new RegExp(successToken), "success field token redaction");
matches(resultText(redactedSuccess), /<redacted-token>/, "success redaction marker");

async function makeCancellationRepo(label, initialFiles = { "selected.txt": "baseline\n" }) {
  const repo = await makeRepo(label, initialFiles);
  await writeRepo(repo, "selected.txt", "pending\n");
  return repo;
}

resetExec();
const mockPreRepo = await makeCancellationRepo("mock-pre-cancel");
const mockPreController = new AbortController();
execImplementation = async (program, args, options) => {
  if (args[0] === "--literal-pathspecs" && args[1] === "commit") {
    mockPreController.abort();
    throw new Error("mock commit interruption");
  }
  return await spawn(program, args, options);
};
const mockPreHead = await head(mockPreRepo);
const mockPreResult = await execute({ files: ["selected.txt"], commitMessage: "fix(test): mock pre cancel" }, mockPreRepo, mockPreController.signal);
assertError(mockPreResult, /mock commit interruption|cancelled/i, "mock pre-commit cancellation");
excludes(resultText(mockPreResult), /outcome indeterminate/i, "mock unchanged reconciliation");
equal(await head(mockPreRepo), mockPreHead, "mock pre-cancel HEAD");
const mockPreReconcile = execCalls.find(call => call.options.timeout === 5_000);
assert(mockPreReconcile, "mock pre-cancel did not reconcile HEAD");
assert(mockPreReconcile.options.signal !== mockPreController.signal, "reconciliation reused aborted caller signal");

resetExec();
const mockPostRepo = await makeCancellationRepo("mock-post-cancel");
const mockPostController = new AbortController();
execImplementation = async (program, args, options) => {
  if (args[0] === "--literal-pathspecs" && args[1] === "commit") {
    await spawn(program, args, options);
    mockPostController.abort();
    throw new Error("mock return lost after commit");
  }
  return await spawn(program, args, options);
};
const mockPostHead = await head(mockPostRepo);
const mockPostResult = await execute({ files: ["selected.txt"], commitMessage: "fix(test): mock post cancel" }, mockPostRepo, mockPostController.signal);
assertError(mockPostResult, /outcome indeterminate/i, "mock post-commit cancellation");
assert((await head(mockPostRepo)) !== mockPostHead, "mock post-cancel fixture did not advance HEAD");
excludes(resultText(mockPostResult), /\b(?:blocked|created)\b/i, "indeterminate attribution");

resetExec();
const unreadableRepo = await makeCancellationRepo("unreadable-reconcile");
execImplementation = async (program, args, options) => {
  if (args[0] === "--literal-pathspecs" && args[1] === "commit") throw new Error("mock process loss");
  if (options.timeout === 5_000) throw new Error("mock unreadable HEAD");
  return await spawn(program, args, options);
};
const unreadableResult = await execute({ files: ["selected.txt"], commitMessage: "fix(test): unreadable reconciliation" }, unreadableRepo);
assertError(unreadableResult, /outcome indeterminate/i, "unreadable reconciliation");

resetExec();
const killedRepo = await makeCancellationRepo("killed-zero");
execImplementation = async (program, args, options) => {
  if (args[0] === "--literal-pathspecs" && args[1] === "commit") return { stdout: "", stderr: "", code: 0, killed: true };
  return await spawn(program, args, options);
};
const killedHead = await head(killedRepo);
const killedResult = await execute({ files: ["selected.txt"], commitMessage: "fix(test): killed result" }, killedRepo);
assertError(killedResult, /killed|timed out/i, "code-zero killed result");
equal(await head(killedRepo), killedHead, "code-zero killed HEAD");

resetExec();
const realPreRepo = await makeCancellationRepo("real-pre-cancel");
await installHook(realPreRepo, "pre-commit", `: > .git/pre-cancel-started\nexec sleep 30`);
const realPreController = new AbortController();
const realPreHead = await head(realPreRepo);
const realPrePromise = execute({ files: ["selected.txt"], commitMessage: "fix(test): real pre cancel" }, realPreRepo, realPreController.signal);
await waitForFile(join(realPreRepo, ".git", "pre-cancel-started"), "real pre-commit hook");
realPreController.abort();
const realPreResult = await realPrePromise;
assertError(realPreResult, /cancelled|interrupted|killed/i, "real pre-commit cancellation");
excludes(resultText(realPreResult), /outcome indeterminate/i, "real pre-cancel reconciliation");
equal(await head(realPreRepo), realPreHead, "real pre-cancel HEAD");

resetExec();
const realPostRepo = await makeCancellationRepo("real-post-cancel");
await installHook(realPostRepo, "post-commit", `: > .git/post-cancel-started\nexec sleep 30`);
const realPostController = new AbortController();
const realPostHead = await head(realPostRepo);
const realPostPromise = execute({ files: ["selected.txt"], commitMessage: "fix(test): real post cancel" }, realPostRepo, realPostController.signal);
await waitForFile(join(realPostRepo, ".git", "post-cancel-started"), "real post-commit hook");
realPostController.abort();
const realPostResult = await realPostPromise;
assertError(realPostResult, /outcome indeterminate/i, "real post-commit cancellation");
assert((await head(realPostRepo)) !== realPostHead, "real post-cancel fixture did not advance HEAD");

resetExec();
const unbornRepo = await makeRepo("unborn", null);
await writeRepo(unbornRepo, "root.txt", "root commit\n");
const unbornResult = await execute({ files: ["root.txt"], commitMessage: "feat(test): create root commit" }, unbornRepo);
assertSuccess(unbornResult, "unborn repository commit");
assert(await head(unbornRepo), "unborn repository did not create HEAD");
sameSet(await committedPaths(unbornRepo), ["root.txt"], "unborn root paths");

resetExec();
const unbornCancelledRepo = await makeRepo("unborn-cancelled", null);
await writeRepo(unbornCancelledRepo, "root.txt", "root commit\n");
const unbornController = new AbortController();
execImplementation = async (program, args, options) => {
  if (args[0] === "--literal-pathspecs" && args[1] === "commit") {
    await spawn(program, args, options);
    unbornController.abort();
    throw new Error("mock unborn return loss");
  }
  return await spawn(program, args, options);
};
const unbornCancelledResult = await execute({ files: ["root.txt"], commitMessage: "feat(test): uncertain root" }, unbornCancelledRepo, unbornController.signal);
assertError(unbornCancelledResult, /outcome indeterminate/i, "unborn advanced reconciliation");
assert(await head(unbornCancelledRepo), "unborn cancelled fixture did not create HEAD");

const inspectionCases = [
  { label: "OID", predicate: args => JSON.stringify(args) === JSON.stringify(["rev-parse", "HEAD"]), missing: [/^Hash:/m, /^Subject:/m, /^Paths:/m] },
  { label: "short hash", predicate: args => args[0] === "rev-parse" && args[1] === "--short", missing: [/^Hash:/m] },
  { label: "subject", predicate: args => args[0] === "show" && args.includes("--format=%s"), missing: [/^Subject:/m] },
  { label: "paths", predicate: args => args[0] === "diff-tree", missing: [/^Paths:/m] },
];
for (const inspectionCase of inspectionCases) {
  resetExec();
  const repo = await makeCancellationRepo(`inspection-${inspectionCase.label.replaceAll(" ", "-")}`);
  const inspectionToken = "github_pat_inspectionabcdefghijklmnopqrstuvwxyz";
  let injected = false;
  execImplementation = async (program, args, options) => {
    if (!injected && inspectionCase.predicate(args)) {
      injected = true;
      return { stdout: "", stderr: `inspection failed ${inspectionToken}`, code: 1, killed: false };
    }
    return await spawn(program, args, options);
  };
  const result = await execute({ files: ["selected.txt"], commitMessage: `fix(test): ${inspectionCase.label} warning` }, repo);
  assertSuccess(result, `${inspectionCase.label} inspection failure`);
  matches(resultText(result), /Commit succeeded\./, `${inspectionCase.label} known success`);
  matches(resultText(result), /Warning:/, `${inspectionCase.label} warning`);
  excludes(resultText(result), new RegExp(inspectionToken), `${inspectionCase.label} warning redaction`);
  for (const missing of inspectionCase.missing) excludes(resultText(result), missing, `${inspectionCase.label} fabricated field`);
}

assert(activeToolMutations.length === 0, "tool execution mutated active tools");
console.log("commit-ui extension tests passed");
TS
