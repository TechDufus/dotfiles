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
  for (const expected of ["omp_commit", "existing conversation context", "nested omp process", "test-model", "HOME_SKILL_SENTINEL"]) {
    if (!sentMessage[1].content.includes(expected)) throw new Error(`commit prompt missing ${expected}`);
  }
  if (sentMessage[1].details.multiCommit !== false) throw new Error(`plain commit command should not request multiple commits: ${JSON.stringify(sentMessage[1].details)}`);

  if (sentMessage[1].content.includes('"commits"')) throw new Error("plain commit prompt should not show commits array schema");

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
for (const expected of ["2 atomic commits", "2 files", "2 commits: feat(test): add alpha fixture; fix(test): add beta fixture"]) {
  if (!atomicCallRendered.includes(expected)) throw new Error(`atomic call render missing ${expected}: ${atomicCallRendered}`);
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

const wrappedResultComponent = tool.renderResult(
  {
    content: [{ type: "text", text: "Commit preview complete" }],
    details: {
      id: "commit-wrap-render-test",
      status: "succeeded",
      phase: "Commit preview complete after reviewing selected diff and verification evidence",
      startedAt: Date.now(),
      finishedAt: Date.now(),
      steps: [{ label: "Running verification: commit UI wraps rationale verification and file lists", status: "done", startedAt: Date.now(), finishedAt: Date.now() }],
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
      warnings: [],
    },
  },
  { expanded: false, isPartial: false, spinnerFrame: 0 },
  theme,
);
const wrappedResultLines = wrappedResultComponent.render(54);
if (wrappedResultLines.some(line => line.length > 54)) {
  throw new Error(`wrapped result exceeded terminal width: ${wrappedResultLines.join("\n")}`);
}
const wrappedResultRendered = wrappedResultLines.join("\n");
for (const expected of ["Rationale", "terminal-edge", "Verification", "Ignored", "Result"]) {
  if (!wrappedResultRendered.includes(expected)) throw new Error(`wrapped result render missing ${expected}: ${wrappedResultRendered}`);
}
for (const expected of ["Commit preview", "Reviewing selected diff", "Internal actions", "included.txt", "unrelated.txt"]) {
  if (!resultRendered.includes(expected)) throw new Error(`result render missing ${expected}: ${resultRendered}`);
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
      steps: [],
      toolCount: 6,
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
for (const expected of ["2 atomic commits", "Commits", "abc1234 feat(test): add alpha fixture", "def5678 fix(test): add beta fixture"]) {
  if (!atomicResultRendered.includes(expected)) throw new Error(`atomic result render missing ${expected}: ${atomicResultRendered}`);
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

  const committed = (await git(tmp, ["diff", "--name-only", "HEAD^", "HEAD"])).stdout.trim();
  if (committed !== "included.txt") throw new Error(`unexpected committed files: ${committed}`);
  const status = (await git(tmp, ["status", "--porcelain"])).stdout;
  if (!status.includes("?? unrelated.txt")) throw new Error(`unrelated file was not left untouched: ${status}`);

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
  const alphaCommitted = (await git(tmp, ["diff", "--name-only", "HEAD~2", "HEAD^"])).stdout.trim();
  if (alphaCommitted !== "alpha.txt") throw new Error(`first grouped commit touched unexpected files: ${alphaCommitted}`);
  const betaCommitted = (await git(tmp, ["diff", "--name-only", "HEAD^", "HEAD"])).stdout.trim();
  if (betaCommitted !== "beta.txt") throw new Error(`second grouped commit touched unexpected files: ${betaCommitted}`);
  const groupedRendered = tool.renderResult(grouped, { expanded: false, isPartial: false, spinnerFrame: 0 }, theme).render(160).join("\n");
  for (const expected of ["2 atomic commits", "feat(test): add alpha fixture", "fix(test): add beta fixture"]) {
    if (!groupedRendered.includes(expected)) throw new Error(`grouped result render missing ${expected}: ${groupedRendered}`);
  }
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
  await rm(remote, { recursive: true, force: true });
}
TS
