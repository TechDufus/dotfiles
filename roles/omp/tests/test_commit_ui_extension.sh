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
const COMMIT_WIDGET_KEY = "omp_commit";
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
const agentEndHandler = eventHandlers("agent_end").find(handler => typeof handler === "function");
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

function captureIntervals() {
  const realSetInterval = globalThis.setInterval;
  const realClearInterval = globalThis.clearInterval;
  const timers = [];
  globalThis.setInterval = ((callback, delay, ...args) => {
    const timer = {
      callback,
      delay,
      args,
      cleared: false,
      unref() {
        return timer;
      },
      ref() {
        return timer;
      },
    };
    timers.push(timer);
    return timer;
  }) as typeof globalThis.setInterval;
  globalThis.clearInterval = ((timer) => {
    const captured = timers.find(candidate => candidate === timer);
    if (captured) {
      captured.cleared = true;
      return undefined;
    }
    return realClearInterval(timer);
  }) as typeof globalThis.clearInterval;
  return {
    timers,
    tick: async () => {
      for (const timer of [...timers]) {
        if (timer.cleared || typeof timer.callback !== "function") continue;
        await timer.callback(...timer.args);
      }
    },
    restore: () => {
      globalThis.setInterval = realSetInterval;
      globalThis.clearInterval = realClearInterval;
    },
  };
}

function assertCommitWidgetSetAction(action, label) {
  if (!action || action[0] !== "setWidget" || action[1] !== COMMIT_WIDGET_KEY) {
    fail(`${label} did not set the ${COMMIT_WIDGET_KEY} widget: ${JSON.stringify(action)}`);
  }
  if (typeof action[2] !== "function") {
    fail(`${label} widget action did not include a render factory: ${JSON.stringify(action)}`);
  }
  const placement = String(action[3]?.placement ?? "");
  if (!/above/i.test(placement)) {
    fail(`${label} widget should be placed above the editor/input: ${JSON.stringify(action[3])}`);
  }
}

function assertWidgetCleared(actionList, label) {
  const clear = actionList.find(action => action[0] === "setWidget" && action[1] === COMMIT_WIDGET_KEY && action[2] === undefined);
  if (!clear) fail(`${label} did not clear the ${COMMIT_WIDGET_KEY} widget: ${JSON.stringify(actionList)}`);
  return clear;
}
function assertWorkingMessageCleared(actionList, label) {
  const clear = actionList.find(action => action[0] === "setWorkingMessage" && action[1] === undefined);
  if (!clear) fail(`${label} did not clear the working message: ${JSON.stringify(actionList)}`);
  return clear;
}


function mountCommitWidget(action, label) {
  assertCommitWidgetSetAction(action, label);
  const intervals = captureIntervals();
  const requests = [];
  try {
    const component = action[2]({
      requestRender: () => requests.push(Date.now()),
    });
    return { component, intervals, requests };
  } catch (error) {
    intervals.restore();
    throw error;
  }
}

async function assertImmediateCommitWidget(action, label) {
  const mounted = mountCommitWidget(action, label);
  try {
    const rendered = render(mounted.component, 54, label);
    assertBoxed(rendered, label);
    assertMatches(rendered, /commit/i, `${label} commit context`);
    assertMatches(rendered, /Planning commit|commit planning|planning/i, `${label} planning context`);
    liveActivityRow(rendered, /Planning commit|commit planning|planning|commit/i, label);
    assertVisibleProgress(rendered, label);
    if (mounted.intervals.timers.length === 0) {
      fail(`${label} did not start a live spinner/progress interval`);
    }
    await mounted.intervals.tick();
    if (mounted.requests.length === 0) {
      fail(`${label} interval did not request a render`);
    }
    const rerendered = render(mounted.component, 54, `${label} rerender`);
    if (rendered === rerendered) {
      fail(`${label} did not change after a spinner/state tick: ${rendered}`);
    }
    return { rendered, rerendered };
  } finally {
    mounted.intervals.restore();
  }
}

function assertIncludes(value, expected, label) {
  if (!String(value).includes(expected)) fail(`${label} missing ${expected}: ${value}`);
}

