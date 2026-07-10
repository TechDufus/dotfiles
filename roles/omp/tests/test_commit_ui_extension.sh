#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
extension_path="$repo_root/roles/omp/files/extensions/commit-ui.ts"

real_gitleaks_path="$(command -v gitleaks || true)"
export OMP_TEST_REAL_GITLEAKS="$real_gitleaks_path"
fake_gitleaks_dir="$(mktemp -d "${TMPDIR:-/tmp}/omp-commit-ui-gitleaks.XXXXXX")"
fake_gitleaks_control_dir="$fake_gitleaks_dir/control"
mkdir "$fake_gitleaks_control_dir"
printf '%s\n' success > "$fake_gitleaks_control_dir/mode"
: > "$fake_gitleaks_control_dir/mutation-file"
: > "$fake_gitleaks_control_dir/scan-log"
export OMP_TEST_GITLEAKS_CONTROL_DIR="$fake_gitleaks_control_dir"
export OMP_TEST_FAKE_GITLEAKS="$fake_gitleaks_dir/gitleaks"
export PATH="$fake_gitleaks_dir:$PATH"
trap 'rm -rf "$fake_gitleaks_dir"' EXIT
cat > "$fake_gitleaks_dir/gitleaks" <<'SH'
#!/bin/sh
set -eu

control_dir="${OMP_TEST_GITLEAKS_CONTROL_DIR:?}"
mode="$(cat "$control_dir/mode")"
log="$control_dir/scan-log"
subcommand="${1:-}"
if [ "$#" -eq 2 ] && { [ "$subcommand" = "dir" ] || [ "$subcommand" = "stdin" ]; } && [ "$2" = "--help" ]; then
  printf 'capability=%s-help\n' "$subcommand" >> "$log"
  printf 'capability-executable=%s\n' "$0" >> "$log"
  if [ -f "$control_dir/capability-hang" ]; then
    sleep 300 &
    descendant_pid=$!
    printf '%s\n' "$descendant_pid" > "$control_dir/capability-descendant.pid"
    wait "$descendant_pid"
  fi
  if [ "${OMP_TEST_GITLEAKS_FORCE_COMPATIBLE:-}" = 1 ]; then
    printf '%s\n' \
      --redact --no-banner --no-color --timeout --config \
      --gitleaks-ignore-path --ignore-gitleaks-allow \
      --report-format --report-path
    exit 0
  fi
  case "$mode" in
    unavailable) exit 1 ;;
    legacy-only)
      [ "$subcommand" = "dir" ] || exit 1
      exit 0
      ;;
    real-gitleaks)
      [ -n "${OMP_TEST_REAL_GITLEAKS:-}" ] || exit 1
      exec "$OMP_TEST_REAL_GITLEAKS" "$@"
      ;;
    *)
      printf '%s\n' \
        --redact --no-banner --no-color --timeout --config \
        --gitleaks-ignore-path --ignore-gitleaks-allow \
        --report-format --report-path
      exit 0
      ;;
  esac
fi
if [ "$subcommand" = "protect" ] || [ "$subcommand" = "git" ]; then
  exit 64
fi
[ "$subcommand" = "dir" ] || [ "$subcommand" = "stdin" ] || exit 64
shift

scan_tree=""
if [ "$subcommand" = "dir" ]; then
  [ "$#" -ge 1 ] || exit 64
  scan_tree="$1"
  [ -d "$scan_tree" ] || exit 64
  shift
fi

redact=0
ignore_allow=0
report_format=""
report_path=""
config_path=""
ignore_path=""
printf 'scan-executable=%s\n' "$0" >> "$log"
printf 'pass=%s\n' "$subcommand" >> "$log"
printf 'arg=%s\n' "$subcommand" >> "$log"
[ -z "$scan_tree" ] || printf 'arg=%s\n' "$scan_tree" >> "$log"
while [ "$#" -gt 0 ]; do
  printf 'arg=%s\n' "$1" >> "$log"
  case "$1" in
    --staged) exit 64 ;;
    --redact) redact=1; shift ;;
    --ignore-gitleaks-allow) ignore_allow=1; shift ;;
    --config)
      [ "$#" -ge 2 ] || exit 64
      config_path="$2"
      printf 'arg=%s\n' "$2" >> "$log"
      shift 2
      ;;
    --gitleaks-ignore-path)
      [ "$#" -ge 2 ] || exit 64
      ignore_path="$2"
      printf 'arg=%s\n' "$2" >> "$log"
      shift 2
      ;;
    --report-format)
      [ "$#" -ge 2 ] || exit 64
      report_format="$2"
      printf 'arg=%s\n' "$2" >> "$log"
      shift 2
      ;;
    --report-path)
      [ "$#" -ge 2 ] || exit 64
      report_path="$2"
      printf 'arg=%s\n' "$2" >> "$log"
      shift 2
      ;;
    --timeout)
      [ "$#" -ge 2 ] || exit 64
      printf 'arg=%s\n' "$2" >> "$log"
      shift 2
      ;;
    --no-banner|--no-color) shift ;;
    *) exit 64 ;;
  esac
done
[ "$redact" -eq 1 ] || exit 64
[ "$ignore_allow" -eq 1 ] || exit 64
[ "$report_format" = "json" ] || exit 64
[ -n "$config_path" ] && [ -f "$config_path" ] || exit 64
[ "$(cat "$config_path")" = "[extend]
useDefault = true" ] || exit 64
[ -n "$ignore_path" ] && [ -f "$ignore_path" ] || exit 64
[ ! -s "$ignore_path" ] || exit 64
[ -n "$report_path" ] && [ -f "$report_path" ] || exit 64
[ "$(cat "$report_path")" = "omp-gitleaks-report-pending" ] || exit 64
workspace="${report_path%/*}"
candidate_index="$workspace/candidate.index"
[ "$config_path" = "$workspace/gitleaks.toml" ] || exit 64
[ "$ignore_path" = "$workspace/gitleaks.ignore" ] || exit 64
[ -f "$candidate_index" ] || exit 64
[ -z "${GIT_INDEX_FILE:-}" ] || exit 64
[ -z "${GITLEAKS_CONFIG:-}" ] || exit 64
[ -z "${GITLEAKS_CONFIG_TOML:-}" ] || exit 64
case "$subcommand" in
  dir)
    [ "$scan_tree" = "$workspace/scan-tree" ] || exit 64
    [ "$report_path" = "$workspace/gitleaks-dir-report.json" ] || exit 64
    ;;
  stdin)
    [ "$report_path" = "$workspace/gitleaks-stdin-report.json" ] || exit 64
    ;;
esac

tree="$(GIT_INDEX_FILE="$candidate_index" git write-tree)"
{
  printf 'env.GIT_INDEX_FILE=unset\n'
  printf 'env.GITLEAKS_CONFIG=unset\n'
  printf 'env.GITLEAKS_CONFIG_TOML=unset\n'
  printf 'tree=%s\n' "$tree"
  printf 'report.%s=%s\nworkspace=%s\n' "$subcommand" "$report_path" "$workspace"
} >> "$log"

if [ "$subcommand" = "dir" ]; then
  expected_stdin="$control_dir/expected-stdin"
  printf '%0512d\n' 0 | tr 0 A > "$expected_stdin"
  GIT_INDEX_FILE="$candidate_index" git ls-files --stage |
  while IFS="$(printf '\t')" read -r metadata path; do
    [ -n "$path" ] || continue
    case "$path" in
      \"*\")
        path="${path#\"}"
        path="${path%\"}"
        path="$(printf '%b' "$path")"
        ;;
    esac
    set -- $metadata
    mode_bits="$1"
    expected_hash="$2"
    [ "$mode_bits" != "160000" ] || continue
    [ -f "$scan_tree/$path" ] || continue
    actual_hash="$(git hash-object "$scan_tree/$path")"
    [ "$actual_hash" = "$expected_hash" ] || exit 65
    printf 'blob=%s|%s|%s\n' "$path" "$expected_hash" "$actual_hash" >> "$log"
    cat "$scan_tree/$path" >> "$expected_stdin"
    printf '\n' >> "$expected_stdin"
  done
else
  received="$control_dir/received-stdin"
  cat > "$received"
  cmp -s "$control_dir/expected-stdin" "$received" || exit 66
  printf 'stdin.sha=%s\n' "$(git hash-object "$received")" >> "$log"
fi

if [ "$mode" = "real-gitleaks" ]; then
  [ -n "${OMP_TEST_REAL_GITLEAKS:-}" ] || exit 69
  if [ "$subcommand" = "stdin" ]; then
    exec "$OMP_TEST_REAL_GITLEAKS" stdin \
      --redact --no-banner --no-color --timeout 60 \
      --config "$config_path" --gitleaks-ignore-path "$ignore_path" \
      --ignore-gitleaks-allow --report-format json --report-path "$report_path" \
      < "$control_dir/received-stdin"
  fi
  exec "$OMP_TEST_REAL_GITLEAKS" dir "$scan_tree" \
    --redact --no-banner --no-color --timeout 60 \
    --config "$config_path" --gitleaks-ignore-path "$ignore_path" \
    --ignore-gitleaks-allow --report-format json --report-path "$report_path"
fi

