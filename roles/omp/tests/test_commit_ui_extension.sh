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
const schema = () => ({
  optional() { return this; },
  describe() { return this; },
});
const zod = {
  string: schema,
  boolean: schema,
  object: schema,
  array: schema,
};
const api = {
  zod,
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
const inputHandler = calls.find(call => call[0] === "event" && call[1] === "input")?.[2];
if (!inputHandler) throw new Error("natural language commit input handler was not registered");
const turnEndHandler = calls.find(call => call[0] === "event" && call[1] === "turn_end")?.[2];
if (!turnEndHandler) throw new Error("turn_end restore handler was not registered");

const promptHome = await mkdtemp(join(tmpdir(), "omp-commit-ui-home-"));
const originalHome = process.env.HOME;
try {
  await mkdir(join(promptHome, ".omp", "agent", "skills", "commit"), { recursive: true });
  await writeFile(join(promptHome, ".omp", "agent", "skills", "commit", "SKILL.md"), "HOME_SKILL_SENTINEL: deployed skill text\n");
  process.env.HOME = promptHome;
  const idleCtx = {
    isIdle: () => true,
    waitForIdle: async () => {},
    ui: { notify: (...args) => actions.push(["notify", ...args]) },
  };

  await command.handler("--dry-run --push --accept-risk --model test-model quoted context", idleCtx);
  const setActiveTools = actions.find(action => action[0] === "setActiveTools");
  if (!setActiveTools || setActiveTools[1][0] !== "omp_commit") {
    throw new Error(`commit command did not isolate active tools: ${JSON.stringify(actions)}`);
  }
  const sentMessage = actions.find(action => action[0] === "sendMessage");
  if (!sentMessage) throw new Error("commit command did not send a hidden tool prompt");
  if (sentMessage[1].display !== false) throw new Error("commit command prompt should be hidden");
  if (sentMessage[2].deliverAs !== "nextTurn") throw new Error("commit command should deliver hidden prompt as next turn");
  for (const expected of ["omp_commit", "existing conversation context", "nested omp process", "test-model", "HOME_SKILL_SENTINEL", "50 characters", "72 characters"]) {
    if (!sentMessage[1].content.includes(expected)) throw new Error(`commit prompt missing ${expected}`);
  }
  if (sentMessage[1].details.multiCommit !== false) throw new Error(`plain commit command should not request multiple commits: ${JSON.stringify(sentMessage[1].details)}`);

  if (sentMessage[1].content.includes('"commits"')) throw new Error("plain commit prompt should not show commits array schema");
  if (!sentMessage[1].content.includes("omit files") || !sentMessage[1].content.includes("files: []") || !sentMessage[1].content.includes("git status")) {
    throw new Error("plain commit prompt should document status-derived file selection");
  }

  await command.handler("--dry-run", idleCtx);
  const duplicateMessages = actions.filter(action => action[0] === "sendMessage");
  if (duplicateMessages.length !== 1) throw new Error(`duplicate commit command queued another prompt: ${JSON.stringify(actions)}`);
  if (!actions.some(action => action[0] === "notify" && String(action[1]).includes("already running"))) {
    throw new Error(`duplicate commit command did not warn while workflow was active: ${JSON.stringify(actions)}`);
  }

  await turnEndHandler();
  actions.length = 0;

  await command.handler("everything and push", idleCtx);
  const slashPushMessage = actions.find(action => action[0] === "sendMessage");
  if (!slashPushMessage) throw new Error("slash commit push request did not send a hidden tool prompt");
  if (slashPushMessage[1].details.push !== true) throw new Error(`slash commit request did not infer push from prose: ${JSON.stringify(slashPushMessage[1].details)}`);

  await turnEndHandler();
  actions.length = 0;

  await command.handler("atomic commits until everything is committed", idleCtx);
  const atomicMessage = actions.find(action => action[0] === "sendMessage");
  if (!atomicMessage) throw new Error("atomic commit request did not send a hidden tool prompt");
  if (atomicMessage[1].details.multiCommit !== true) throw new Error(`atomic commit request did not enable multi-commit mode: ${JSON.stringify(atomicMessage[1].details)}`);
  if (!atomicMessage[1].content.includes("commits array")) throw new Error("atomic commit prompt did not require grouped commits array");
  if (!atomicMessage[1].content.includes("exactly once")) throw new Error("atomic commit prompt should keep one tool call");
  if (!atomicMessage[1].content.includes("exact files") || !atomicMessage[1].content.includes("Empty files in a split entry blocks")) {
    throw new Error("atomic commit prompt should require exact files and block empty split entries");
  }
  if (atomicMessage[1].content.includes("once per atomic commit")) throw new Error("atomic commit prompt should not request separate tool calls");


  await turnEndHandler();
  actions.length = 0;

  const naturalResult = await inputHandler(
    { type: "input", text: "let's go ahead and commit these changes and push", source: "interactive" },
    idleCtx,
  );
  if (!naturalResult?.handled) throw new Error(`natural language commit request was not handled: ${JSON.stringify(naturalResult)}`);
  const naturalSetActiveTools = actions.find(action => action[0] === "setActiveTools");
  if (!naturalSetActiveTools || naturalSetActiveTools[1][0] !== "omp_commit") {
    throw new Error(`natural language commit request did not isolate active tools: ${JSON.stringify(actions)}`);
  }
  const naturalMessage = actions.find(action => action[0] === "sendMessage");
  if (!naturalMessage) throw new Error("natural language commit request did not send a hidden tool prompt");
  if (!naturalMessage[1].content.includes("natural language")) throw new Error("natural language prompt did not identify its trigger source");
  if (naturalMessage[1].details.push !== true) throw new Error(`natural language commit request did not infer push: ${JSON.stringify(naturalMessage[1].details)}`);
  if (!naturalMessage[1].details.context.includes("go ahead and commit")) throw new Error(`natural language commit request lost context: ${JSON.stringify(naturalMessage[1].details)}`);

  await turnEndHandler();
  actions.length = 0;

  const messageOnlyResult = await inputHandler(
    { type: "input", text: "draft a commit message for this change", source: "interactive" },
    idleCtx,
  );
  if (messageOnlyResult?.handled) throw new Error("commit-message-only request should not trigger commit workflow");
  if (actions.length !== 0) throw new Error(`commit-message-only request unexpectedly mutated extension state: ${JSON.stringify(actions)}`);

  const discussionResult = await inputHandler(
    { type: "input", text: "I want to review my omp commit extension because waiting to make a commit was too slow; if I say /commit everything and push the extension doesn't push.", source: "interactive" },
    idleCtx,
  );
  if (discussionResult?.handled) throw new Error("commit workflow discussion should not trigger a commit request");
  if (actions.length !== 0) throw new Error(`commit workflow discussion unexpectedly mutated extension state: ${JSON.stringify(actions)}`);
} finally {
  if (originalHome === undefined) {
    delete process.env.HOME;
  } else {
    process.env.HOME = originalHome;
  }
  await rm(promptHome, { recursive: true, force: true });
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

function assertRenderedIncludes(rendered, label, expected) {
  if (!rendered.includes(expected)) throw new Error(`${label} render missing ${expected}: ${rendered}`);
}

function assertRenderedMatches(rendered, label, pattern, fact) {
  if (!pattern.test(rendered)) throw new Error(`${label} render missing ${fact}: ${rendered}`);
}

function assertRenderedExcludes(rendered, label, unexpected) {
  if (rendered.includes(unexpected)) throw new Error(`${label} render should not include ${unexpected}: ${rendered}`);
}

function assertWorkflowRail(rendered, label, expectedSteps) {
  assertRenderedMatches(rendered, label, /Progress|Checklist|[✓✔●•✖✗]/i, "workflow rail");
  for (const step of expectedSteps) {
    assertRenderedMatches(rendered, label, new RegExp(`\\b${step}\\b`, "i"), `${step} workflow step`);
  }
}

function assertStatsChips(rendered, label, expectedStats) {
  assertRenderedMatches(rendered, label, /Stats/i, "stats section");
  for (const [fact, pattern] of expectedStats) {
    assertRenderedMatches(rendered, label, pattern, `${fact} stats chip`);
  }
}

function assertCommitOverview(rendered, label, expected) {
  assertRenderedMatches(rendered, label, /Commits?/i, "commit overview");
  for (const value of expected) {
    assertRenderedIncludes(rendered, label, value);
  }
}

function step(label, status = "done") {
  return { label, status, startedAt: Date.now(), finishedAt: status === "running" ? undefined : Date.now() };
}

function assertBoxedCard(rendered, label) {
  assertRenderedMatches(rendered, label, /[┌┏╭╔╒╓]/, "top border");
  assertRenderedMatches(rendered, label, /[└┗╰╚╘╙]/, "bottom border");
}

function assertNoLineExceeds(lines, width, label) {
  if (lines.some(line => line.length > width)) {
    throw new Error(`${label} render exceeded terminal width: ${lines.join("\n")}`);
  }
}
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
  assertRenderedIncludes(callRendered, "call", expected);
}

const atomicCallComponent = tool.renderCall(
  {
    multiCommit: true,
    commits: [
      {
        files: ["alpha.txt"],
        commitMessage: "feat(test): add alpha fixture",
        rationale: "alpha change",
        verificationEvidence: [{ description: "alpha reviewed", source: "observed" }],
      },
      {
        files: ["beta.txt"],
        commitMessage: "fix(test): add beta fixture",
        rationale: "beta change",
        verificationEvidence: [{ description: "beta reviewed", source: "observed" }],
      },
    ],
  },
  {},
  theme,
);
const atomicCallRendered = atomicCallComponent.render(160).join("\n");
for (const expected of ["2 files", "feat(test): add alpha fixture", "fix(test): add beta fixture"]) {
  assertRenderedIncludes(atomicCallRendered, "grouped call", expected);
}
assertRenderedMatches(atomicCallRendered, "grouped call", /Commit group|Commits?/i, "grouped commit label");
assertRenderedMatches(atomicCallRendered, "grouped call", /2\s+split commits?|split\s+2|commits?\s+2|2\s+commits?/i, "split commit count");

const resultComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "Reviewing selected diff" }],
    details: {
      id: "commit-test",
      status: "running",
      phase: "Reviewing selected diff",
      startedAt: Date.now(),
      steps: [
        step("Validating commit plan"),
        step("Inspecting working tree"),
        step("Reviewing selected diff", "running"),
      ],
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

const wrappedResultComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "Commit preview complete" }],
    details: {
      id: "commit-wrap-render-test",
      status: "succeeded",
      phase: "Commit preview complete after reviewing selected diff and verification evidence",
      startedAt: Date.now(),
      finishedAt: Date.now(),
      steps: [
        step("Validating commit plan"),
        step("Inspecting working tree"),
        step("Reviewing selected diff"),
        step("Checking for secrets"),
        step("Running verification: commit UI wraps rationale verification and file lists"),
      ],
      toolCount: 3,
      failedToolCount: 0,
      dryRun: true,
      push: false,
      acceptRisk: false,
      commitMessage: "chore(test): wrap commit UI fields in narrow terminals",
      rationale: "Compact rationale should wrap across narrow terminals without terminal-edge truncation.",
      selectedFiles: ["roles/omp/files/extensions/commit-ui.ts", "roles/omp/tests/test_commit_ui_extension.sh"],
      ignoredFiles: ["roles/omp/tests/unrelated-fixture.txt"],
      verificationCount: 0,
      verificationEvidence: ["observed: wrap regression reviewed without terminal-edge truncation"],
      finalText: "Commit preview complete.\nFiles: roles/omp/files/extensions/commit-ui.ts, roles/omp/tests/test_commit_ui_extension.sh",
      warnings: ["wrap warning fixture"],
    },
  },
  { expanded: false, isPartial: false, spinnerFrame: 0 },
  theme,
);
const wrappedResultLines = wrappedResultComponent.render(54);
assertNoLineExceeds(wrappedResultLines, 54, "wrapped result");
const wrappedResultRendered = wrappedResultLines.join("\n");
assertBoxedCard(wrappedResultRendered, "wrapped result");
assertWorkflowRail(wrappedResultRendered, "wrapped result", ["plan", "tree", "diff", "secrets", "verify"]);
assertStatsChips(wrappedResultRendered, "wrapped result", [
  ["file count", /files?\D+2|2 files?/i],
  ["ignored count", /ignored\D+1|1 ignored/i],
  ["verification", /verify|verification|evidence/i],
  ["push", /push/i],
  ["warning count", /warnings?\D+1|1 warnings?/i],
]);
for (const expected of ["Ignored", "Outcome", "Commit preview complete", "unrelated-fixture.txt", "wrap warning fixture"]) {
  assertRenderedIncludes(wrappedResultRendered, "wrapped result", expected);
}
assertRenderedExcludes(wrappedResultRendered, "wrapped result", "Result");
assertBoxedCard(resultRendered, "single result");
assertWorkflowRail(resultRendered, "single result", ["plan", "tree", "diff"]);
assertStatsChips(resultRendered, "single result", [
  ["file count", /files?\D+1|1 file/i],
  ["ignored count", /ignored\D+1|1 ignored/i],
  ["verification", /verify|verification|evidence/i],
]);
for (const expected of ["Commit preview", "Reviewing selected diff", "included.txt", "unrelated.txt"]) {
  assertRenderedIncludes(resultRendered, "single result", expected);
}

const atomicResultComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "2 commits created" }],
    details: {
      id: "commit-atomic-render-test",
      status: "succeeded",
      phase: "2 commits created",
      startedAt: Date.now(),
      finishedAt: Date.now(),
      steps: [
        step("Validating commit plan"),
        step("Inspecting working tree"),
        step("Reviewing selected diff"),
        step("Checking for secrets"),
        step("Running verification"),
        step("Staging selected changes"),
        step("Creating commit"),
        step("Checking commit result"),
        step("Pushing branch"),
      ],
      toolCount: 6,
      failedToolCount: 0,
      dryRun: false,
      push: true,
      acceptRisk: false,
      multiCommit: true,
      selectedFiles: ["alpha.txt", "beta.txt"],
      ignoredFiles: [],
      verificationCount: 0,
      verificationEvidence: ["observed: alpha reviewed", "observed: beta reviewed"],
      commits: [
        {
          commitMessage: "feat(test): add alpha fixture",
          selectedFiles: ["alpha.txt"],
          verificationCount: 0,
          verificationEvidence: ["observed: alpha reviewed"],
          acceptRisk: false,
          commitHash: "abc1234",
        },
        {
          commitMessage: "fix(test): add beta fixture",
          selectedFiles: ["beta.txt"],
          verificationCount: 0,
          verificationEvidence: ["observed: beta reviewed"],
          acceptRisk: false,
          commitHash: "def5678",
        },
      ],
      warnings: [],
    },
  },
  { expanded: false, isPartial: false, spinnerFrame: 0 },
  theme,
);
const atomicResultRendered = atomicResultComponent.render(160).join("\n");
assertBoxedCard(atomicResultRendered, "grouped result");
assertWorkflowRail(atomicResultRendered, "grouped result", ["plan", "tree", "diff", "secrets", "verify", "stage", "commit", "hash", "push"]);
assertStatsChips(atomicResultRendered, "grouped result", [
  ["commit count", /commits?\D+2|2 commits?/i],
  ["file count", /files?\D+2|2 files?/i],
  ["verification", /verify|verification|evidence/i],
  ["hash", /hash|abc1234|def5678/i],
  ["push", /push/i],
]);
assertCommitOverview(atomicResultRendered, "grouped result", ["abc1234", "def5678", "feat(test): add alpha fixture", "fix(test): add beta fixture"]);
assertRenderedIncludes(atomicResultRendered, "grouped result", "2 commits created");
assertRenderedIncludes(atomicResultRendered, "grouped result", "Outcome");
assertRenderedExcludes(atomicResultRendered, "grouped result", "Result");
assertRenderedMatches(atomicResultRendered, "grouped result", /✔|✓/, "success status icon");
assertRenderedMatches(atomicResultRendered, "grouped result", /2\s+split commits?|split\s+2|commits?\s+2|2\s+commits?/i, "split commit count");
assertRenderedMatches(atomicResultRendered, "grouped result", /(^|\n).*1(?:\/2|\b).*feat\(test\): add alpha fixture/i, "first commit row");
assertRenderedMatches(atomicResultRendered, "grouped result", /(^|\n).*2(?:\/2|\b).*fix\(test\): add beta fixture/i, "second commit row");
assertRenderedMatches(atomicResultRendered, "grouped result", /files?\s+1|1 file/i, "per-commit file count");

const groupedRunningComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "Commit 2/2: creating commit" }],
    details: {
      id: "commit-group-running-render-test",
      status: "running",
      phase: "Commit 2/2: creating commit",
      startedAt: Date.now(),
      steps: [
        step("Validating commit plan"),
        step("Inspecting working tree"),
        step("Reviewing selected diff"),
        step("Checking for secrets"),
        step("Running verification"),
        step("Staging selected changes"),
        step("Commit 2/2: Creating commit", "running"),
      ],
      toolCount: 5,
      failedToolCount: 0,
      dryRun: false,
      push: false,
      acceptRisk: false,
      multiCommit: true,
      selectedFiles: ["alpha.txt", "beta.txt"],
      ignoredFiles: [],
      verificationCount: 0,
      verificationEvidence: ["observed: alpha reviewed", "observed: beta reviewed"],
      commits: [
        {
          commitMessage: "feat(test): add alpha fixture",
          selectedFiles: ["alpha.txt"],
          verificationCount: 0,
          verificationEvidence: ["observed: alpha reviewed"],
          acceptRisk: false,
          commitHash: "abc1234",
          status: "succeeded",
        },
        {
          commitMessage: "fix(test): add beta fixture",
          selectedFiles: ["beta.txt"],
          verificationCount: 0,
          verificationEvidence: ["observed: beta reviewed"],
          acceptRisk: false,
          status: "running",
          phase: "Creating commit",
        },
      ],
      warnings: [],
    },
  },
  { expanded: false, isPartial: true, spinnerFrame: 1 },
  theme,
);
const groupedRunningRendered = groupedRunningComponent.render(160).join("\n");
assertBoxedCard(groupedRunningRendered, "grouped running");
assertWorkflowRail(groupedRunningRendered, "grouped running", ["plan", "tree", "diff", "secrets", "verify", "stage", "commit"]);
assertStatsChips(groupedRunningRendered, "grouped running", [
  ["commit count", /commits?\D+2|2 commits?/i],
  ["file count", /files?\D+2|2 files?/i],
  ["verification", /verify|verification|evidence/i],
  ["push", /push/i],
]);
assertCommitOverview(groupedRunningRendered, "grouped running", ["Commit 2/2", "Creating commit", "abc1234", "fix(test): add beta fixture"]);
assertRenderedMatches(groupedRunningRendered, "grouped running", /[●•⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]|running/i, "active spinner");
assertRenderedMatches(groupedRunningRendered, "grouped running", /pending|running/i, "pending commit state");
assertRenderedMatches(groupedRunningRendered, "grouped running", /2\s+split commits?|split\s+2|commits?\s+2|2\s+commits?/i, "split commit count");
assertRenderedMatches(groupedRunningRendered, "grouped running", /files?\s+1|1 file/i, "per-commit file count");

const groupedFailedComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "Commit workflow blocked" }],
    details: {
      id: "commit-group-failed-render-test",
      status: "failed",
      phase: "Commit workflow blocked",
      startedAt: Date.now(),
      finishedAt: Date.now(),
      steps: [
        step("Validating commit plan"),
        step("Inspecting working tree"),
        step("Reviewing selected diff"),
        step("Checking for secrets"),
        step("Running verification"),
        step("Staging selected changes"),
        step("Commit 2/2: Creating commit", "failed"),
      ],
      toolCount: 7,
      failedToolCount: 1,
      dryRun: false,
      push: false,
      acceptRisk: false,
      multiCommit: true,
      selectedFiles: ["alpha.txt", "beta.txt"],
      ignoredFiles: [],
      verificationCount: 0,
      verificationEvidence: [],
      errorText: "git commit failed",
      commits: [
        {
          commitMessage: "feat(test): add alpha fixture",
          selectedFiles: ["alpha.txt"],
          verificationCount: 0,
          verificationEvidence: [],
          acceptRisk: false,
          commitHash: "abc1234",
          status: "succeeded",
        },
        {
          commitMessage: "fix(test): add beta fixture",
          selectedFiles: ["beta.txt"],
          verificationCount: 0,
          verificationEvidence: [],
          acceptRisk: false,
          status: "failed",
          phase: "Creating commit",
          errorText: "git commit failed",
        },
      ],
      warnings: [],
    },
  },
  { expanded: false, isPartial: false, spinnerFrame: 0 },
  theme,
);
const groupedFailedRendered = groupedFailedComponent.render(160).join("\n");
assertBoxedCard(groupedFailedRendered, "grouped failed");
assertWorkflowRail(groupedFailedRendered, "grouped failed", ["plan", "tree", "diff", "secrets", "verify", "stage", "commit"]);
assertStatsChips(groupedFailedRendered, "grouped failed", [
  ["commit count", /commits?\D+2|2 commits?/i],
  ["file count", /files?\D+2|2 files?/i],
  ["verification", /verify|verification|evidence/i],
  ["push", /push/i],
]);
assertCommitOverview(groupedFailedRendered, "grouped failed", ["Blocked", "Already created", "abc1234", "feat(test): add alpha fixture", "git commit failed", "partially complete"]);
assertRenderedMatches(groupedFailedRendered, "grouped failed", /✖|✗/, "failed status icon");
assertRenderedMatches(groupedFailedRendered, "grouped failed", /2\s+split commits?|split\s+2|commits?\s+2|2\s+commits?/i, "split commit count");
assertRenderedMatches(groupedFailedRendered, "grouped failed", /files?\s+1|1 file/i, "per-commit file count");
for (const rendered of [callRendered, atomicCallRendered, resultRendered, wrappedResultRendered, atomicResultRendered, groupedRunningRendered, groupedFailedRendered]) {
  if (/\batomic\b/i.test(rendered)) throw new Error(`rendered UI should not say atomic: ${rendered}`);
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

function assertSamePathSet(actual, expected, label) {
  const actualSorted = [...actual].sort();
  const expectedSorted = [...expected].sort();
  if (actualSorted.length !== expectedSorted.length || actualSorted.some((file, index) => file !== expectedSorted[index])) {
    throw new Error(`${label} mismatch: ${JSON.stringify({ actual, expected })}`);
  }
}

function assertCommitMessageLimits(message, label) {
  const lines = message.split("\n");
  if ((lines[0] ?? "").length > 50) throw new Error(`${label} subject is too long: ${JSON.stringify(lines[0])}`);
  for (const [index, line] of lines.slice(2).entries()) {
    if (line.length > 72) throw new Error(`${label} body line ${index + 3} is too long: ${JSON.stringify(line)}`);
  }
}

const tmp = await mkdtemp(join(tmpdir(), "omp-commit-ui-test-"));
const remote = await mkdtemp(join(tmpdir(), "omp-commit-ui-remote-"));
try {
  await git(tmp, ["init"]);
  await git(tmp, ["config", "user.email", "commit-ui-test@example.invalid"]);
  await git(tmp, ["config", "user.name", "Commit UI Test"]);
  await writeFile(join(tmp, "included.txt"), "old\n");
  await git(tmp, ["add", "included.txt"]);
  await git(tmp, ["commit", "-m", "chore(test): initial fixture"]);
  await git(remote, ["init", "--bare"]);
  await git(tmp, ["remote", "add", "origin", remote]);
  await git(tmp, ["push", "-u", "origin", "HEAD"]);

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
  if (result.details.commits[0].status !== "succeeded") throw new Error(`single commit did not finish with succeeded UI state: ${JSON.stringify(result.details)}`);

  const committed = (await git(tmp, ["diff", "--name-only", "HEAD^", "HEAD"])).stdout.trim();
  if (committed !== "included.txt") throw new Error(`unexpected committed files: ${committed}`);
  const status = (await git(tmp, ["status", "--porcelain"])).stdout;
  if (!status.includes("?? unrelated.txt")) throw new Error(`unrelated file was not left untouched: ${status}`);

  await writeFile(join(tmp, "paragraph.txt"), "paragraph commit\n");
  const paragraphMessage = [
    "feat(test): preserve commit body",
    "",
    "First body paragraph explains the fixture.",
    "",
    "Second body paragraph confirms spacing survives.",
  ].join("\n");
  const paragraphCommit = await tool.execute(
    "commit-paragraph-test",
    {
      files: ["paragraph.txt"],
      commitMessage: paragraphMessage,
      rationale: "Exercise multi-paragraph commit messages.",
      verificationEvidence: [{ description: "paragraph fixture reviewed in test", source: "observed" }],
      dryRun: false,
      push: false,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (paragraphCommit.isError) throw new Error(`paragraph commit failed: ${JSON.stringify(paragraphCommit)}`);
  const paragraphLog = (await git(tmp, ["log", "-1", "--pretty=%B"])).stdout.trimEnd();
  if (paragraphLog !== paragraphMessage) throw new Error(`paragraph commit message was not preserved: ${JSON.stringify(paragraphLog)}`);

  await writeFile(join(tmp, "long-body.txt"), "long body commit\n");
  const longBodyMessage = [
    "fix(test): commit repaired body line",
    "",
    "This generated body line is intentionally much longer than seventy-two characters so deterministic wrapping can keep the helper happy.",
  ].join("\n");
  const longBodyCommit = await tool.execute(
    "commit-long-body-test",
    {
      files: ["long-body.txt"],
      commitMessage: longBodyMessage,
      rationale: "Exercise commit message repair in a real git commit.",
      verificationEvidence: [{ description: "long body fixture reviewed in test", source: "observed" }],
      dryRun: false,
      push: false,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (longBodyCommit.isError) throw new Error(`long body commit failed: ${JSON.stringify(longBodyCommit)}`);
  assertCommitMessageLimits(longBodyCommit.details.commitMessage, "committed repaired message");
  if (!longBodyCommit.content[0].text.includes(longBodyCommit.details.commitMessage)) throw new Error(`commit result did not show repaired message: ${JSON.stringify(longBodyCommit)}`);
  const longBodyLog = (await git(tmp, ["log", "-1", "--pretty=%B"])).stdout.trimEnd();
  if (longBodyLog !== longBodyCommit.details.commitMessage) throw new Error(`git commit did not use repaired message: ${JSON.stringify({ log: longBodyLog, details: longBodyCommit.details.commitMessage })}`);

  await writeFile(join(tmp, "validation.txt"), "validation fixture\n");
  const repairedPreview = await tool.execute(
    "commit-repaired-preview-test",
    {
      files: ["validation.txt"],
      commitMessage: [
        "feat(test): repair generated subject words that exceed helper limits cleanly",
        "",
        "This generated dry run body line is intentionally much longer than seventy-two characters so deterministic wrapping can keep the helper happy.",
      ].join("\n"),
      rationale: "Exercise subject and body repair before validation.",
      verificationEvidence: [{ description: "validation fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (repairedPreview.isError) throw new Error(`repaired preview failed: ${JSON.stringify(repairedPreview)}`);
  assertCommitMessageLimits(repairedPreview.details.commitMessage, "dry-run repaired message");
  const repairedPreviewLines = repairedPreview.details.commitMessage.split("\n");
  if (!repairedPreviewLines[0].startsWith("feat(test): ")) throw new Error(`repaired subject lost conventional prefix: ${JSON.stringify(repairedPreview.details.commitMessage)}`);
  if (!repairedPreviewLines.slice(2).join(" ").includes("exceed helper limits cleanly")) throw new Error(`subject overflow was not moved into the body: ${JSON.stringify(repairedPreview.details.commitMessage)}`);
  if (repairedPreview.details.commitMessage !== repairedPreview.details.commits[0].commitMessage) throw new Error(`repaired details diverged: ${JSON.stringify(repairedPreview.details)}`);
  if (!repairedPreview.content[0].text.includes(repairedPreview.details.commitMessage)) throw new Error(`dry-run result did not show repaired message: ${JSON.stringify(repairedPreview)}`);
  if (!repairedPreview.details.warnings.some(warning => warning.includes("commit message repaired"))) throw new Error(`repair warning missing: ${JSON.stringify(repairedPreview.details.warnings)}`);
  const bodyWithoutBlank = await tool.execute(
    "commit-body-without-blank-test",
    {
      files: ["validation.txt"],
      commitMessage: "feat(test): reject unseparated body\nBody starts without a blank second line.",
      rationale: "Exercise commit body separator validation.",
      verificationEvidence: [{ description: "validation fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (!bodyWithoutBlank.isError) throw new Error(`body without blank separator was accepted: ${JSON.stringify(bodyWithoutBlank)}`);


  await writeFile(join(tmp, "status-derived-a.txt"), "status derived a\n");
  await writeFile(join(tmp, "status-derived-b.txt"), "status derived b\n");
  const statusBeforeDerivedSelection = parseStatusPaths((await git(tmp, ["status", "--porcelain=v1", "-z", "--untracked-files=all"])).stdout);
  const statusDerivedPreview = await tool.execute(
    "commit-status-derived-files-test",
    {
      files: [],
      commitMessage: "chore(test): preview status derived files",
      rationale: "A single commit may intentionally include every current git status path.",
      verificationEvidence: [{ description: "status-derived fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (statusDerivedPreview.isError) throw new Error(`status-derived files preview failed: ${JSON.stringify(statusDerivedPreview)}`);
  assertSamePathSet(statusDerivedPreview.details.selectedFiles, statusBeforeDerivedSelection, "status-derived selected files");
  if (statusDerivedPreview.details.ignoredFiles.length !== 0) {
    throw new Error(`status-derived files should not ignore changed files: ${JSON.stringify(statusDerivedPreview.details)}`);
  }
  if (!statusDerivedPreview.details.warnings.some(warning => warning.includes("no files were supplied") && warning.includes("git status"))) {
    throw new Error(`status-derived warning missing: ${JSON.stringify(statusDerivedPreview.details.warnings)}`);
  }

  const omittedFilesPreview = await tool.execute(
    "commit-omitted-files-test",
    {
      commitMessage: "chore(test): preview omitted file selection",
      rationale: "Omitted files should behave like files: [] for a single status-derived commit.",
      verificationEvidence: [{ description: "omitted files fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (omittedFilesPreview.isError) throw new Error(`omitted files preview failed: ${JSON.stringify(omittedFilesPreview)}`);
  assertSamePathSet(omittedFilesPreview.details.selectedFiles, statusBeforeDerivedSelection, "omitted-files selected files");

  await writeFile(join(tmp, "stale-selection.txt"), "stale selection still changed\n");
  const staleSelectionPreview = await tool.execute(
    "commit-stale-selection-test",
    {
      files: ["stale-selection.txt", "missing-stale.txt", "included.txt"],
      commitMessage: "chore(test): preview stale file filtering",
      rationale: "Generated file lists may retain stale paths from an older model turn.",
      verificationEvidence: [{ description: "stale selection fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (staleSelectionPreview.isError) throw new Error(`stale selection preview failed: ${JSON.stringify(staleSelectionPreview)}`);
  if (staleSelectionPreview.details.selectedFiles.join(",") !== "stale-selection.txt") {
    throw new Error(`stale selection did not keep only changed matches: ${JSON.stringify(staleSelectionPreview.details)}`);
  }
  if (!staleSelectionPreview.details.warnings.some(warning => warning.includes("missing-stale.txt") && warning.includes("included.txt"))) {
    throw new Error(`stale selection warning missing stale paths: ${JSON.stringify(staleSelectionPreview.details.warnings)}`);
  }

  const allStaleSelection = await tool.execute(
    "commit-all-stale-selection-test",
    {
      files: ["missing-stale.txt", "included.txt"],
      commitMessage: "chore(test): block all stale file filtering",
      rationale: "A generated file list with no changed matches must still block.",
      verificationEvidence: [{ description: "all stale selection fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (!allStaleSelection.isError) throw new Error(`all stale selection was accepted: ${JSON.stringify(allStaleSelection)}`);
  if (!allStaleSelection.content[0].text.includes("requested files are not changed")) {
    throw new Error(`all stale selection did not preserve blocking error: ${JSON.stringify(allStaleSelection)}`);
  }

  await writeFile(join(tmp, "split-empty-block.txt"), "split empty guard\n");
  const splitEmptySelection = await tool.execute(
    "commit-split-empty-files-test",
    {
      multiCommit: true,
      commits: [
        {
          files: [],
          commitMessage: "chore(test): block empty split selection",
          rationale: "Split commits cannot infer membership from the whole status list.",
          verificationEvidence: [{ description: "empty split fixture reviewed in test", source: "observed" }],
        },
        {
          files: ["split-empty-block.txt"],
          commitMessage: "chore(test): preview split guard",
          rationale: "The second split has an explicit changed file.",
          verificationEvidence: [{ description: "split guard fixture reviewed in test", source: "observed" }],
        },
      ],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (!splitEmptySelection.isError) throw new Error(`empty split files were accepted: ${JSON.stringify(splitEmptySelection)}`);
  if (!splitEmptySelection.content[0].text.includes("no files were selected")) {
    throw new Error(`empty split files did not preserve blocking error: ${JSON.stringify(splitEmptySelection)}`);
  }

  await writeFile(join(tmp, "empty-commits.txt"), "single commit compatibility\n");
  const emptyCommitsArray = await tool.execute(
    "commit-empty-commits-array-test",
    {
      files: ["empty-commits.txt"],
      commitMessage: "chore(test): preview empty commits array fallback",
      rationale: "Single-commit tool calls may include an empty commits array from generated schemas.",
      verificationEvidence: [{ description: "empty commits array fixture reviewed in test", source: "observed" }],
      commits: [],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (emptyCommitsArray.isError) throw new Error(`empty commits array fallback failed: ${JSON.stringify(emptyCommitsArray)}`);
  if (!emptyCommitsArray.content[0].text.includes("Commit preview complete")) {
    throw new Error(`empty commits array fallback did not produce a preview: ${JSON.stringify(emptyCommitsArray)}`);
  }

  const blankCommitPlaceholder = await tool.execute(
    "commit-blank-commit-placeholder-test",
    {
      files: ["empty-commits.txt"],
      commitMessage: "chore(test): preview blank commits placeholder fallback",
      rationale: "Single-commit tool calls may include a blank generated commits entry.",
      verificationEvidence: [{ description: "blank commits placeholder fixture reviewed in test", source: "observed" }],
      commits: [
        {
          files: [],
          commitMessage: "",
          rationale: "",
          verification: [],
          verificationEvidence: [],
          acceptRisk: false,
        },
      ],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (blankCommitPlaceholder.isError) throw new Error(`blank commits placeholder fallback failed: ${JSON.stringify(blankCommitPlaceholder)}`);
  if (!blankCommitPlaceholder.content[0].text.includes("Commit preview complete")) {
    throw new Error(`blank commits placeholder fallback did not produce a preview: ${JSON.stringify(blankCommitPlaceholder)}`);
  }

  await writeFile(join(tmp, "push.txt"), "push me\n");
  const pushed = await tool.execute(
    "commit-push-test",
    {
      files: ["push.txt"],
      commitMessage: "chore(test): push fixture",
      rationale: "Exercise push after creating a commit.",
      verificationEvidence: [{ description: "push fixture reviewed in test", source: "observed" }],
      dryRun: false,
      push: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (pushed.isError) throw new Error(`push execution failed: ${JSON.stringify(pushed)}`);
  if (!pushed.content[0].text.includes("Pushed to remote.")) throw new Error(`push result missing success text: ${JSON.stringify(pushed)}`);
  const remoteHead = (await git(remote, ["rev-parse", "--short", "HEAD"])).stdout.trim();
  if (remoteHead !== pushed.details.commitHash) throw new Error(`push did not update remote HEAD: remote=${remoteHead} local=${pushed.details.commitHash}`);


  const evidencePreview = await tool.execute(
    "commit-evidence-test",
    {
      files: ["unrelated.txt"],
      commitMessage: "chore(test): preview prior verification evidence",
      rationale: "Exercise prior verification evidence without rerunning a command.",
      verificationEvidence: [{ description: "script check passed earlier", command: "./scripts/check.sh", args: ["--dry-run"], source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (evidencePreview.isError) throw new Error(`verification evidence preview failed: ${JSON.stringify(evidencePreview)}`);
  if (!evidencePreview.content[0].text.includes("Verification evidence: 1")) {
    throw new Error(`verification evidence was not reflected in result text: ${JSON.stringify(evidencePreview)}`);
  }
  if (!evidencePreview.details.warnings.some(warning => warning.includes("prior verification evidence"))) {
    throw new Error(`verification evidence warning was not recorded: ${JSON.stringify(evidencePreview.details)}`);
  }

  await writeFile(join(tmp, "alpha.txt"), "alpha\n");
  await writeFile(join(tmp, "beta.txt"), "beta\n");
  const grouped = await tool.execute(
    "commit-atomic-execute-test",
    {
      multiCommit: true,
      commits: [
        {
          files: ["alpha.txt"],
          commitMessage: "feat(test): add alpha fixture",
          rationale: "Alpha fixture belongs in its own commit.",
          verificationEvidence: [{ description: "alpha fixture reviewed in test", source: "observed" }],
        },
        {
          files: ["beta.txt"],
          commitMessage: "fix(test): add beta fixture",
          rationale: "Beta fixture belongs in its own commit.",
          verificationEvidence: [{ description: "beta fixture reviewed in test", source: "observed" }],
        },
      ],
      dryRun: false,
      push: false,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (grouped.isError) throw new Error(`grouped commit execution failed: ${JSON.stringify(grouped)}`);
  if (!grouped.content[0].text.includes("Commits created: 2.")) throw new Error(`grouped commit result missing summary: ${JSON.stringify(grouped)}`);
  if (grouped.details.commits.length !== 2) throw new Error(`grouped commit details did not retain both commits: ${JSON.stringify(grouped.details)}`);
  if (!grouped.details.commits.every(commit => commit.commitHash)) throw new Error(`grouped commits did not record hashes: ${JSON.stringify(grouped.details)}`);
  if (!grouped.details.commits.every(commit => commit.status === "succeeded")) throw new Error(`grouped commits did not finish with succeeded UI state: ${JSON.stringify(grouped.details)}`);
  const alphaCommitted = (await git(tmp, ["diff", "--name-only", "HEAD~2", "HEAD^"])).stdout.trim();
  if (alphaCommitted !== "alpha.txt") throw new Error(`first grouped commit touched unexpected files: ${alphaCommitted}`);
  const betaCommitted = (await git(tmp, ["diff", "--name-only", "HEAD^", "HEAD"])).stdout.trim();
  if (betaCommitted !== "beta.txt") throw new Error(`second grouped commit touched unexpected files: ${betaCommitted}`);
  const groupedRendered = tool.renderResult(grouped, { expanded: false, isPartial: false, spinnerFrame: 0 }, theme).render(160).join("\n");
  assertBoxedCard(groupedRendered, "grouped execution");
  assertWorkflowRail(groupedRendered, "grouped execution", ["plan", "tree", "diff", "secrets", "verify", "stage", "commit", "hash"]);
  assertStatsChips(groupedRendered, "grouped execution", [
    ["commit count", /commits?\D+2|2 commits?/i],
    ["file count", /files?\D+2|2 files?/i],
    ["verification", /verify|verification|evidence/i],
    ["hash", /hash|[a-f0-9]{7}/i],
    ["push", /push/i],
  ]);
  assertCommitOverview(groupedRendered, "grouped execution", ["feat(test): add alpha fixture", "fix(test): add beta fixture"]);
  assertRenderedIncludes(groupedRendered, "grouped execution", "Commits created:");
  assertRenderedIncludes(groupedRendered, "grouped execution", "Outcome");
  for (const commit of grouped.details.commits) {
    assertRenderedIncludes(groupedRendered, "grouped execution", commit.commitHash);
  }
  for (const pattern of [/2\s+split commits?|split\s+2|commits?\s+2|2\s+commits?/i, /files?\s+1|1 file/i, /✔|✓/]) {
    assertRenderedMatches(groupedRendered, "grouped execution", pattern, pattern.source);
  }
  assertRenderedMatches(groupedRendered, "grouped execution", /(^|\n).*1(?:\/2|\b).*feat\(test\): add alpha fixture/i, "first grouped execution row");
  assertRenderedMatches(groupedRendered, "grouped execution", /(^|\n).*2(?:\/2|\b).*fix\(test\): add beta fixture/i, "second grouped execution row");
  assertRenderedExcludes(groupedRendered, "grouped execution", "Result");
  if (/\batomic\b/i.test(groupedRendered)) throw new Error(`grouped execution render should not say atomic: ${groupedRendered}`);
  const snake = (...parts) => parts.join("_");
  const dash = (...parts) => parts.join("-");
  const dotted = (...parts) => parts.join(".");
  await mkdir(join(tmp, "docs"), { recursive: true });
  await writeFile(join(tmp, "docs", "deployment-env.md"), `OPENAI_${snake("API", "KEY")}=$OPENAI_${snake("API", "KEY")}\n`);
  const envReferencePreview = await tool.execute(
    "commit-env-reference-secret-test",
    {
      files: ["docs/deployment-env.md"],
      commitMessage: "chore(test): allow env secret reference",
      rationale: "Environment variable references are not secret material.",
      verificationEvidence: [{ description: "env reference fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (envReferencePreview.isError) throw new Error(`env var secret reference was blocked: ${JSON.stringify(envReferencePreview)}`);

  await mkdir(join(tmp, "apps", "api", "src", "routes"), { recursive: true });
  const authFixturePath = "apps/api/src/routes/auth.routes.test.ts";
  await writeFile(join(tmp, authFixturePath), [
    "const authConfig = {",
    `  ${snake("JWT", "SECRET")}: '${"6f".repeat(32)}',`,
    `  ${snake("OIDC", "CLIENT", "SECRET")}: '${dash("auth", "route", "test", "secret")}',`,
    "};",
    "const oidcResponse = {",
    `  ${snake("access", "token")}: '${dash("test", "only", "access", "token")}',`,
    `  ${snake("id", "token")}: '${dash("test", "only", "id", "token")}',`,
    "  token_type: 'Bearer',",
    "};",
    "",
  ].join("\n"));
  const testFixturePreview = await tool.execute(
    "commit-test-fixture-secret-test",
    {
      files: [authFixturePath],
      commitMessage: "chore(test): allow auth fixture literals",
      rationale: "Test fixture literals are not deployable secret material.",
      verificationEvidence: [{ description: "auth fixture literals reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (testFixturePreview.isError) throw new Error(`test fixture secret literals were blocked: ${JSON.stringify(testFixturePreview)}`);

  const leakedTokenFixturePath = "apps/api/src/routes/auth.leaked-token.test.ts";
  await writeFile(join(tmp, leakedTokenFixturePath), `export const oidcResponse = { ${snake("access", "token")}: '${["ghp", "test", "a".repeat(24)].join("_")}' };\n`);
  const leakedTokenBlocked = await tool.execute(
    "commit-test-token-secret-test",
    {
      files: [leakedTokenFixturePath],
      commitMessage: "chore(test): block token-shaped fixture",
      rationale: "Real credential-shaped literals should still block in test files.",
      verificationEvidence: [{ description: "token-shaped fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const leakedTokenText = leakedTokenBlocked.content?.[0]?.text ?? JSON.stringify(leakedTokenBlocked);
  if (!leakedTokenBlocked.isError || !leakedTokenText.includes("Potential GitHub token")) {
    throw new Error(`token-shaped test fixture did not block: ${leakedTokenText}`);
  }

  const hexTokenFixturePath = "apps/api/src/routes/auth.hex-token.test.ts";
  await writeFile(join(tmp, hexTokenFixturePath), `export const oidcResponse = { ${snake("access", "token")}: '${"ab".repeat(32)}' };\n`);
  const hexTokenBlocked = await tool.execute(
    "commit-test-hex-secret-test",
    {
      files: [hexTokenFixturePath],
      commitMessage: "chore(test): block bare hex token fixture",
      rationale: "Bare high-entropy token values should still block in test files.",
      verificationEvidence: [{ description: "hex token fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const hexTokenText = hexTokenBlocked.content?.[0]?.text ?? JSON.stringify(hexTokenBlocked);
  if (!hexTokenBlocked.isError || !hexTokenText.includes("Potential generic secret assignment")) {
    throw new Error(`bare hex token fixture did not block: ${hexTokenText}`);
  }

  const markedTokenFixturePath = "apps/api/src/routes/auth.marked-token.test.ts";
  await writeFile(join(tmp, markedTokenFixturePath), `export const config = { ${snake("api", "key")}: '${["my", "test", "token", "a".repeat(24)].join("-")}' };\n`);
  const markedTokenBlocked = await tool.execute(
    "commit-test-marked-secret-test",
    {
      files: [markedTokenFixturePath],
      commitMessage: "chore(test): block marked secret fixture",
      rationale: "A delimiter-separated fixture marker alone should not allow a secret-like literal.",
      verificationEvidence: [{ description: "marked secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const markedTokenText = markedTokenBlocked.content?.[0]?.text ?? JSON.stringify(markedTokenBlocked);
  if (!markedTokenBlocked.isError || !markedTokenText.includes("Potential generic secret assignment")) {
    throw new Error(`marked secret-like fixture did not block: ${markedTokenText}`);
  }

  await writeFile(join(tmp, "docs", "deployment-placeholder.md"), `OPENAI_${snake("API", "KEY")}=${["sk", "proj", "YOUR", "KEY", "HERE"].join("-")}\n`);
  const placeholderBlocked = await tool.execute(
    "commit-secret-placeholder-test",
    {
      files: ["docs/deployment-placeholder.md"],
      commitMessage: "chore(test): block secret placeholder",
      rationale: "Secret-shaped placeholders should still block.",
      verificationEvidence: [{ description: "secret placeholder fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  if (!placeholderBlocked.isError || !placeholderBlocked.content[0].text.includes("Potential OpenAI API key")) {
    throw new Error(`secret-shaped placeholder did not block: ${JSON.stringify(placeholderBlocked)}`);
  }

  await writeFile(join(tmp, "nested-secret-config.ts"), dotted("config", "oauth", "client", "secret") + " = \"" + "b".repeat(12) + "\"\n");
  const nestedSecretBlocked = await tool.execute(
    "commit-nested-secret-test",
    {
      files: ["nested-secret-config.ts"],
      commitMessage: "chore(test): block nested secret assignment",
      rationale: "Nested config secret assignments should still be scanned.",
      verificationEvidence: [{ description: "nested secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const nestedSecretText = nestedSecretBlocked.content?.[0]?.text ?? JSON.stringify(nestedSecretBlocked);
  if (!nestedSecretBlocked.isError || !nestedSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`nested secret assignment did not block: ${nestedSecretText}`);
  }

  await writeFile(join(tmp, "bracket-secret-config.ts"), "config[" + JSON.stringify(snake("api", "key")) + "] = \"" + "c".repeat(12) + "\"\n");
  const bracketSecretBlocked = await tool.execute(
    "commit-bracket-secret-test",
    {
      files: ["bracket-secret-config.ts"],
      commitMessage: "chore(test): block bracket secret assignment",
      rationale: "Static bracketed secret keys should still be scanned.",
      verificationEvidence: [{ description: "bracket secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const bracketSecretText = bracketSecretBlocked.content?.[0]?.text ?? JSON.stringify(bracketSecretBlocked);
  if (!bracketSecretBlocked.isError || !bracketSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`bracket secret assignment did not block: ${bracketSecretText}`);
  }

  await writeFile(join(tmp, "punctuated-bracket-secret-config.ts"), "config[" + JSON.stringify("2fa_" + "secret") + "] = \"" + "e".repeat(12) + "\"\n");
  const punctuatedBracketSecretBlocked = await tool.execute(
    "commit-punctuated-bracket-secret-test",
    {
      files: ["punctuated-bracket-secret-config.ts"],
      commitMessage: "chore(test): block punctuated bracket secret",
      rationale: "Quoted bracket secret keys with punctuation should still be scanned.",
      verificationEvidence: [{ description: "punctuated bracket secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const punctuatedBracketSecretText = punctuatedBracketSecretBlocked.content?.[0]?.text ?? JSON.stringify(punctuatedBracketSecretBlocked);
  if (!punctuatedBracketSecretBlocked.isError || !punctuatedBracketSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`punctuated bracket secret assignment did not block: ${punctuatedBracketSecretText}`);
  }

  await writeFile(join(tmp, "template-bracket-secret-config.ts"), "config[`" + snake("api", "key") + "`] = \"" + "f".repeat(12) + "\"\n");
  const templateBracketSecretBlocked = await tool.execute(
    "commit-template-bracket-secret-test",
    {
      files: ["template-bracket-secret-config.ts"],
      commitMessage: "chore(test): block template bracket secret",
      rationale: "Static template-literal bracket secret keys should still be scanned.",
      verificationEvidence: [{ description: "template bracket secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const templateBracketSecretText = templateBracketSecretBlocked.content?.[0]?.text ?? JSON.stringify(templateBracketSecretBlocked);
  if (!templateBracketSecretBlocked.isError || !templateBracketSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`template bracket secret assignment did not block: ${templateBracketSecretText}`);
  }

  await writeFile(join(tmp, "escaped-bracket-secret-config.ts"), 'config["' + "api" + '\\"_' + "key" + '"] = "' + "g".repeat(12) + '"\n');
  const escapedBracketSecretBlocked = await tool.execute(
    "commit-escaped-bracket-secret-test",
    {
      files: ["escaped-bracket-secret-config.ts"],
      commitMessage: "chore(test): block escaped bracket secret",
      rationale: "Escaped static bracket secret keys should still be scanned.",
      verificationEvidence: [{ description: "escaped bracket secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const escapedBracketSecretText = escapedBracketSecretBlocked.content?.[0]?.text ?? JSON.stringify(escapedBracketSecretBlocked);
  if (!escapedBracketSecretBlocked.isError || !escapedBracketSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`escaped bracket secret assignment did not block: ${escapedBracketSecretText}`);
  }

  await writeFile(join(tmp, "dollar-bracket-secret-config.ts"), 'config["client$' + "secret" + '"] = "' + "i".repeat(12) + '"\n');
  const dollarBracketSecretBlocked = await tool.execute(
    "commit-dollar-bracket-secret-test",
    {
      files: ["dollar-bracket-secret-config.ts"],
      commitMessage: "chore(test): block dollar bracket secret",
      rationale: "Quoted static bracket secret keys may contain dollar signs.",
      verificationEvidence: [{ description: "dollar bracket secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const dollarBracketSecretText = dollarBracketSecretBlocked.content?.[0]?.text ?? JSON.stringify(dollarBracketSecretBlocked);
  if (!dollarBracketSecretBlocked.isError || !dollarBracketSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`dollar bracket secret assignment did not block: ${dollarBracketSecretText}`);
  }

  await writeFile(join(tmp, "bare-bracket-secret-config.ts"), "config[" + snake("API", "KEY") + "] = \"" + "d".repeat(12) + "\"\n");
  const bareBracketSecretBlocked = await tool.execute(
    "commit-bare-bracket-secret-test",
    {
      files: ["bare-bracket-secret-config.ts"],
      commitMessage: "chore(test): block bare bracket secret",
      rationale: "Static bare bracket secret keys should still be scanned.",
      verificationEvidence: [{ description: "bare bracket secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const bareBracketSecretText = bareBracketSecretBlocked.content?.[0]?.text ?? JSON.stringify(bareBracketSecretBlocked);
  if (!bareBracketSecretBlocked.isError || !bareBracketSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`bare bracket secret assignment did not block: ${bareBracketSecretText}`);
  }

  await writeFile(join(tmp, "multiline-secret.yml"), snake("api", "key") + ":\n  |\n    " + "h".repeat(12) + "\n");
  const multilineSecretBlocked = await tool.execute(
    "commit-multiline-secret-test",
    {
      files: ["multiline-secret.yml"],
      commitMessage: "chore(test): block multiline secret",
      rationale: "Adjacent added lines with a key then literal value should still be scanned.",
      verificationEvidence: [{ description: "multiline secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const multilineSecretText = multilineSecretBlocked.content?.[0]?.text ?? JSON.stringify(multilineSecretBlocked);
  if (!multilineSecretBlocked.isError || !multilineSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`multiline secret assignment did not block: ${multilineSecretText}`);
  }

  await writeFile(join(tmp, "context-secret.yml"), snake("api", "key") + ":\n");
  await git(tmp, ["add", "context-secret.yml"]);
  await git(tmp, ["commit", "-m", "chore(test): add context secret key"]);
  await writeFile(join(tmp, "context-secret.yml"), snake("api", "key") + ":\n  |\n    " + "j".repeat(12) + "\n");
  const contextSecretBlocked = await tool.execute(
    "commit-context-secret-test",
    {
      files: ["context-secret.yml"],
      commitMessage: "chore(test): block context secret",
      rationale: "Unchanged key lines adjacent to added literal values should still be scanned.",
      verificationEvidence: [{ description: "context secret fixture reviewed in test", source: "observed" }],
      dryRun: true,
    },
    undefined,
    () => {},
    { cwd: tmp },
  );
  const contextSecretText = contextSecretBlocked.content?.[0]?.text ?? JSON.stringify(contextSecretBlocked);
  if (!contextSecretBlocked.isError || !contextSecretText.includes("Potential generic secret assignment")) {
    throw new Error(`context secret assignment did not block: ${contextSecretText}`);
  }
  await writeFile(join(tmp, "secret.txt"), snake("api", "key") + " = \"" + "a".repeat(12) + "\"\n");
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
  await rm(remote, { recursive: true, force: true });
}
TS