function assertMatches(value, pattern, label) {
  if (!pattern.test(String(value))) fail(`${label} did not match ${pattern}: ${value}`);
}

function assertNotMatches(value, pattern, label) {
  if (pattern.test(String(value))) fail(`${label} unexpectedly matched ${pattern}: ${value}`);
}

function assertExcludes(value, unexpected, label) {
  if (String(value).includes(unexpected)) fail(`${label} unexpectedly included ${unexpected}: ${value}`);
}

function assertBoxed(value, label) {
  assertMatches(value, /[┌┏╭╔╒╓]/, `${label} top border`);
  assertMatches(value, /[└┗╰╚╘╙]/, `${label} bottom border`);
}

function assertCompactCallTeaser(value, label, options = {}) {
  const text = String(value);
  const lines = text.split("\n");
  if (lines.length !== 1) fail(`${label} should render as one compact receipt line: ${value}`);
  const line = lines[0].trim();
  for (const pattern of [
    /Waiting for tool call/i,
    /[┌┐└┘┏┓┗┛╭╮╰╯╔╗╚╝╒╕╘╛]/,
    /[│║┃├┝┠└┕┗╟╙]/,
    /[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/,
  ]) {
    if (pattern.test(text)) fail(`${label} used boxed, railed, spinner, or waiting UI ${pattern}: ${value}`);
  }
  const countSuffix = typeof options.expectedFiles === "number"
    ? `(?:\\s+·\\s+${options.expectedFiles}\\s+files?)?`
    : "(?:\\s+·\\s+\\d+\\s+files?)?";
  const receiptPattern = new RegExp(`^\\/commit queued${countSuffix}$`, "i");
  if (!receiptPattern.test(line)) fail(`${label} should only show /commit queued with an optional file count: ${value}`);
}

function assertConciseNotification(action, label) {
  const message = String(action?.[1] ?? "");
  if (!message) fail(`${label} notification message was empty: ${JSON.stringify(action)}`);
  if (message.split("\n").length !== 1 || message.length > 96) {
    fail(`${label} notification should be a concise one-line status: ${message}`);
  }
  for (const pattern of [
    /[┌┐└┘┏┓┗┛╭╮╰╯╔╗╚╝╒╕╘╛]/,
    /[│║┃├┝┠└┕┗╟╙]/,
    /[━─█░▒▓■□▰▱]{4,}/,
  ]) {
    if (pattern.test(message)) fail(`${label} notification looked like a rich card: ${message}`);
  }
  assertMatches(message, /commit/i, `${label} notification text`);
}

function assertStaticRender(rendered, rerendered, label) {
  if (rendered !== rerendered) fail(`${label} changed between spinner frames: ${JSON.stringify({ rendered, rerendered })}`);
}

function progressBarStats(value, label) {
  const filledPattern = /[━█▓▒■▰]/;
  const emptyPattern = /[─░□▱]/;
  const barPattern = /[━─█░▒▓■□▰▱]{4,}/;
  const bar = String(value)
    .split("\n")
    .map(line => line.match(barPattern)?.[0])
    .find(match => match && filledPattern.test(match));
  if (!bar) fail(`${label} missing visible progress bar: ${value}`);
  const glyphs = [...bar];
  const filled = glyphs.filter(glyph => filledPattern.test(glyph)).length;
  const empty = glyphs.filter(glyph => emptyPattern.test(glyph)).length;
  const total = filled + empty;
  if (total < 4 || filled === 0) fail(`${label} progress bar was not measurable: ${value}`);
  return { bar, filled, total, ratio: filled / total };
}

function assertVisibleProgress(value, label) {
  assertMatches(value, /\bProgress\b/i, `${label} progress label`);
  return progressBarStats(value, label);
}

function renderedLines(value) {
  return String(value).split("\n");
}

function liveActivityRow(value, phasePattern, label) {
  const row = renderedLines(value).find(line =>
    /(?:Working|Activity|Current|Now|Live|Running|In progress|Doing|Status)\s*:/i.test(line) &&
    phasePattern.test(line)
  );
  if (!row) fail(`${label} missing a live activity/detail row: ${value}`);
  if (!/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏✦]/.test(row)) {
    fail(`${label} live activity/detail row was not visibly animated: ${row}\n${value}`);
  }
  return row;
}