if [ "$subcommand" = "dir" ]; then
  case "$mode" in
    mutate-worktree)
      printf '%s\n' 'changed after scan' > "$(cat "$control_dir/mutation-file")"
      ;;
    mutate-real-index)
      real_index="$(git rev-parse --absolute-git-dir)/index"
      GIT_INDEX_FILE="$real_index" git add -- "$(cat "$control_dir/mutation-file")"
      ;;
    advance-head)
      real_index="$(git rev-parse --absolute-git-dir)/index"
      GIT_INDEX_FILE="$real_index" git add -- "$(cat "$control_dir/mutation-file")"
      GIT_INDEX_FILE="$real_index" git commit --no-verify -m "chore(test): concurrent external commit" >/dev/null
      ;;
    abort-descendant)
      sleep 300 &
      descendant_pid=$!
      printf '%s\n' "$descendant_pid" > "$control_dir/descendant.pid"
      wait "$descendant_pid"
      ;;
  esac
  printf '%s\n' '[]' > "$report_path"
  exit 0
fi

case "$mode" in
  success|mutate-worktree|mutate-real-index|advance-head|unavailable)
    printf '%s\n' '[]' > "$report_path"
    ;;
  findings)
    printf '%s\n' '[{"RuleID":"synthetic-fixture","Secret":"REDACTED"}]' > "$report_path"
    exit 1
    ;;
  missing-report)
    ;;
  empty-report)
    : > "$report_path"
    ;;
  malformed-report)
    printf '%s\n' '{' > "$report_path"
    ;;
  wrong-shape-report)
    printf '%s\n' '{"findings":[]}' > "$report_path"
    ;;
  *)
    exit 64
    ;;
esac
exit 0
SH
chmod +x "$fake_gitleaks_dir/gitleaks"

bun --check "$extension_path"

bun - "$extension_path" <<'TS'
import { access, chmod, mkdir, mkdtemp, readFile, realpath, rm, symlink, writeFile } from "node:fs/promises";
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
  const actual = (await git(repo, ["diff", "--name-only", "-z", ...revisionRange])).stdout.split("\0").filter(Boolean);
  assertSameSet(actual, expected, label);
}

async function headOf(repo) {
  return (await git(repo, ["rev-parse", "HEAD"])).stdout.trim();
}

async function commitCountOf(repo) {
  return Number((await git(repo, ["rev-list", "--count", "HEAD"])).stdout.trim());
}

async function stagedPathsOf(repo) {
  return (await git(repo, ["diff", "--cached", "--name-only", "-z"])).stdout.split("\0").filter(Boolean);
}

async function stagedTreeOf(repo) {
  return (await git(repo, ["write-tree"])).stdout.trim();
}

type GitleaksMode =
  | "success"
  | "mutate-worktree"
  | "mutate-real-index"
  | "advance-head"
  | "abort-descendant"
  | "findings"
  | "missing-report"
  | "empty-report"
  | "malformed-report"
  | "wrong-shape-report"
  | "legacy-only"
  | "real-gitleaks"
  | "unavailable";
const gitleaksControlDir = process.env.OMP_TEST_GITLEAKS_CONTROL_DIR;
if (!gitleaksControlDir) fail("gitleaks fake control directory was not configured");

async function setFakeGitleaksMode(mode: GitleaksMode, mutationFile = "") {
  await writeFile(join(gitleaksControlDir, "mode"), `${mode}\n`);
  await writeFile(join(gitleaksControlDir, "mutation-file"), `${mutationFile}\n`);
  await writeFile(join(gitleaksControlDir, "scan-log"), "");
  await rm(join(gitleaksControlDir, "descendant.pid"), { force: true });
  await rm(join(gitleaksControlDir, "capability-descendant.pid"), { force: true });
  await rm(join(gitleaksControlDir, "capability-hang"), { force: true });
}