function assertPendingSelectionSignal(value, label) {
  assertNotMatches(value, /\b0\s+files?\b/i, `${label} unresolved file count`);
  assertMatches(value, /\b(?:files?|selection|changes?)\b/i, `${label} pending file context`);
  assertMatches(value, /\b(?:pending|scanning|selecting|discovering|resolving|checking|detecting|loading)\b/i, `${label} pending file signal`);
}

function assertCollapsedLeftOut(value, width, label) {
  const line = renderedLines(value).find(candidate => /\bLeft out\b/i.test(candidate));
  if (!line) fail(`${label} lost Left out label: ${value}`);
  if (line.length > width) fail(`${label} Left out line exceeded width ${width}: ${line}\n${value}`);
  assertMatches(line, /\bLeft out\b\s*:\s*\S/i, `${label} left out label and value`);
  assertNotMatches(line, /;\s*…|;…|;\s*$/, `${label} malformed semicolon truncation`);
  assertNotMatches(line, /\bLeft out\b\s*:\s*(?:…|\.\.\.)\s*$/i, `${label} collapsed away ignored file context`);
  assertMatches(line, /\b\d+\s+files?\b/i, `${label} left out count`);
  assertMatches(line, /ignored\//i, `${label} ignored path context`);
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

function assertDistinctSnapshotRefs(snapshot, finalDetails, label) {
  if (snapshot === finalDetails) fail(`${label} reused the final details object`);
  for (const key of ["steps", "commits", "selectedFiles", "ignoredFiles", "warnings"]) {
    if (Array.isArray(snapshot?.[key]) && Array.isArray(finalDetails?.[key]) && snapshot[key] === finalDetails[key]) {
      fail(`${label} reused mutable ${key} array`);
    }
  }
  if (snapshot?.steps?.[0] && finalDetails?.steps?.[0] && snapshot.steps[0] === finalDetails.steps[0]) {
    fail(`${label} reused mutable step row objects`);
  }
  if (snapshot?.commits?.[0] && finalDetails?.commits?.[0] && snapshot.commits[0] === finalDetails.commits[0]) {
    fail(`${label} reused mutable commit row objects`);
  }
}

function assertLiveUpdateSnapshots(updates, result, label) {
  const snapshots = updates.map(update => update?.details).filter(details => details?.kind === "omp_commit");
  if (snapshots.length === 0) fail(`${label} did not emit details snapshots`);
  const finalDetails = result?.details;
  if (!finalDetails) fail(`${label} returned no final details: ${JSON.stringify(result)}`);
  const partialSnapshots = snapshots.length > 1 ? snapshots.slice(0, -1) : snapshots;
  for (const snapshot of partialSnapshots) assertDistinctSnapshotRefs(snapshot, finalDetails, `${label} partial update snapshot`);

  const phases = snapshots.map(details => ({ status: details.status, phase: details.phase }));
  const runningSnapshot = snapshots.find(details => details.status === "running" && details.phase && details.phase !== finalDetails.phase);
  if (!runningSnapshot) {
    fail(`${label} did not preserve a running/intermediate update snapshot: ${JSON.stringify(phases)}`);
  }
  assertDistinctSnapshotRefs(runningSnapshot, finalDetails, `${label} running update snapshot`);
  if (runningSnapshot.finalText) {
    fail(`${label} running snapshot already had final text: ${JSON.stringify(runningSnapshot)}`);
  }
  const runningStepSnapshot = snapshots.find(details => details.steps?.some(step => step.status === "running"));
  if (!runningStepSnapshot) {
    fail(`${label} did not preserve a snapshot with a running step: ${JSON.stringify(snapshots.map(details => details.steps))}`);
  }
  const runningCommitSnapshot = snapshots.find(details => details.commits?.some(commit => commit.status === "running"));
  if (!runningCommitSnapshot) {
    fail(`${label} did not preserve a snapshot with a running commit row: ${JSON.stringify(snapshots.map(details => details.commits))}`);
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
    ui: {
      notify: (...args) => actions.push(["notify", ...args]),
      setWorkingMessage: (...args) => actions.push(["setWorkingMessage", ...args]),
      setWidget: (...args) => actions.push(["setWidget", ...args]),
    },
  };

  const commandContext = "Current context: commit the focused test refactor only.";
  await command.handler(`--dry-run --push --split ${commandContext}`, idleCtx);
  const widgetIndex = actions.findIndex(action => action[0] === "setWidget" && action[1] === COMMIT_WIDGET_KEY && typeof action[2] === "function");
  if (widgetIndex === -1) fail(`/commit command did not set an immediate ${COMMIT_WIDGET_KEY} widget: ${JSON.stringify(actions)}`);
  const widgetAction = actions[widgetIndex];
  assertCommitWidgetSetAction(widgetAction, "/commit immediate widget");
  const firstWorkflowIndex = actions.findIndex(action =>
    action[0] === "setWidget" ||
    action[0] === "notify" ||
    action[0] === "setWorkingMessage" ||
    action[0] === "setActiveTools" ||
    action[0] === "sendMessage"
  );
  if (firstWorkflowIndex !== widgetIndex) {
    fail(`/commit command did not set the live widget before any visible, tool-isolation, or prompt side effect: ${JSON.stringify(actions)}`);
  }
  const feedbackIndex = actions.findIndex(action => action[0] === "notify");
  if (feedbackIndex === -1) fail("/commit command did not show immediate visible feedback");
  assertConciseNotification(actions[feedbackIndex], "/commit immediate feedback");
  const workingIndex = actions.findIndex(action => action[0] === "setWorkingMessage");
  if (workingIndex === -1) fail("/commit command did not set a working message");
  if (actions[workingIndex][1] !== "Planning commit…") {
    fail(`/commit command set unexpected working message: ${JSON.stringify(actions[workingIndex])}`);
  }
  const toolIsolationIndex = actions.findIndex(action => action[0] === "setActiveTools");
  const isolated = toolIsolationIndex === -1 ? undefined : actions[toolIsolationIndex];
  if (!isolated || isolated[1].join(",") !== "omp_commit") {
    fail(`commit command did not isolate active tools: ${JSON.stringify(actions)}`);
  }
  const sentIndex = actions.findIndex(action => action[0] === "sendMessage");
  const sent = sentIndex === -1 ? undefined : actions[sentIndex];
  if (!sent) fail("commit command did not send a hidden prompt");
  if (widgetIndex > feedbackIndex) fail("/commit command showed visible feedback before the live widget");
  if (widgetIndex > workingIndex) fail("/commit command set the working message before the live widget");
  if (widgetIndex > toolIsolationIndex) fail("/commit command isolated active tools before the live widget");
  if (widgetIndex > sentIndex) fail(`/commit command set the live widget after the hidden prompt: ${JSON.stringify(actions)}`);
  if (feedbackIndex > sentIndex) fail("/commit command showed visible feedback after the hidden prompt");
  if (workingIndex > sentIndex) fail("/commit command set the working message after the hidden prompt");
  if (toolIsolationIndex > sentIndex) fail("/commit command isolated active tools after the hidden prompt");
  await assertImmediateCommitWidget(widgetAction, "/commit immediate widget");
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
  assertMatches(promptEnvelope, /type\(scope\):\s*summary/i, "hidden prompt conventional commit shape");
  for (const preferredType of ["fix", "feat", "refactor", "docs", "test", "chore", "ci"]) {
    assertMatches(promptEnvelope, new RegExp(`\\b${preferredType}\\b`, "i"), `hidden prompt preferred type ${preferredType}`);
  }
  assertMatches(promptEnvelope, /(?:subject|summary|first line)[^.\n]{0,120}50[-\s]*(?:characters?|chars?|columns?)|50[-\s]*(?:characters?|chars?|columns?)[^.\n]{0,120}(?:subject|summary|first line)/i, "hidden prompt subject length");
  assertMatches(promptEnvelope, /(?:body|non-blank|line)[^.\n]{0,120}72[-\s]*(?:characters?|chars?|columns?)|72[-\s]*(?:characters?|chars?|columns?)[^.\n]{0,120}(?:body|non-blank|line)/i, "hidden prompt body wrapping");
  assertNotMatches(promptEnvelope, /(?:messages?|commit messages?)[^.\n]{0,80}(?:only|just)[^.\n]{0,80}(?:non[-\s]?empty|not\s+empty)|(?:any|arbitrary)[^.\n]{0,80}(?:non[-\s]?empty|not\s+empty)[^.\n]{0,80}(?:messages?|commit messages?|strings?)|arbitrary[^.\n]{0,80}(?:messages?|commit messages?)/i, "hidden prompt arbitrary message guidance");
  if (prompt.details?.dryRun !== true || prompt.details?.push !== true || prompt.details?.multiCommit !== true) {
    fail(`commit command did not parse dry-run/push/split details: ${JSON.stringify(prompt.details)}`);
  }
  for (const forbidden of ["HOME_SKILL_SENTINEL", "verificationEvidence", "acceptRisk", "./scripts/check.sh"]) {
    assertExcludes(promptEnvelope, forbidden, "hidden prompt");
  }

  if (!turnEndHandler) fail("commit command did not register turn_end active-tool restoration");
  actions.length = 0;
  await turnEndHandler();
  assertWidgetCleared(actions, "/commit turn_end cleanup");
  assertWorkingMessageCleared(actions, "/commit turn_end cleanup");
  const restored = actions.find(action => action[0] === "setActiveTools");
  if (!restored || restored[1].join(",") !== "read,bash") {
    fail(`commit command did not restore previous active tools: ${JSON.stringify(actions)}`);
  }

  if (!agentEndHandler) fail("commit command did not register agent_end active-tool restoration");
  actions.length = 0;
  await command.handler("--dry-run agent-end cleanup", idleCtx);
  actions.length = 0;
  await agentEndHandler();
  assertWidgetCleared(actions, "/commit agent_end cleanup");
  assertWorkingMessageCleared(actions, "/commit agent_end cleanup");
  const agentRestored = actions.find(action => action[0] === "setActiveTools");
  if (!agentRestored || agentRestored[1].join(",") !== "read,bash") {
    fail(`commit command did not restore previous active tools on agent_end: ${JSON.stringify(actions)}`);
  }

  actions.length = 0;
  await command.handler("--dry-run tool completion cleanup", idleCtx);
  const completionWidget = actions.find(action => action[0] === "setWidget" && action[1] === COMMIT_WIDGET_KEY && typeof action[2] === "function");
  if (!completionWidget) fail(`/commit command did not set a widget for tool completion cleanup: ${JSON.stringify(actions)}`);
  const completionRepo = await makeRepo("widget-cleanup-");
  actions.length = 0;
  const completion = await execute(completionRepo, "widget-cleanup", {
    commitMessage: "chore(test): widget cleanup",
    dryRun: true,
    push: false,
  });
  assertError(completion, /No working tree changes to commit/i, "tool completion widget cleanup fixture");
  assertWidgetCleared(actions, "/commit tool completion cleanup");
  assertWorkingMessageCleared(actions, "/commit tool completion cleanup");
  const prematureRestore = actions.find(action => action[0] === "setActiveTools");
  if (prematureRestore) {
    fail(`/commit tool completion restored active tools before turn_end: ${JSON.stringify(actions)}`);
  }
  if (activeTools.join(",") !== "omp_commit") {
    fail(`/commit tool completion exposed previous active tools mid-turn: ${JSON.stringify(activeTools)}`);
  }
  actions.length = 0;
  await turnEndHandler();
  const restoredAfterCompletion = actions.find(action => action[0] === "setActiveTools");
  if (!restoredAfterCompletion || restoredAfterCompletion[1].join(",") !== "read,bash") {
    fail(`commit command did not restore previous active tools after tool completion turn_end: ${JSON.stringify(actions)}`);
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
assertCompactCallTeaser(callRendered, "single commit call", { expectedFiles: 1 });
assertStaticRender(callRendered, callRerendered, "single commit call");
for (const unexpected of ["exercise compact", "current session", "test_commit_ui_extension.sh"]) {
  assertExcludes(callRendered, unexpected, "single commit call details");
}
assertNotMatches(callRendered, /\b(?:insertions?|deletions?|changed|stats?|subjects?|preview|push after)\b|[+-]\d+\b/i, "single commit call stale details");
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
assertCompactCallTeaser(groupedCallRendered, "split commit call", { expectedFiles: 2 });
assertStaticRender(groupedCallRendered, groupedCallRerendered, "split commit call");
for (const unexpected of ["split alpha", "split beta", "alpha.txt", "beta.txt", "split"]) {
  assertExcludes(groupedCallRendered, unexpected, "split commit call details");
}
assertNotMatches(groupedCallRendered, /\b\d+\s+commits?\b|\bsplit\b|\b(?:subjects?|insertions?|deletions?|changed|stats?|preview|push after)\b|[+-]\d+\b/i, "split commit call stale details");
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
    steps: [
      { key: "plan", label: "Plan", status: "done" },
      { key: "tree", label: "Tree", status: "running" },
      { key: "stage", label: "Stage", status: "pending" },
      { key: "commit", label: "Commit", status: "pending" },
    ],
    warnings: [],
  },
};
const runningRendered = renderResult(runningResult, 54, "running result", { isPartial: true, spinnerFrame: 2 });
const runningRerendered = renderResult(runningResult, 54, "running result rerender", { isPartial: true, spinnerFrame: 3 });
assertBoxed(runningRendered, "running result");
if (runningRendered === runningRerendered) fail(`running result did not animate between spinner frames: ${runningRendered}`);
const runningActivity = liveActivityRow(runningRendered, /Inspecting working tree/i, "running result");
const rerenderedRunningActivity = liveActivityRow(runningRerendered, /Inspecting working tree/i, "running result rerender");
if (runningActivity === rerenderedRunningActivity) {
  fail(`running result live activity/detail row did not animate between spinner frames: ${JSON.stringify({ runningActivity, rerenderedRunningActivity })}`);
}
const runningProgress = assertVisibleProgress(runningRendered, "running result");
assertMatches(runningRendered, /1\/4\s+steps|✓\s*Plan/i, "running result partial progress");
assertMatches(runningRendered, /Inspecting working tree|running|[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]\s*Tree/i, "running result live label");
if (runningProgress.filled >= runningProgress.total) fail(`running result progress should be partial, not full: ${JSON.stringify(runningProgress)}\n${runningRendered}`);
assertNoLegacyUi(runningRendered, "running result");

const pendingSelectionResult = {
  content: [{ type: "text", text: "Scanning working tree" }],
  details: {
    id: "render-pending-selection",
    status: "running",
    phase: "Scanning working tree",
    dryRun: true,
    push: false,
    selectedFiles: [],
    ignoredFiles: [],
    commits: [{ status: "pending", requestedFiles: ["src/pending-selection.ts"], selectedFiles: [], message: "render scan" }],
    steps: [
      { key: "plan", label: "Plan", status: "running" },
      { key: "tree", label: "Tree", status: "pending" },
      { key: "stage", label: "Stage", status: "pending" },
      { key: "commit", label: "Commit", status: "pending" },
    ],
    warnings: [],
  },
};
const pendingSelectionRendered = renderResult(pendingSelectionResult, 54, "pending selection result", { isPartial: true, spinnerFrame: 4 });
assertBoxed(pendingSelectionRendered, "pending selection result");
liveActivityRow(pendingSelectionRendered, /Scanning working tree/i, "pending selection result");
assertPendingSelectionSignal(pendingSelectionRendered, "pending selection result");
assertVisibleProgress(pendingSelectionRendered, "pending selection result");

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
const completedProgress = assertVisibleProgress(completedRendered, "completed result");
if (completedProgress.filled !== completedProgress.total) fail(`completed result progress should be full: ${JSON.stringify(completedProgress)}\n${completedRendered}`);
if (runningProgress.ratio >= completedProgress.ratio) fail(`running progress should be less complete than finished progress: ${JSON.stringify({ runningProgress, completedProgress })}`);
assertMatches(completedRendered, /✓/, "completed result visible success checkmark");
assertMatches(completedRendered, /Commit preview complete|Outcome|succeeded|success/i, "completed result success status");
assertMatches(completedRendered, /stale-file|warnings?|ignored/i, "completed result warnings and ignored files");
assertNoLegacyUi(completedRendered, "completed result");

const collapsedLeftOutRendered = renderResult(
  {
    content: [{ type: "text", text: "Commit preview complete." }],
    details: {
      id: "render-left-out-collapse",
      status: "succeeded",
      phase: "Commit preview complete",
      dryRun: true,
      push: false,
      selectedFiles: ["kept-file-with-a-long-name.txt"],
      ignoredFiles: [
        "ignored/generated-artifact-with-a-very-long-name-one.txt",
        "ignored/generated-artifact-with-a-very-long-name-two.txt",
        "ignored/generated-artifact-with-a-very-long-name-three.txt",
      ],
      warnings: [],
      commits: [{ status: "succeeded", selectedFiles: ["kept-file-with-a-long-name.txt"], message: "preview compact card" }],
      finalText: "Commit preview complete.",
    },
  },
  54,
  "collapsed left out result",
);
assertBoxed(collapsedLeftOutRendered, "collapsed left out result");
assertCollapsedLeftOut(collapsedLeftOutRendered, 54, "collapsed left out result");
assertNoLegacyUi(collapsedLeftOutRendered, "collapsed left out result");

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
  assertLiveUpdateSnapshots(updates, selected, "selected-file commit");
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

  const invalidMessageRepo = await makeRepo("invalid-message-");
  await writeFile(join(invalidMessageRepo, "invalid-message.txt"), "invalid message\n");
  const invalidMessage = [
    "this is not conventional and it is intentionally much longer than fifty characters",
    "",
    "This body line is intentionally much longer than seventy-two characters and should be rejected before staging.",
  ].join("\n");
  const invalidMessageHead = (await git(invalidMessageRepo, ["rev-parse", "HEAD"])).stdout.trim();
  const invalid = await execute(invalidMessageRepo, "reject-non-conventional-message", {
    files: ["invalid-message.txt"],
    message: invalidMessage,
    dryRun: false,
    push: false,
  });
  assertError(invalid, /commit message|conventional|type\(scope\)|subject|body|50|72/i, "non-conforming message");
  const invalidMessageHeadAfter = (await git(invalidMessageRepo, ["rev-parse", "HEAD"])).stdout.trim();
  if (invalidMessageHeadAfter !== invalidMessageHead) fail("non-conforming message created a commit");
  const invalidMessageStatus = (await git(invalidMessageRepo, ["status", "--porcelain"])).stdout.trim();
  if (invalidMessageStatus !== "?? invalid-message.txt") {
    fail(`non-conforming message should be rejected before staging: ${invalidMessageStatus}`);
  }

  const formattedBodyRepo = await makeRepo("formatted-body-");
  await writeFile(join(formattedBodyRepo, "formatted-body.txt"), "formatted body\n");
  const formattedBodyMessage = [
    "fix(test): preserve commit body",
    "",
    "Body lines stay wrapped at seventy-two chars and remain untouched today.",
    "Formatting remains exactly as supplied by the direct tool call.",
  ].join("\n");
  if (
    formattedBodyMessage.split("\n")[0].length > 50 ||
    formattedBodyMessage.split("\n").slice(2).some(line => line.length > 72)
  ) {
    fail("valid conventional body fixture exceeds commit convention");
  }
  const formattedBody = await execute(formattedBodyRepo, "valid-conventional-body", {
    files: ["formatted-body.txt"],
    message: formattedBodyMessage,
    dryRun: false,
    push: false,
  });
  assertSucceeded(formattedBody, "valid conventional body message");
  const loggedFormattedBodyMessage = (await git(formattedBodyRepo, ["log", "-1", "--pretty=%B"])).stdout.trimEnd();
  if (loggedFormattedBodyMessage !== formattedBodyMessage) {
    fail(`valid conventional body message was not preserved: ${JSON.stringify({ loggedFormattedBodyMessage, formattedBodyMessage, details: formattedBody.details })}`);
  }

  const legacyRepo = await makeRepo("legacy-metadata-");
  await mkdir(join(legacyRepo, "scripts"), { recursive: true });
  const verifier = join(legacyRepo, "scripts", "should-not-run.sh");
  await writeFile(verifier, "#!/bin/sh\necho ran > verification-ran.txt\nexit 42\n");
  await chmod(verifier, 0o755);
  await writeFile(join(legacyRepo, "legacy.txt"), "legacy metadata\n");
  const legacy = await execute(legacyRepo, "legacy-metadata-ignored", {
    files: ["legacy.txt"],
    commitMessage: "chore(test): ignore legacy metadata",
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

  const privateKeyRepo = await makeRepo("private-key-");
  const privateKeyBlock = [
    "-----BEGIN OPENSSH PRIVATE KEY-----",
    "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW",
    "QyNTUxOQAAACBfakeFixturePrivateKeyMaterialOnlyForPatternCoverage",
    "-----END OPENSSH PRIVATE KEY-----",
  ].join("\n");
  await writeFile(join(privateKeyRepo, "id_ed25519"), `${privateKeyBlock}\n`);
  const privateKeyHead = (await git(privateKeyRepo, ["rev-parse", "HEAD"])).stdout.trim();
  const privateKey = await execute(privateKeyRepo, "selected-private-key-block", {
    files: ["id_ed25519"],
    commitMessage: "chore(test): block selected private key",
    dryRun: false,
    push: false,
  });
  if (!privateKey?.isError) fail(`selected private key content should block the commit: ${JSON.stringify(privateKey)}`);
  const privateKeyHeadAfter = (await git(privateKeyRepo, ["rev-parse", "HEAD"])).stdout.trim();
  if (privateKeyHeadAfter !== privateKeyHead) fail("selected private key content created a commit");
  const privateKeyOutput = `${textOf(privateKey)}\n${JSON.stringify(privateKey.details ?? {})}`;
  assertMatches(privateKeyOutput, /private key|secret|credential|sensitive/i, "selected private key block error");
  assertExcludes(privateKeyOutput, "fakeFixturePrivateKeyMaterialOnlyForPatternCoverage", "selected private key block output");

  const tokenRepo = await makeRepo("token-warning-");
  const tokenValue = ["sk", "proj", "test", "x".repeat(32)].join("-");
  await writeFile(join(tokenRepo, "token-warning.ts"), `export const apiKey = "${tokenValue}";\n`);
  const tokenWarning = await execute(tokenRepo, "selected-token-warning", {
    files: ["token-warning.ts"],
    commitMessage: "chore(test): allow selected token-shaped fixture",
    dryRun: false,
    push: false,
  });
  assertSucceeded(tokenWarning, "selected token-shaped content");
  if (!hashOf(tokenWarning)) fail(`selected token-shaped content did not create a commit: ${JSON.stringify(tokenWarning.details)}`);
  await assertCommittedFiles(tokenRepo, ["HEAD^", "HEAD"], ["token-warning.ts"], "selected token-shaped content commit");
  const tokenWarnings = warningsOf(tokenWarning);
  if (!tokenWarnings.some(warning => /token|secret|credential|sensitive/i.test(warning))) {
    fail(`selected token-shaped content warning missing: ${JSON.stringify(tokenWarnings)}`);
  }
  const tokenRendered = renderResult(tokenWarning, 90, "selected token-shaped result", { expanded: true });
  const tokenOutput = `${JSON.stringify(tokenWarning)}\n${tokenRendered}`;
  assertExcludes(tokenOutput, tokenValue, "selected token-shaped content output");
  if (/secret findings/i.test(tokenOutput)) fail(`selected token-shaped content used old secret findings UI: ${tokenOutput}`);
  if (Array.isArray(tokenWarning.details?.secretFindings) && tokenWarning.details.secretFindings.length > 0) {
    fail(`selected token-shaped content should not report blocking secret findings: ${JSON.stringify(tokenWarning.details.secretFindings)}`);
  }
} finally {
  await Promise.all(tempPaths.map(path => rm(path, { recursive: true, force: true })));
}
TS