async function assertScanContractAndCleanup(expectedPaths, label, requireStdin = true) {
  const log = await readFile(join(gitleaksControlDir, "scan-log"), "utf8");
  const required = [
    "capability=dir-help",
    "capability=stdin-help",
    "pass=dir",
    "arg=dir",
    "arg=--redact",
    "arg=--config",
    "arg=--gitleaks-ignore-path",
    "arg=--ignore-gitleaks-allow",
    "arg=--report-format",
    "arg=json",
    "arg=--report-path",
    "env.GIT_INDEX_FILE=unset",
    "env.GITLEAKS_CONFIG=unset",
    "env.GITLEAKS_CONFIG_TOML=unset",
  ];
  if (requireStdin) required.push("pass=stdin", "arg=stdin", "stdin.sha=");
  for (const item of required) {
    assertIncludes(log, item, `${label} scanner invocation`);
  }
  if (log.split("\n").filter(line => line === "pass=dir").length !== 1) {
    fail(`${label} did not run exactly one path-aware directory pass`);
  }
  if (log.split("\n").filter(line => line === "pass=stdin").length !== (requireStdin ? 1 : 0)) {
    fail(`${label} ran an unexpected number of raw-byte stdin passes`);
  }
  assertExcludes(log, "arg=git", `${label} stale git scanner invocation`);
  assertExcludes(log, "arg=protect", `${label} stale protect scanner invocation`);
  assertExcludes(log, "arg=--staged", `${label} stale staged scanner invocation`);
  const values = key => log.split("\n").filter(line => line.startsWith(`${key}=`)).map(line => line.slice(key.length + 1));
  const value = key => values(key)[0] ?? "";
  const workspaces = values("workspace");
  const expectedWorkspaceCount = requireStdin ? 2 : 1;
  if (workspaces.length !== expectedWorkspaceCount || workspaces.some(workspace => workspace !== workspaces[0])) {
    fail(`${label} scanner passes did not share one private workspace`);
  }
  const workspace = workspaces[0];
  const scanTree = join(workspace, "scan-tree");
  const candidateIndex = join(workspace, "candidate.index");
  const dirReport = value("report.dir");
  const stdinReport = join(workspace, "gitleaks-stdin-report.json");
  if (!workspace || !dirReport || (requireStdin && value("report.stdin") !== stdinReport)) {
    fail(`${label} scanner audit log was incomplete`);
  }
  const blobs = log.split("\n").filter(line => line.startsWith("blob=")).map(line => {
    const [path, candidateHash, scanHash] = line.slice("blob=".length).split("|");
    if (!path || !/^[0-9a-f]{40,64}$/.test(candidateHash) || candidateHash !== scanHash) {
      fail(`${label} materialized scan blob differed from the candidate index`);
    }
    return path;
  });
  assertSameSet(blobs, expectedPaths, `${label} materialized scan paths`);
  if (!/^[0-9a-f]{40,64}$/.test(value("tree"))) fail(`${label} did not log a candidate tree`);
  if (dirReport !== join(workspace, "gitleaks-dir-report.json")) fail(`${label} directory report escaped private workspace`);
  if (stdinReport !== join(workspace, "gitleaks-stdin-report.json")) fail(`${label} stdin report escaped private workspace`);
  for (const privatePath of [candidateIndex, scanTree, dirReport, stdinReport, join(workspace, "gitleaks-stdin.input"), workspace]) {
    if (await exists(privatePath)) fail(`${label} left private scanner artifact behind: ${privatePath}`);
  }
  return { tree: value("tree"), workspace };
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

await setFakeGitleaksMode("success");

function assertErrorMessage(result, expected, label) {
  if (!result?.isError) fail(`${label} should have failed`);
  if (!textOf(result).includes(expected)) fail(`${label} omitted the expected user-facing error`);
}

function assertTokenIsRedacted(value, token, label) {
  if (String(value).includes(token)) fail(`${label} exposed fixture token content`);
}

async function assertUnchangedHeadAndCommitCount(repo, expectedHead, expectedCount, label) {
  if (await headOf(repo) !== expectedHead) fail(`${label} changed HEAD`);
  if (await commitCountOf(repo) !== expectedCount) fail(`${label} changed commit count`);
}

async function assertReturnedHashMatchesHead(repo, result, label) {
  const expected = (await git(repo, ["rev-parse", "--short", "HEAD"])).stdout.trim();
  if (hashOf(result) !== expected) {
    fail(`${label} returned hash did not identify the created candidate commit`);
  }
}

async function withFakeGitleaksMode(mode: GitleaksMode, mutationFile = "") {
  await setFakeGitleaksMode(mode, mutationFile);
  return async () => await setFakeGitleaksMode("success");
}

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
  const selectedScan = await assertScanContractAndCleanup(["included.txt"], "selected-file commit");
  const selectedCommitTree = (await git(selectedRepo, ["rev-parse", "HEAD^{tree}"])).stdout.trim();
  if (selectedCommitTree !== selectedScan.tree) fail("selected-file commit tree differed from scanned candidate");
  await assertReturnedHashMatchesHead(selectedRepo, selected, "selected-file commit");

  const mutationRepo = await makeRepo("candidate-worktree-mutation-");
  const mutationPath = join(mutationRepo, "selected.txt");
  await writeFile(mutationPath, "scanned candidate\n");
  await setFakeGitleaksMode("mutate-worktree", mutationPath);
  const mutationResult = await execute(mutationRepo, "candidate-worktree-mutation", {
    files: ["selected.txt"],
    commitMessage: "chore(test): commit scanned candidate",
    dryRun: false,
    push: false,
  });
  assertSucceeded(mutationResult, "candidate worktree mutation");
  const mutationScan = await assertScanContractAndCleanup(["selected.txt"], "candidate worktree mutation");
  if ((await git(mutationRepo, ["rev-parse", "HEAD^{tree}"])).stdout.trim() !== mutationScan.tree) {
    fail("candidate worktree mutation did not commit the exact scanned tree");
  }
  if ((await git(mutationRepo, ["show", "HEAD:selected.txt"])).stdout !== "scanned candidate\n") {
    fail("candidate worktree mutation committed post-scan worktree content");
  }
  if ((await readFile(mutationPath, "utf8")) !== "changed after scan\n") {
    fail("candidate worktree mutation fixture did not mutate after scanning");
  }

  for (const reportCase of [
    { mode: "findings", expected: "Gitleaks detected potential secrets; commit was not created." },
    { mode: "missing-report", expected: "Gitleaks scan failed; commit was not created." },
    { mode: "empty-report", expected: "Gitleaks scan failed; commit was not created." },
    { mode: "malformed-report", expected: "Gitleaks scan failed; commit was not created." },
    { mode: "wrong-shape-report", expected: "Gitleaks scan failed; commit was not created." },
  ] as const) {
    const repo = await makeRepo(`gitleaks-${reportCase.mode}-`);
    const blockedToken = ["sk", "fixture", reportCase.mode, "q".repeat(32)].join("-");
    await writeFile(join(repo, "selected.ts"), `export const credential = "${blockedToken}";\n`);
    const beforeHead = await headOf(repo);
    const beforeCount = await commitCountOf(repo);
    const beforeIndex = await stagedTreeOf(repo);
    await setFakeGitleaksMode(reportCase.mode);
    const result = await execute(repo, `gitleaks-${reportCase.mode}`, {
      files: ["selected.ts"],
      commitMessage: `chore(test): block ${reportCase.mode}`,
      dryRun: false,
      push: false,
    });
    assertErrorMessage(result, reportCase.expected, `gitleaks ${reportCase.mode}`);
    await assertUnchangedHeadAndCommitCount(repo, beforeHead, beforeCount, `gitleaks ${reportCase.mode}`);
    if (await stagedTreeOf(repo) !== beforeIndex) fail(`gitleaks ${reportCase.mode} changed the real index`);
    assertSameSet(await stagedPathsOf(repo), [], `gitleaks ${reportCase.mode} real index`);
    assertTokenIsRedacted(`${textOf(result)}\n${JSON.stringify(result.details ?? {})}`, blockedToken, `gitleaks ${reportCase.mode}`);
    await assertScanContractAndCleanup(["selected.ts"], `gitleaks ${reportCase.mode}`);
  }

  const capabilityRepo = await makeRepo("gitleaks-capability-abort-descendant-");
  await writeFile(join(capabilityRepo, "selected.txt"), "capability abort fixture\n");
  const capabilityHead = await headOf(capabilityRepo);
  const capabilityCount = await commitCountOf(capabilityRepo);
  const capabilityIndex = await stagedTreeOf(capabilityRepo);
  await setFakeGitleaksMode("success");
  await writeFile(join(gitleaksControlDir, "capability-hang"), "");
  const capabilityController = new AbortController();
  const capabilityPromise = tool.execute(
    "gitleaks-capability-abort-descendant",
    {
      files: ["selected.txt"],
      commitMessage: "chore(test): abort capability probe",
      dryRun: false,
      push: false,
    },
    capabilityController.signal,
    () => {},
    { cwd: capabilityRepo },
  );
  const capabilityPidPath = join(gitleaksControlDir, "capability-descendant.pid");
  const capabilityStartDeadline = Date.now() + 5_000;
  while (!(await exists(capabilityPidPath)) && Date.now() < capabilityStartDeadline) await Bun.sleep(20);
  if (!(await exists(capabilityPidPath))) {
    fail("scanner capability descendant fixture did not start");
  }
  const capabilityPid = (await readFile(capabilityPidPath, "utf8")).trim();
  if (!/^[1-9][0-9]*$/.test(capabilityPid)) fail("scanner capability fixture recorded an invalid PID");
  const capabilityAbortStartedAt = Date.now();
  capabilityController.abort();
  const capabilityResult = await capabilityPromise;
  assertError(capabilityResult, /cancelled|aborted/i, "scanner capability descendant abort");
  if (Date.now() - capabilityAbortStartedAt >= 3_000) fail("scanner capability cancellation exceeded its bounded deadline");
  await assertUnchangedHeadAndCommitCount(capabilityRepo, capabilityHead, capabilityCount, "scanner capability abort");
  if (await stagedTreeOf(capabilityRepo) !== capabilityIndex) fail("scanner capability abort changed the real index");
  const capabilityCleanupDeadline = Date.now() + 3_000;
  let capabilityDescendantRunning = true;
  while (capabilityDescendantRunning && Date.now() < capabilityCleanupDeadline) {
    const processState = await run(capabilityRepo, "ps", ["-o", "stat=", "-p", capabilityPid], { allowFailure: true });
    capabilityDescendantRunning = processState.exitCode === 0 && !processState.stdout.trim().startsWith("Z");
    if (capabilityDescendantRunning) await Bun.sleep(25);
  }
  if (capabilityDescendantRunning) fail("scanner capability abort left a running descendant process");

  const abortScannerRepo = await makeRepo("gitleaks-abort-descendant-");
  await writeFile(join(abortScannerRepo, "selected.txt"), "abort scanner fixture\n");
  const abortScannerHead = await headOf(abortScannerRepo);
  const abortScannerCount = await commitCountOf(abortScannerRepo);
  await setFakeGitleaksMode("abort-descendant");
  const scannerController = new AbortController();
  const abortScannerPromise = tool.execute(
    "gitleaks-abort-descendant",
    {
      files: ["selected.txt"],
      commitMessage: "chore(test): abort scanner process group",
      dryRun: false,
      push: false,
    },
    scannerController.signal,
    () => {},
    { cwd: abortScannerRepo },
  );
  const descendantPidPath = join(gitleaksControlDir, "descendant.pid");
  const descendantDeadline = Date.now() + 5_000;
  while (!(await exists(descendantPidPath)) && Date.now() < descendantDeadline) await Bun.sleep(20);
  if (!(await exists(descendantPidPath))) fail("scanner descendant fixture did not start");
  const descendantPid = (await readFile(descendantPidPath, "utf8")).trim();
  if (!/^[1-9][0-9]*$/.test(descendantPid)) fail("scanner descendant fixture recorded an invalid PID");
  scannerController.abort();
  const abortScannerResult = await abortScannerPromise;
  assertError(abortScannerResult, /cancelled|aborted/i, "scanner descendant abort");
  await assertUnchangedHeadAndCommitCount(
    abortScannerRepo,
    abortScannerHead,
    abortScannerCount,
    "scanner descendant abort",
  );
  const cleanupDeadline = Date.now() + 3_000;
  let descendantRunning = true;
  while (descendantRunning && Date.now() < cleanupDeadline) {
    const processState = await run(abortScannerRepo, "ps", ["-o", "stat=", "-p", descendantPid], { allowFailure: true });
    descendantRunning = processState.exitCode === 0 && !processState.stdout.trim().startsWith("Z");
    if (descendantRunning) await Bun.sleep(25);
  }
  if (descendantRunning) fail("scanner abort left a running descendant process");
  await assertScanContractAndCleanup(["selected.txt"], "scanner descendant abort", false);


  const fallbackRepo = await makeRepo("gitleaks-compatible-home-fallback-");
  await writeFile(join(fallbackRepo, "selected.txt"), "compatible fallback fixture\n");
  const fallbackHome = await tempDir("omp-commit-ui-gitleaks-home-");
  const fallbackBin = join(fallbackHome, ".local", "bin");
  const fallbackGitleaks = join(fallbackBin, "gitleaks");
  const fakeGitleaksPath = process.env.OMP_TEST_FAKE_GITLEAKS;
  if (!fakeGitleaksPath) fail("gitleaks fake executable path was not configured");
  await mkdir(fallbackBin, { recursive: true });
  const fallbackScript = (await readFile(fakeGitleaksPath, "utf8")).replace(
    "#!/bin/sh\n",
    "#!/bin/sh\nexport OMP_TEST_GITLEAKS_FORCE_COMPATIBLE=1\n",
  );
  await writeFile(fallbackGitleaks, fallbackScript);
  await chmod(fallbackGitleaks, 0o755);
  const fallbackPreviousHome = process.env.HOME;
  try {
    process.env.HOME = fallbackHome;
    await setFakeGitleaksMode("unavailable");
    const fallbackResult = await execute(fallbackRepo, "gitleaks-compatible-home-fallback", {
      files: ["selected.txt"],
      commitMessage: "chore(test): use compatible home scanner",
      dryRun: false,
      push: false,
    });
    assertSucceeded(fallbackResult, "compatible HOME scanner fallback");
    await assertReturnedHashMatchesHead(fallbackRepo, fallbackResult, "compatible HOME scanner fallback");
    await assertCommittedFiles(fallbackRepo, ["HEAD^", "HEAD"], ["selected.txt"], "compatible HOME scanner fallback files");
    const fallbackLog = await readFile(join(gitleaksControlDir, "scan-log"), "utf8");
    const scanExecutables = fallbackLog.split("\n")
      .filter(line => line.startsWith("scan-executable="))
      .map(line => line.slice("scan-executable=".length));
    if (scanExecutables.length !== 2 || scanExecutables.some(path => path !== fallbackGitleaks)) {
      fail(`compatible HOME scanner fallback did not run the selected executable: ${JSON.stringify(scanExecutables)}`);
    }
    assertIncludes(fallbackLog, `capability-executable=${fakeGitleaksPath}`, "incompatible bare scanner probe");
    assertIncludes(fallbackLog, `capability-executable=${fallbackGitleaks}`, "compatible HOME scanner probe");
    await assertScanContractAndCleanup(["selected.txt"], "compatible HOME scanner fallback");
  } finally {
    if (fallbackPreviousHome === undefined) delete process.env.HOME;
    else process.env.HOME = fallbackPreviousHome;
  }

  if (process.env.OMP_TEST_REAL_GITLEAKS) {
    const attributesRepo = await makeRepo("gitleaks-attributes-");
    await writeFile(join(attributesRepo, ".gitattributes"), "selected.ts -diff\n");
    await git(attributesRepo, ["add", "--", ".gitattributes"]);
    await git(attributesRepo, ["commit", "-m", "chore(test): add diff suppression fixture"]);
    const suppressedToken = `github_pat_${"A1b2C3d4E5f6G7h8I9j0K".repeat(5).slice(0, 82)}`;
    await writeFile(join(attributesRepo, "selected.ts"), `export const credential = "${suppressedToken}";\n`);
    const attributesHead = await headOf(attributesRepo);
    const attributesCount = await commitCountOf(attributesRepo);
    await setFakeGitleaksMode("real-gitleaks");
    const attributesResult = await execute(attributesRepo, "gitleaks-attributes", {
      files: ["selected.ts"],
      commitMessage: "chore(test): block diff-suppressed secret",
      dryRun: false,
      push: false,
    });
    assertErrorMessage(
      attributesResult,
      "Gitleaks detected potential secrets; commit was not created.",
      "gitattributes diff suppression",
    );
    await assertUnchangedHeadAndCommitCount(
      attributesRepo,
      attributesHead,
      attributesCount,
      "gitattributes diff suppression",
    );
    assertTokenIsRedacted(
      `${textOf(attributesResult)}\n${JSON.stringify(attributesResult.details ?? {})}`,
      suppressedToken,
      "gitattributes diff suppression",
    );
    await assertScanContractAndCleanup(["selected.ts"], "gitattributes diff suppression", false);

    const rawBypassCases = [
      {
        label: "binary-extension",
        path: "secret.bin",
        bytes: token => Buffer.from(`binary extension fixture\n${token}\n`),
      },
      {
        label: "ignored-directory",
        path: "node_modules/secret",
        bytes: token => Buffer.from(`ignored directory fixture\n${token}\n`),
      },
      {
        label: "elf-magic",
        path: "fixture.elf",
        bytes: token => Buffer.concat([Buffer.from([0x7f, 0x45, 0x4c, 0x46, 0x00]), Buffer.from(token)]),
      },
      {
        label: "image-magic",
        path: "fixture.png",
        bytes: token => Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]), Buffer.from(token)]),
      },
      {
        label: "archive-magic",
        path: "fixture.zip",
        bytes: token => Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04, 0x00]), Buffer.from(token)]),
      },
    ];
    for (const [caseIndex, bypassCase] of rawBypassCases.entries()) {
      const repo = await makeRepo(`gitleaks-raw-${bypassCase.label}-`);
      const tokenAlphabet = `A1b2C3d4E5f6G7h8I9j0K${caseIndex}`;
      const generatedToken = `github_pat_${tokenAlphabet.repeat(5).slice(0, 82)}`;
      await mkdir(join(repo, bypassCase.path, ".."), { recursive: true });
      await writeFile(join(repo, bypassCase.path), bypassCase.bytes(generatedToken));
      const beforeHead = await headOf(repo);
      const beforeCount = await commitCountOf(repo);
      await setFakeGitleaksMode("real-gitleaks");
      const result = await execute(repo, `gitleaks-raw-${bypassCase.label}`, {
        files: [bypassCase.path],
        commitMessage: `chore(test): block ${bypassCase.label} fixture`,
        dryRun: false,
        push: false,
      });
      assertErrorMessage(result, "Gitleaks detected potential secrets; commit was not created.", `raw ${bypassCase.label}`);
      await assertUnchangedHeadAndCommitCount(repo, beforeHead, beforeCount, `raw ${bypassCase.label}`);
      assertTokenIsRedacted(
        `${textOf(result)}\n${JSON.stringify(result.details ?? {})}`,
        generatedToken,
        `raw ${bypassCase.label}`,
      );
      await assertScanContractAndCleanup([bypassCase.path], `raw ${bypassCase.label}`);
    }

    const symlinkRepo = await makeRepo("gitleaks-raw-symlink-");
    const symlinkToken = `github_pat_${"Z9y8X7w6V5u4T3s2R1q0P".repeat(5).slice(0, 82)}`;
    await symlink(symlinkToken, join(symlinkRepo, "secret-link"));
    const symlinkHead = await headOf(symlinkRepo);
    const symlinkCount = await commitCountOf(symlinkRepo);
    await setFakeGitleaksMode("real-gitleaks");
    const symlinkResult = await execute(symlinkRepo, "gitleaks-raw-symlink", {
      files: ["secret-link"],
      commitMessage: "chore(test): block symlink target fixture",
      dryRun: false,
      push: false,
    });
    assertErrorMessage(symlinkResult, "Gitleaks detected potential secrets; commit was not created.", "raw symlink target");
    await assertUnchangedHeadAndCommitCount(symlinkRepo, symlinkHead, symlinkCount, "raw symlink target");
    assertTokenIsRedacted(
      `${textOf(symlinkResult)}\n${JSON.stringify(symlinkResult.details ?? {})}`,
      symlinkToken,
      "raw symlink target",
    );
    await assertScanContractAndCleanup(["secret-link"], "raw symlink target", false);
  }

  const advancedBaseRepo = await makeRepo("advanced-base-");
  await writeFile(join(advancedBaseRepo, "candidate.txt"), "candidate content\n");
  await writeFile(join(advancedBaseRepo, "external.txt"), "external content\n");
  const advancedBaseInitialHead = await headOf(advancedBaseRepo);
  const advancedBaseInitialCount = await commitCountOf(advancedBaseRepo);
  await setFakeGitleaksMode("advance-head", "external.txt");
  const advancedBaseResult = await execute(advancedBaseRepo, "advanced-base", {
    files: ["candidate.txt"],
    commitMessage: "chore(test): reject stale candidate base",
    dryRun: false,
    push: false,
  });
  assertError(
    advancedBaseResult,
    /repository base changed after scanning|Git command failed|Created commit did not match/i,
    "advanced base guard",
  );
  if (await commitCountOf(advancedBaseRepo) !== advancedBaseInitialCount + 1) {
    fail("advanced base guard did not preserve exactly one external commit");
  }
  if (await headOf(advancedBaseRepo) === advancedBaseInitialHead) fail("advanced base fixture did not advance HEAD");
  await assertCommittedFiles(
    advancedBaseRepo,
    [advancedBaseInitialHead, "HEAD"],
    ["external.txt"],
    "advanced base external commit",
  );
  const advancedBaseStatus = (await git(advancedBaseRepo, ["status", "--porcelain"])).stdout;
  assertIncludes(advancedBaseStatus, "?? candidate.txt", "advanced base preserved candidate worktree file");
  await assertScanContractAndCleanup(["candidate.txt"], "advanced base guard");

  const literalPathRepo = await makeRepo("literal-pathspec-");
  const magicPath = ":(glob)*.txt";
  await writeFile(join(literalPathRepo, magicPath), "literal pathspec candidate\n");
  await writeFile(join(literalPathRepo, "decoy.txt"), "must remain unselected\n");
  await setFakeGitleaksMode("success");
  const literalPathResult = await execute(literalPathRepo, "literal-pathspec", {
    files: [magicPath],
    commitMessage: "chore(test): commit literal pathspec filename",
    dryRun: false,
    push: false,
  });
  assertSucceeded(literalPathResult, "literal pathspec filename");
  await assertCommittedFiles(literalPathRepo, ["HEAD^", "HEAD"], [magicPath], "literal pathspec committed files");
  assertIncludes(
    (await git(literalPathRepo, ["status", "--porcelain"])).stdout,
    "?? decoy.txt",
    "literal pathspec preserved glob match",
  );
  await assertScanContractAndCleanup([magicPath], "literal pathspec filename");

  if (process.platform !== "win32") {
    const exactPathRepo = await makeRepo("exact-path-bytes-");
    const exactPaths = [" leading.txt", "trailing.txt ", "unix\\backslash.txt"];
    const decoyPaths = ["leading.txt", "trailing.txt", "unix/backslash.txt"];
    await mkdir(join(exactPathRepo, "unix"));
    for (const path of exactPaths) await writeFile(join(exactPathRepo, path), `selected ${JSON.stringify(path)}\n`);
    for (const path of decoyPaths) await writeFile(join(exactPathRepo, path), `decoy ${JSON.stringify(path)}\n`);
    await setFakeGitleaksMode("success");
    const exactPathResult = await execute(exactPathRepo, "exact-path-bytes", {
      files: exactPaths,
      commitMessage: "chore(test): preserve exact path bytes",
      dryRun: false,
      push: false,
    });
    assertSucceeded(exactPathResult, "exact path bytes");
    await assertCommittedFiles(exactPathRepo, ["HEAD^", "HEAD"], exactPaths, "exact path byte committed files");
    assertSameSet(
      parseStatusPaths((await git(exactPathRepo, ["status", "--porcelain", "-z", "--untracked-files=all"])).stdout),
      decoyPaths,
      "exact path decoys",
    );
    await assertScanContractAndCleanup(exactPaths, "exact path bytes");
  }

  const omissionRepo = await makeRepo("scan-omissions-");
  await writeFile(join(omissionRepo, "deleted.txt"), "delete candidate\n");
  await git(omissionRepo, ["add", "--", "deleted.txt"]);
  await git(omissionRepo, ["commit", "-m", "chore(test): add deletion fixture"]);
  await rm(join(omissionRepo, "deleted.txt"));
  await writeFile(join(omissionRepo, "plain.txt"), "materialized candidate\n");
  const nestedRepo = join(omissionRepo, "module");
  await mkdir(nestedRepo);
  await git(nestedRepo, ["init"]);
  await git(nestedRepo, ["config", "user.email", "commit-ui-test@example.invalid"]);
  await git(nestedRepo, ["config", "user.name", "Commit UI Test"]);
  await writeFile(join(nestedRepo, "nested.txt"), "gitlink fixture\n");
  await git(nestedRepo, ["add", "--", "nested.txt"]);
  await git(nestedRepo, ["commit", "-m", "chore(test): nested fixture"]);
  await setFakeGitleaksMode("success");
  const omissionResult = await execute(omissionRepo, "scan-omissions", {
    files: ["deleted.txt", "module", "plain.txt"],
    commitMessage: "chore(test): preserve scanner omissions",
    dryRun: false,
    push: false,
  });
  assertSucceeded(omissionResult, "scanner omissions");
  await assertCommittedFiles(
    omissionRepo,
    ["HEAD^", "HEAD"],
    ["deleted.txt", "module", "plain.txt"],
    "scanner omission committed files",
  );
  await assertScanContractAndCleanup(["plain.txt"], "scanner omissions");

  const splitIndexRepo = await makeRepo("real-split-index-");
  await git(splitIndexRepo, ["update-index", "--split-index"]);
  const sharedIndexPath = (await git(splitIndexRepo, ["rev-parse", "--path-format=absolute", "--shared-index-path"])).stdout.trim();
  if (!sharedIndexPath || !(await exists(sharedIndexPath))) fail("real split-index fixture did not create a shared index");
  await writeFile(join(splitIndexRepo, "selected.txt"), "staged predecessor\n");
  await git(splitIndexRepo, ["add", "--", "selected.txt"]);
  await writeFile(join(splitIndexRepo, "selected.txt"), "candidate successor\n");
  await setFakeGitleaksMode("success");
  const splitIndexResult = await execute(splitIndexRepo, "real-split-index", {
    files: ["selected.txt"],
    commitMessage: "chore(test): reconcile real split index",
    dryRun: false,
    push: false,
  });
  assertSucceeded(splitIndexResult, "real split-index reconciliation");
  await assertReturnedHashMatchesHead(splitIndexRepo, splitIndexResult, "real split-index reconciliation");
  assertSameSet(await stagedPathsOf(splitIndexRepo), [], "real split-index reconciled staging");
  if ((await git(splitIndexRepo, ["status", "--porcelain"])).stdout !== "") {
    fail("real split-index reconciliation left a stale staged or worktree reversal");
  }
  if ((await git(splitIndexRepo, ["show", "HEAD:selected.txt"])).stdout !== "candidate successor\n") {
    fail("real split-index reconciliation committed the stale staged predecessor");
  }
  if (warningsOf(splitIndexResult).length !== 0) {
    fail(`real split-index reconciliation emitted a warning: ${JSON.stringify(warningsOf(splitIndexResult))}`);
  }
  await assertScanContractAndCleanup(["selected.txt"], "real split-index reconciliation");

  const realIndexRepo = await makeRepo("real-index-mutation-");
  await writeFile(join(realIndexRepo, "selected.txt"), "scanned selection\n");
  await writeFile(join(realIndexRepo, "concurrent.txt"), "physical index mutation\n");
  await setFakeGitleaksMode("mutate-real-index", "concurrent.txt");
  const realIndexResult = await execute(realIndexRepo, "real-index-mutation", {
    files: ["selected.txt"],
    commitMessage: "chore(test): preserve physical index mutation",
    dryRun: false,
    push: false,
  });
  assertSucceeded(realIndexResult, "real-index mutation");
  const realIndexScan = await assertScanContractAndCleanup(["selected.txt"], "real-index mutation");
  if ((await git(realIndexRepo, ["rev-parse", "HEAD^{tree}"])).stdout.trim() !== realIndexScan.tree) {
    fail("real-index mutation commit differed from scanned candidate");
  }
  assertSameSet(await stagedPathsOf(realIndexRepo), ["concurrent.txt", "selected.txt"], "real-index mutation preserved physical staging");
  if ((await git(realIndexRepo, ["show", ":concurrent.txt"])).stdout !== "physical index mutation\n") {
    fail("real-index mutation did not preserve concurrently staged content");
  }
  if (!warningsOf(realIndexResult).some(warning => /newer staged changes.*preserved/i.test(warning))) {
    fail(`real-index mutation omitted preservation warning: ${JSON.stringify(warningsOf(realIndexResult))}`);
  }

  const hooksRepo = await makeRepo("configured-hooks-");
  const hooksDir = join(hooksRepo, "configured-hooks");
  const hooksLog = join(hooksRepo, "hook-order.log");
  const referenceLog = join(hooksRepo, "reference-transaction.log");
  await mkdir(hooksDir);
  await git(hooksRepo, ["config", "core.hooksPath", hooksDir]);
  for (const hook of ["pre-commit", "prepare-commit-msg", "commit-msg", "post-commit"]) {
    const hookPath = join(hooksDir, hook);
    await writeFile(hookPath, `#!/bin/sh\nprintf '%s:%s\\n' '${hook}' "$GIT_INDEX_FILE" >> '${hooksLog}'\n`);
    await chmod(hookPath, 0o755);
  }
  const hooksBase = await headOf(hooksRepo);
  const hooksRef = (await git(hooksRepo, ["symbolic-ref", "HEAD"])).stdout.trim();
  const referenceHook = join(hooksDir, "reference-transaction");
  await writeFile(
    referenceHook,
    `#!/bin/sh\nprintf 'phase=%s\\n' "$1" >> '${referenceLog}'\ncat >> '${referenceLog}'\n`,
  );
  await chmod(referenceHook, 0o755);
  await writeFile(join(hooksRepo, "hooked.txt"), "hooked candidate\n");
  await setFakeGitleaksMode("success");
  const hooksResult = await execute(hooksRepo, "configured-hooks", {
    files: ["hooked.txt"],
    commitMessage: "chore(test): run configured hooks",
    dryRun: false,
    push: false,
  });
  assertSucceeded(hooksResult, "configured hooks");
  const hooksScan = await assertScanContractAndCleanup(["hooked.txt"], "configured hooks");
  const hookLines = (await readFile(hooksLog, "utf8")).trim().split("\n");
  assertSameSet(hookLines.map(line => line.split(":")[0]), ["pre-commit", "prepare-commit-msg", "commit-msg", "post-commit"], "configured hook count");
  if (hookLines.map(line => line.split(":")[0]).join(",") !== "pre-commit,prepare-commit-msg,commit-msg,post-commit") {
    fail(`configured hooks ran out of order: ${JSON.stringify(hookLines)}`);
  }
  if (!hookLines.every(line => line.slice(line.indexOf(":") + 1) === join(hooksScan.workspace, "candidate.index"))) {
    fail(`configured hooks did not receive candidate index: ${JSON.stringify(hookLines)}`);
  }
  const hooksCreated = await headOf(hooksRepo);
  function parseReferenceTransactions(raw, label) {
    const lines = raw.trimEnd().split("\n");
    const groups = [];
    for (const line of lines) {
      const phase = /^phase=(preparing|prepared|committed|aborted)$/.exec(line)?.[1];
      if (phase) {
        groups.push({ phase, updates: [] });
        continue;
      }
      const group = groups.at(-1);
      const update = /^([0-9a-f]{40,64}) ([0-9a-f]{40,64}) (\S+)$/.exec(line);
      if (!group || !update || update[1].length !== update[2].length) {
        fail(`${label} contained a malformed phase/update group: ${JSON.stringify(lines)}`);
      }
      group.updates.push(line);
    }
    if (groups.length === 0 || groups.some(group => group.updates.length === 0)) {
      fail(`${label} contained an empty or missing phase/update group: ${JSON.stringify(lines)}`);
    }
    return groups;
  }
  const referenceGroups = parseReferenceTransactions(await readFile(referenceLog, "utf8"), "reference-transaction hook");
  const expectedBranchUpdate = `${hooksBase} ${hooksCreated} ${hooksRef}`;
  const branchGroups = referenceGroups.filter(group => group.updates.some(update => update.endsWith(` ${hooksRef}`)));
  const requiredBranchGroups = branchGroups.filter(group => group.phase === "prepared" || group.phase === "committed");
  if (requiredBranchGroups.length !== 2 ||
    requiredBranchGroups[0].phase !== "prepared" ||
    requiredBranchGroups[1].phase !== "committed" ||
    requiredBranchGroups.some(group => group.updates.filter(update => update.endsWith(` ${hooksRef}`)).join("\n") !== expectedBranchUpdate)) {
    fail(`reference-transaction hook did not preserve the prepared then committed branch update: ${JSON.stringify(referenceGroups)}`);
  }
  for (const group of branchGroups.filter(group => group.phase === "preparing")) {
    if (group.updates.filter(update => update.endsWith(` ${hooksRef}`)).some(update => update !== expectedBranchUpdate)) {
      fail(`reference-transaction hook changed the preparing branch update: ${JSON.stringify(referenceGroups)}`);
    }
  }

  const rejectingReferenceRepo = await makeRepo("rejecting-reference-hook-");
  const rejectingHooksDir = join(rejectingReferenceRepo, "hooks");
  const rejectingReferenceLog = join(rejectingReferenceRepo, "reference-transaction.log");
  await mkdir(rejectingHooksDir);
  await git(rejectingReferenceRepo, ["config", "core.hooksPath", "hooks"]);
  const rejectingReferenceHook = join(rejectingHooksDir, "reference-transaction");
  await writeFile(
    rejectingReferenceHook,
    `#!/bin/sh\nprintf 'phase=%s\\n' "$1" >> '${rejectingReferenceLog}'\ncat >> '${rejectingReferenceLog}'\n[ "$1" != prepared ] || exit 23\n`,
  );
  await chmod(rejectingReferenceHook, 0o755);
  await writeFile(join(rejectingReferenceRepo, "selected.txt"), "rejected transaction\n");
  const rejectingBase = await headOf(rejectingReferenceRepo);
  const rejectingCount = await commitCountOf(rejectingReferenceRepo);
  const rejectingRef = (await git(rejectingReferenceRepo, ["symbolic-ref", "HEAD"])).stdout.trim();
  await setFakeGitleaksMode("success");
  const rejectingReferenceResult = await execute(rejectingReferenceRepo, "rejecting-reference-hook", {
    files: ["selected.txt"],
    commitMessage: "chore(test): reject prepared transaction",
    dryRun: false,
    push: false,
  });
  assertError(rejectingReferenceResult, /git .* failed|reference-transaction/i, "rejecting reference hook");
  await assertUnchangedHeadAndCommitCount(
    rejectingReferenceRepo,
    rejectingBase,
    rejectingCount,
    "rejecting reference hook",
  );
  const rejectingGroups = parseReferenceTransactions(
    await readFile(rejectingReferenceLog, "utf8"),
    "rejecting reference-transaction hook",
  );
  const rejectingPrepared = rejectingGroups.find(group =>
    group.phase === "prepared" && group.updates.some(update => update.endsWith(` ${rejectingRef}`))
  );
  const rejectedUpdate = rejectingPrepared?.updates.find(update => update.endsWith(` ${rejectingRef}`)) ?? "";
  const rejectedNewOid = rejectedUpdate.split(" ")[1];
  const expectedRejectedUpdate = `${rejectingBase} ${rejectedNewOid} ${rejectingRef}`;
  if (!rejectingPrepared ||
    rejectingPrepared.updates.filter(update => update.endsWith(` ${rejectingRef}`)).join("\n") !== expectedRejectedUpdate ||
    !/^[0-9a-f]{40,64}$/.test(rejectedNewOid ?? "") ||
    rejectedNewOid === rejectingBase) {
    fail(`rejecting reference hook did not receive the exact prepared candidate update: ${JSON.stringify(rejectingGroups)}`);
  }
  const rejectingAbortedIndex = rejectingGroups.findIndex(group =>
    group.phase === "aborted" && group.updates.some(update => update.endsWith(` ${rejectingRef}`))
  );
  if (rejectingAbortedIndex >= 0) {
    const aborted = rejectingGroups[rejectingAbortedIndex];
    if (rejectingAbortedIndex <= rejectingGroups.indexOf(rejectingPrepared) ||
      aborted.updates.filter(update => update.endsWith(` ${rejectingRef}`)).join("\n") !== expectedRejectedUpdate) {
      fail(`rejecting reference hook changed or reordered the aborted target update: ${JSON.stringify(rejectingGroups)}`);
    }
  }
  await assertScanContractAndCleanup(["selected.txt"], "rejecting reference hook");

  for (const ordinaryCase of [
    { label: "accepting", reject: false },
    { label: "rejecting", reject: true },
  ]) {
    const repo = await makeRepo(`${ordinaryCase.label}-pre-commit-relative-helper-`);
    const hookRoot = join(repo, "hook-layout");
    const activeHookDir = join(hookRoot, "active");
    const helperLog = join(repo, "ordinary-helper.log");
    await mkdir(activeHookDir, { recursive: true });
    await git(repo, ["config", "core.hooksPath", "hook-layout/active"]);
    const helper = join(hookRoot, "helper.sh");
    await writeFile(
      helper,
      `#!/bin/sh\nprintf '%s\\n' '${ordinaryCase.label}-helper-executed' >> '${helperLog}'\n${ordinaryCase.reject ? "exit 27\n" : ""}`,
    );
    await chmod(helper, 0o755);
    const preCommit = join(activeHookDir, "pre-commit");
    await writeFile(
      preCommit,
      '#!/bin/sh\nhook_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n"$hook_dir/../helper.sh"\n',
    );
    await chmod(preCommit, 0o755);
    await writeFile(join(repo, "selected.txt"), `${ordinaryCase.label} ordinary hook candidate\n`);
    const beforeHead = await headOf(repo);
    const beforeCount = await commitCountOf(repo);
    const beforeIndex = await stagedTreeOf(repo);
    await setFakeGitleaksMode("success");
    const result = await execute(repo, `${ordinaryCase.label}-pre-commit-relative-helper`, {
      files: ["selected.txt"],
      commitMessage: `chore(test): ${ordinaryCase.label} ordinary helper`,
      dryRun: false,
      push: false,
    });
    if (ordinaryCase.reject) {
      assertError(result, /git .* failed|pre-commit/i, "rejecting ordinary pre-commit helper");
      await assertUnchangedHeadAndCommitCount(repo, beforeHead, beforeCount, "rejecting ordinary pre-commit helper");
      if (await stagedTreeOf(repo) !== beforeIndex) fail("rejecting ordinary pre-commit helper changed the real index");
      assertSameSet(await stagedPathsOf(repo), [], "rejecting ordinary pre-commit helper real index");
    } else {
      assertSucceeded(result, "accepting ordinary pre-commit helper");
      await assertReturnedHashMatchesHead(repo, result, "accepting ordinary pre-commit helper");
      await assertCommittedFiles(repo, ["HEAD^", "HEAD"], ["selected.txt"], "accepting ordinary pre-commit helper files");
    }
    if ((await readFile(helperLog, "utf8")) !== `${ordinaryCase.label}-helper-executed\n`) {
      fail(`${ordinaryCase.label} ordinary pre-commit did not resolve and execute its parent helper through dirname/$0`);
    }
    await assertScanContractAndCleanup(["selected.txt"], `${ordinaryCase.label} ordinary pre-commit helper`);
  }

  for (const spacedHookCase of [
    { label: "accepting", reject: false },
    { label: "rejecting", reject: true },
  ]) {
    const repo = await makeRepo(`${spacedHookCase.label}-spaced-hooks-path-`);
    const relativeHooksPath = ` ${spacedHookCase.label}-hooks `;
    const hooksDir = join(repo, relativeHooksPath);
    const hookLog = join(repo, `${spacedHookCase.label}-spaced-hook.log`);
    await mkdir(hooksDir);
    await git(repo, ["config", "core.hooksPath", relativeHooksPath]);
    const helper = join(hooksDir, "helper.sh");
    await writeFile(
      helper,
      `#!/bin/sh\nprintf '%s\\n' "$1" >> '${hookLog}'\n${spacedHookCase.reject ? "exit 29\n" : ""}`,
    );
    await chmod(helper, 0o755);
    const preCommit = join(hooksDir, "pre-commit");
    await writeFile(
      preCommit,
      '#!/bin/sh\nhook_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n"$hook_dir/helper.sh" "$0"\n',
    );
    await chmod(preCommit, 0o755);
    await writeFile(join(repo, "selected.txt"), `${spacedHookCase.label} spaced hook candidate\n`);
    const beforeHead = await headOf(repo);
    const beforeCount = await commitCountOf(repo);
    const beforeIndex = await stagedTreeOf(repo);
    await setFakeGitleaksMode("success");
    const result = await execute(repo, `${spacedHookCase.label}-spaced-hooks-path`, {
      files: ["selected.txt"],
      commitMessage: `chore(test): ${spacedHookCase.label} spaced hook path`,
      dryRun: false,
      push: false,
    });
    const caseLabel = `${spacedHookCase.label} spaced hooks path`;
    if (spacedHookCase.reject) {
      assertError(result, /git .* failed|pre-commit/i, caseLabel);
      await assertUnchangedHeadAndCommitCount(repo, beforeHead, beforeCount, caseLabel);
      if (await stagedTreeOf(repo) !== beforeIndex) fail(`${caseLabel} changed the real index`);
      assertSameSet(await stagedPathsOf(repo), [], `${caseLabel} real index`);
    } else {
      assertSucceeded(result, caseLabel);
      await assertReturnedHashMatchesHead(repo, result, caseLabel);
      await assertCommittedFiles(repo, ["HEAD^", "HEAD"], ["selected.txt"], `${caseLabel} files`);
    }
    const observedHookLog = await readFile(hookLog, "utf8");
    if (!observedHookLog.endsWith("\n") || observedHookLog.slice(0, -1).includes("\n")) {
      fail(`${caseLabel} logged a malformed original pre-commit $0: ${JSON.stringify(observedHookLog)}`);
    }
    const observedHookPath = observedHookLog.slice(0, -1);
    if (!observedHookPath.endsWith(`/${relativeHooksPath}/pre-commit`) ||
      await realpath(observedHookPath) !== await realpath(preCommit)) {
      fail(`${caseLabel} did not preserve and resolve the original pre-commit $0 through its spaced configured path: ${JSON.stringify({ observedHookPath, preCommit })}`);
    }
    await assertScanContractAndCleanup(["selected.txt"], caseLabel);
  }

  const inactiveSpacedHookRepo = await makeRepo("inactive-spaced-hooks-path-");
  const inactiveRelativeHooksPath = " inactive-hooks ";
  const inactiveHooksDir = join(inactiveSpacedHookRepo, inactiveRelativeHooksPath);
  const inactiveHookLog = join(inactiveSpacedHookRepo, "inactive-spaced-hook.log");
  await mkdir(inactiveHooksDir);
  await git(inactiveSpacedHookRepo, ["config", "core.hooksPath", inactiveRelativeHooksPath]);
  await writeFile(
    join(inactiveHooksDir, "pre-commit"),
    `#!/bin/sh\nprintf 'ran\\n' >> '${inactiveHookLog}'\nexit 31\n`,
  );
  await chmod(join(inactiveHooksDir, "pre-commit"), 0o644);
  await writeFile(join(inactiveSpacedHookRepo, "selected.txt"), "inactive spaced hook candidate\n");
  await setFakeGitleaksMode("success");
  const inactiveSpacedHookResult = await execute(inactiveSpacedHookRepo, "inactive-spaced-hooks-path", {
    files: ["selected.txt"],
    commitMessage: "chore(test): ignore inactive spaced hook",
    dryRun: false,
    push: false,
  });
  assertSucceeded(inactiveSpacedHookResult, "inactive spaced hooks path");
  await assertReturnedHashMatchesHead(inactiveSpacedHookRepo, inactiveSpacedHookResult, "inactive spaced hooks path");
  await assertCommittedFiles(
    inactiveSpacedHookRepo,
    ["HEAD^", "HEAD"],
    ["selected.txt"],
    "inactive spaced hooks path files",
  );
  if (await exists(inactiveHookLog)) fail("inactive spaced pre-commit hook ran despite lacking execute permission");
  await assertScanContractAndCleanup(["selected.txt"], "inactive spaced hooks path");


  const siblingHookRepo = await makeRepo("commit-msg-sibling-helper-");
  const siblingHooksDir = join(siblingHookRepo, "hooks");
  const siblingHookLog = join(siblingHookRepo, "sibling-hook.log");
  await mkdir(siblingHooksDir);
  await git(siblingHookRepo, ["config", "core.hooksPath", "hooks"]);
  await writeFile(
    join(siblingHooksDir, "helper.sh"),
    `record_sibling_hook() { printf '%s\\n' sibling-helper-loaded >> '${siblingHookLog}'; }\n`,
  );
  const siblingCommitMsg = join(siblingHooksDir, "commit-msg");
  await writeFile(
    siblingCommitMsg,
    `#!/bin/sh\nhook_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n. "$hook_dir/helper.sh"\nrecord_sibling_hook "$1"\n`,
  );
  await chmod(siblingCommitMsg, 0o755);
  await writeFile(join(siblingHookRepo, "selected.txt"), "sibling hook candidate\n");
  await setFakeGitleaksMode("success");
  const siblingHookResult = await execute(siblingHookRepo, "commit-msg-sibling-helper", {
    files: ["selected.txt"],
    commitMessage: "chore(test): load commit hook sibling",
    dryRun: false,
    push: false,
  });
  assertSucceeded(siblingHookResult, "commit-msg sibling helper");
  await assertReturnedHashMatchesHead(siblingHookRepo, siblingHookResult, "commit-msg sibling helper");
  if ((await readFile(siblingHookLog, "utf8")) !== "sibling-helper-loaded\n") {
    fail("original commit-msg did not resolve its sibling helper through dirname/$0");
  }
  await assertScanContractAndCleanup(["selected.txt"], "commit-msg sibling helper");

  const nullHooksRepo = await makeRepo("null-hooks-path-");
  await git(nullHooksRepo, ["config", "core.hooksPath", "/dev/null"]);
  await writeFile(join(nullHooksRepo, "selected.txt"), "no original hooks\n");
  await setFakeGitleaksMode("success");
  const nullHooksResult = await execute(nullHooksRepo, "null-hooks-path", {
    files: ["selected.txt"],
    commitMessage: "chore(test): tolerate null hooks path",
    dryRun: false,
    push: false,
  });
  assertSucceeded(nullHooksResult, "non-directory hooks path");
  await assertReturnedHashMatchesHead(nullHooksRepo, nullHooksResult, "non-directory hooks path");
  await assertScanContractAndCleanup(["selected.txt"], "non-directory hooks path");

  for (const mutatingHook of ["pre-commit", "prepare-commit-msg"]) {
    const repo = await makeRepo(`${mutatingHook}-tree-guard-`);
    const hookDir = join(repo, "hooks");
    const hookLog = join(repo, "hook.log");
    await mkdir(hookDir);
    await git(repo, ["config", "core.hooksPath", hookDir]);
    await writeFile(join(repo, "selected.txt"), "scanned\n");
    await writeFile(join(repo, "hook-added.txt"), "candidate mutation\n");
    for (const hook of ["pre-commit", "prepare-commit-msg", "commit-msg", "post-commit"]) {
      const body = hook === mutatingHook
        ? `printf '%s\\n' '${hook}' >> '${hookLog}'\ngit add -- hook-added.txt\n`
        : `printf '%s\\n' '${hook}' >> '${hookLog}'\n`;
      await writeFile(join(hookDir, hook), `#!/bin/sh\n${body}`);
      await chmod(join(hookDir, hook), 0o755);
    }
    const beforeHead = await headOf(repo);
    const beforeCount = await commitCountOf(repo);
    const beforeIndex = await stagedTreeOf(repo);
    await setFakeGitleaksMode("success");
    const result = await execute(repo, `${mutatingHook}-tree-guard`, {
      files: ["selected.txt"],
      commitMessage: `chore(test): guard ${mutatingHook} mutation`,
      dryRun: false,
      push: false,
    });
    assertError(result, /Commit blocked because a hook changed the scanned candidate|Git command failed/i, `${mutatingHook} tree guard`);
    await assertUnchangedHeadAndCommitCount(repo, beforeHead, beforeCount, `${mutatingHook} tree guard`);
    if (await stagedTreeOf(repo) !== beforeIndex) fail(`${mutatingHook} tree guard changed real index`);
    const ranHooks = (await readFile(hookLog, "utf8")).trim().split("\n");
    if (!ranHooks.includes("commit-msg")) fail(`${mutatingHook} tree guard did not reach commit-msg`);
    if (ranHooks.includes("post-commit")) fail(`${mutatingHook} tree guard ran post-commit`);
    await assertScanContractAndCleanup(["selected.txt"], `${mutatingHook} tree guard`);
  }

  const branchSwitchRepo = await makeRepo("same-base-branch-switch-");
  const branchSwitchHooks = join(branchSwitchRepo, "hooks");
  await mkdir(branchSwitchHooks);
  await git(branchSwitchRepo, ["config", "core.hooksPath", "hooks"]);
  const branchSwitchBase = await headOf(branchSwitchRepo);
  await git(branchSwitchRepo, ["branch", "same-base-sibling", branchSwitchBase]);
  const branchSwitchHook = join(branchSwitchHooks, "commit-msg");
  await writeFile(
    branchSwitchHook,
    "#!/bin/sh\ngit symbolic-ref HEAD refs/heads/same-base-sibling\n",
  );
  await chmod(branchSwitchHook, 0o755);
  await writeFile(join(branchSwitchRepo, "selected.txt"), "same-base branch switch\n");
  await setFakeGitleaksMode("success");
  const branchSwitchResult = await execute(branchSwitchRepo, "same-base-branch-switch", {
    files: ["selected.txt"],
    commitMessage: "chore(test): reject same-base branch switch",
    dryRun: false,
    push: false,
  });
  assertError(
    branchSwitchResult,
    /repository reference changed after scanning|Git command failed|git .* failed/i,
    "same-base branch switch",
  );
  if ((await git(branchSwitchRepo, ["symbolic-ref", "HEAD"])).stdout.trim() !== "refs/heads/same-base-sibling") {
    fail("same-base branch switch fixture did not change the symbolic HEAD");
  }
  for (const ref of ["refs/heads/main", "refs/heads/same-base-sibling"]) {
    if ((await git(branchSwitchRepo, ["rev-parse", ref])).stdout.trim() !== branchSwitchBase) {
      fail(`same-base branch switch unexpectedly advanced ${ref}`);
    }
  }
  if (hashOf(branchSwitchResult)) fail("same-base branch switch returned a commit receipt");
  await assertScanContractAndCleanup(["selected.txt"], "same-base branch switch");

  const sameTreeRepo = await makeRepo("same-tree-external-");
  const sameTreeHooks = join(sameTreeRepo, "hooks");
  await mkdir(sameTreeHooks);
  await git(sameTreeRepo, ["config", "core.hooksPath", "hooks"]);
  const sameTreeBase = await headOf(sameTreeRepo);
  const sameTreeRef = (await git(sameTreeRepo, ["symbolic-ref", "HEAD"])).stdout.trim();
  const sameTreeHook = join(sameTreeHooks, "commit-msg");
  await writeFile(
    sameTreeHook,
    `#!/bin/sh\ntree=$(git write-tree) || exit 30\nbase=$(git rev-parse HEAD) || exit 30\nexternal=$(printf '%s\\n' 'chore(test): concurrent same-tree commit' | git commit-tree "$tree" -p "$base") || exit 30\ngit update-ref '${sameTreeRef}' "$external" "$base" || exit 30\nexit 31\n`,
  );
  await chmod(sameTreeHook, 0o755);
  await writeFile(join(sameTreeRepo, "selected.txt"), "same scanned tree bytes\n");
  await setFakeGitleaksMode("success");
  const sameTreeResult = await execute(sameTreeRepo, "same-tree-external", {
    files: ["selected.txt"],
    commitMessage: "chore(test): reject matching external commit",
    dryRun: false,
    push: false,
  });
  assertError(sameTreeResult, /git .* failed|Git command failed/i, "same-tree external commit");
  const externalSameTree = await headOf(sameTreeRepo);
  if (externalSameTree === sameTreeBase) fail("same-tree external fixture did not advance the branch");
  const externalParents = (await git(sameTreeRepo, ["rev-list", "--parents", "-n", "1", externalSameTree])).stdout.trim();
  if (externalParents !== `${externalSameTree} ${sameTreeBase}`) {
    fail("same-tree external fixture created unexpected ancestry");
  }
  if ((await git(sameTreeRepo, ["show", "-s", "--format=%s", externalSameTree])).stdout.trim() !==
    "chore(test): concurrent same-tree commit") {
    fail("same-tree external fixture did not preserve the concurrent commit");
  }
  if (hashOf(sameTreeResult)) fail("same-tree external commit was mistaken for this transaction");
  await assertScanContractAndCleanup(["selected.txt"], "same-tree external commit");

  const legacyScannerRepo = await makeRepo("gitleaks-legacy-only-");
  await writeFile(join(legacyScannerRepo, "legacy.txt"), "legacy scanner fixture\n");
  const legacyScannerHead = await headOf(legacyScannerRepo);
  const legacyScannerCount = await commitCountOf(legacyScannerRepo);
  const legacyScannerIndex = await stagedTreeOf(legacyScannerRepo);
  await setFakeGitleaksMode("legacy-only");
  const legacyOnly = await execute(legacyScannerRepo, "gitleaks-legacy-only", {
    files: ["legacy.txt"],
    commitMessage: "chore(test): reject legacy scanner",
    dryRun: false,
    push: false,
  });
  assertErrorMessage(legacyOnly, "Gitleaks is unavailable or incompatible; commit was not created.", "legacy-only gitleaks");
  await assertUnchangedHeadAndCommitCount(legacyScannerRepo, legacyScannerHead, legacyScannerCount, "legacy-only gitleaks");
  if (await stagedTreeOf(legacyScannerRepo) !== legacyScannerIndex) fail("legacy-only gitleaks changed real index");
  const legacyScannerLog = await readFile(join(gitleaksControlDir, "scan-log"), "utf8");
  assertIncludes(legacyScannerLog, "capability=dir-help", "legacy-only directory capability probe");
  assertIncludes(legacyScannerLog, "capability=stdin-help", "legacy-only stdin capability probe");
  assertExcludes(legacyScannerLog, "pass=dir", "legacy-only directory scan");
  assertExcludes(legacyScannerLog, "pass=stdin", "legacy-only stdin scan");

  const detachedRepo = await makeRepo("detached-head-");
  const detachedBase = await headOf(detachedRepo);
  await git(detachedRepo, ["checkout", "--detach", detachedBase]);
  await writeFile(join(detachedRepo, "detached.txt"), "detached candidate\n");
  await setFakeGitleaksMode("success");
  const detachedResult = await execute(detachedRepo, "detached-head", {
    files: ["detached.txt"],
    commitMessage: "chore(test): commit detached candidate",
    dryRun: false,
    push: false,
  });
  assertSucceeded(detachedResult, "detached HEAD commit");
  await assertReturnedHashMatchesHead(detachedRepo, detachedResult, "detached HEAD commit");
  const detachedHead = await headOf(detachedRepo);
  if ((await git(detachedRepo, ["rev-list", "--parents", "-n", "1", detachedHead])).stdout.trim() !==
    `${detachedHead} ${detachedBase}`) {
    fail("detached HEAD commit recorded unexpected ancestry");
  }
  if ((await git(detachedRepo, ["symbolic-ref", "-q", "HEAD"], { allowFailure: true })).exitCode !== 1) {
    fail("detached HEAD commit unexpectedly attached HEAD to a branch");
  }
  await assertScanContractAndCleanup(["detached.txt"], "detached HEAD commit");

  const unbornRepo = await tempDir("omp-commit-ui-unborn-");
  await git(unbornRepo, ["init"]);
  await git(unbornRepo, ["config", "user.email", "commit-ui-test@example.invalid"]);
  await git(unbornRepo, ["config", "user.name", "Commit UI Test"]);
  await writeFile(join(unbornRepo, "first.txt"), "first commit\n");
  await setFakeGitleaksMode("success");
  const unborn = await execute(unbornRepo, "unborn-first-commit", {
    files: ["first.txt"],
    commitMessage: "chore(test): create first commit",
    dryRun: false,
    push: false,
  });
  assertSucceeded(unborn, "unborn first commit");
  if (await commitCountOf(unbornRepo) !== 1) fail("unborn repository did not create exactly one commit");
  const unbornScan = await assertScanContractAndCleanup(["first.txt"], "unborn first commit");
  if ((await git(unbornRepo, ["rev-parse", "HEAD^{tree}"])).stdout.trim() !== unbornScan.tree) {
    fail("unborn first commit differed from scanned candidate");
  }


  await assertReturnedHashMatchesHead(unbornRepo, unborn, "unborn first commit");
  const unbornRef = (await git(unbornRepo, ["symbolic-ref", "HEAD"])).stdout.trim();
  if (!unbornRef.startsWith("refs/heads/")) fail("unborn first commit did not preserve its symbolic branch");

  const sha256Repo = await tempDir("omp-commit-ui-sha256-");
  const sha256Init = await git(sha256Repo, ["init", "--object-format=sha256"], { allowFailure: true });
  if (sha256Init.exitCode === 0) {
    await git(sha256Repo, ["config", "user.email", "commit-ui-test@example.invalid"]);
    await git(sha256Repo, ["config", "user.name", "Commit UI Test"]);
    await writeFile(join(sha256Repo, "base.txt"), "sha256 base\n");
    await git(sha256Repo, ["add", "--", "base.txt"]);
    await git(sha256Repo, ["commit", "-m", "chore(test): initial sha256 fixture"]);
    await writeFile(join(sha256Repo, "selected.txt"), "sha256 candidate\n");
    await setFakeGitleaksMode("success");
    const sha256Result = await execute(sha256Repo, "sha256-commit", {
      files: ["selected.txt"],
      commitMessage: "chore(test): commit sha256 candidate",
      dryRun: false,
      push: false,
    });
    assertSucceeded(sha256Result, "SHA-256 commit");
    await assertReturnedHashMatchesHead(sha256Repo, sha256Result, "SHA-256 commit");
    if (!/^[0-9a-f]{64}$/.test(await headOf(sha256Repo))) fail("SHA-256 commit did not return a 64-character OID");
    const sha256Scan = await assertScanContractAndCleanup(["selected.txt"], "SHA-256 commit");
    if (!/^[0-9a-f]{64}$/.test(sha256Scan.tree)) fail("SHA-256 scan did not record a 64-character tree OID");
  } else {
    console.log("SKIP: Git does not support SHA-256 repositories");
  }

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
  await writeFile(join(renameRepo, "delete-isolated.txt"), "leave deletion uncommitted\n");
  await git(renameRepo, ["add", "rename-source.txt", "delete-isolated.txt"]);
  await git(renameRepo, ["commit", "-m", "chore(test): add rename and delete sources"]);
  await git(renameRepo, ["mv", "rename-source.txt", "rename-destination.txt"]);
  await rm(join(renameRepo, "delete-isolated.txt"));
  const renameStatusPaths = parseStatusPaths((await git(renameRepo, ["status", "--porcelain=v1", "-z", "--untracked-files=all"])).stdout);
  assertSameSet(renameStatusPaths, ["rename-destination.txt", "delete-isolated.txt"], "rename/delete porcelain isolation");
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
  if (!ignoredFilesOf(renameResult).includes("delete-isolated.txt")) {
    fail(`rename selection did not isolate unrelated deletion: ${JSON.stringify(renameResult.details)}`);
  }
  const renameNameStatus = (await git(renameRepo, ["diff", "--name-status", "HEAD^", "HEAD"])).stdout.trim();
  if (!/^R\d*\s+rename-source\.txt\s+rename-destination\.txt$/m.test(renameNameStatus)) {
    fail(`rename destination commit did not preserve the rename: ${renameNameStatus}`);
  }
  const renameFinalStatus = (await git(renameRepo, ["status", "--porcelain"])).stdout;
  assertIncludes(renameFinalStatus, " D delete-isolated.txt", "rename commit preserved isolated deletion");

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
