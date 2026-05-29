import type { Component } from "@oh-my-pi/pi-tui";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const TOOL_NAME = "omp_commit";
const MAX_VISIBLE_STEPS = 7;
const MAX_FINAL_LINES = 8;
const MAX_OUTPUT_CHARS = 2_000;
const MAX_SECRET_SCAN_CHARS = 2_000_000;

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const CONVENTIONAL_COMMIT_RE = /^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?: .+/;
const MUTATING_GIT_VERBS = new Set(["add", "am", "apply", "checkout", "cherry-pick", "clean", "commit", "merge", "mv", "pull", "push", "rebase", "reset", "restore", "revert", "rm", "stash", "switch"]);

const SECRET_PATTERNS: Array<{ name: string; pattern: RegExp }> = [
	{ name: "private key", pattern: /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/ },
	{ name: "AWS access key", pattern: /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/ },
	{ name: "GitHub token", pattern: /\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/ },
	{ name: "Slack token", pattern: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/ },
	{ name: "generic secret assignment", pattern: /(?:password|passwd|pwd|secret|api[_-]?key|access[_-]?key|token)\s*[:=]\s*["']?[^"'\s]{12,}/i },
];

type RunStatus = "running" | "succeeded" | "failed";
type StepStatus = "running" | "done" | "failed";

interface CommitStep {
	label: string;
	status: StepStatus;
	startedAt: number;
	finishedAt?: number;
}

interface VerificationPlan {
	command: string;
	args?: string[];
	description?: string;
	required?: boolean;
}

interface CommitToolParams {
	files?: string[];
	commitMessage?: string;
	rationale?: string;
	verification?: VerificationPlan[];
	context?: string;
	dryRun?: boolean;
	push?: boolean;
	acceptRisk?: boolean;
}

interface CommitPlan {
	files: string[];
	commitMessage: string;
	rationale: string;
	verification: VerificationPlan[];
	context: string;
	dryRun: boolean;
	push: boolean;
	acceptRisk: boolean;
}

interface ParsedArgs {
	dryRun: boolean;
	push: boolean;
	acceptRisk: boolean;
	context: string;
	model?: string;
}

interface GitStatusEntry {
	code: string;
	path: string;
}

interface CommandResult {
	stdout: string;
	stderr: string;
	exitCode: number;
}

interface CommitRunDetails {
	id: string;
	status: RunStatus;
	phase: string;
	startedAt: number;
	finishedAt?: number;
	steps: CommitStep[];
	toolCount: number;
	failedToolCount: number;
	dryRun: boolean;
	push: boolean;
	acceptRisk: boolean;
	context?: string;
	rationale?: string;
	commitMessage?: string;
	selectedFiles: string[];
	ignoredFiles: string[];
	verificationCount: number;
	commitHash?: string;
	finalText?: string;
	errorText?: string;
	warnings: string[];
}

class WorkflowError extends Error {}
class CommandError extends WorkflowError {
	constructor(
		message: string,
		readonly result: CommandResult,
	) {
		super(message);
	}
}

export default function commitUi(pi: ExtensionAPI): void {
	const z = pi.zod;
	let restoreActiveTools: string[] | undefined;

	pi.setLabel?.("commit UI");

	pi.registerTool({
		name: TOOL_NAME,
		label: "Commit",
		description: "Execute a reviewed commit plan in-process with one live progress card and hidden git operations.",
		defaultInactive: true,
		parameters: z.object({
			files: z.array(z.string()).optional().describe("Repo-relative files or directories to include. Leave empty only to block safely when the current context is insufficient."),
			commitMessage: z.string().optional().describe("Conventional commit message to use. The first line must be conventional-commit formatted."),
			rationale: z.string().optional().describe("Why these files and this message match the current conversation context."),
			verification: z.array(z.object({
				command: z.string().describe("Verification executable, without shell wrapping."),
				args: z.array(z.string()).optional().describe("Executable arguments."),
				description: z.string().optional().describe("Short human label for the verification."),
				required: z.boolean().optional().describe("Reserved for display; failing verification still blocks."),
			})).optional().describe("Narrow verification commands to run before staging/committing."),
			context: z.string().optional().describe("Additional slash-command context."),
			dryRun: z.boolean().optional().describe("Validate and preview without staging, committing, or pushing."),
			push: z.boolean().optional().describe("Push after a successful commit."),
			acceptRisk: z.boolean().optional().describe("Allow committing without verification only when the user explicitly passed --accept-risk."),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const plan = normalizeCommitPlan(params);
			const details = createRunDetails(plan);
			const emit = () => onUpdate?.({ content: [{ type: "text", text: details.phase }], details });
			emit();

			try {
				await executeCommitPlan(plan, ctx.cwd, details, emit, signal);
			} catch (error) {
				details.status = "failed";
				details.failedToolCount += 1;
				details.errorText = formatError(error);
				details.phase = "Commit workflow blocked";
				details.finishedAt = Date.now();
				finishRunningSteps(details, "failed");
				emit();
			}

			return {
				content: [{ type: "text", text: buildToolResultText(details) }],
				details,
				isError: details.status === "failed",
			};
		},
		renderCall(args, _options, theme) {
			return new CommitCallComponent(normalizeCommitPlan(args), theme);
		},
		renderResult(result, options, theme) {
			if (!isCommitRunDetails(result.details)) {
				const text = result.content.find(item => item.type === "text")?.text ?? "Commit workflow";
				return new StaticLinesComponent([theme.fg("muted", text)], theme);
			}
			return new CommitRunComponent(result.details, Boolean(options.expanded), theme, options.spinnerFrame);
		},
	});

	pi.registerCommand("commit", {
		description: "Plan from current context, then commit behind one live progress card",
		handler: async (args, ctx) => {
			if (restoreActiveTools) {
				ctx.ui.notify("A commit workflow is already running.", "warning");
				return;
			}

			const parsed = parseCommitArgs(args);
			if (!ctx.isIdle()) {
				ctx.ui.notify("Commit queued until the current turn finishes.", "info");
				await ctx.waitForIdle();
			}

			restoreActiveTools = pi.getActiveTools();
			await pi.setActiveTools([TOOL_NAME]);
			pi.sendMessage(
				{
					customType: "commit-request",
					content: await buildToolInvocationPrompt(parsed),
					display: false,
					details: parsed,
					attribution: "user",
				},
				{ triggerTurn: true, deliverAs: "nextTurn" },
			);
		},
	});

	const restoreTools = async () => {
		if (!restoreActiveTools) return;
		const tools = restoreActiveTools;
		restoreActiveTools = undefined;
		await pi.setActiveTools(tools);
	};

	pi.on("turn_end", restoreTools);
	pi.on("agent_end", restoreTools);
}

class CommitCallComponent implements Component {
	constructor(
		private readonly plan: CommitPlan,
		private readonly theme: any,
	) {}

	invalidate(): void {}

	render(width: number): string[] {
		const title = this.plan.dryRun ? "Commit preview" : "Commit";
		const lines = [`${this.theme.fg("accent", "●")} ${this.theme.fg("accent", this.theme.bold(title))}`];
		const flags = [
			this.plan.push ? "push" : undefined,
			this.plan.acceptRisk ? "risk accepted" : undefined,
			this.plan.files.length > 0 ? `${this.plan.files.length} file${this.plan.files.length === 1 ? "" : "s"}` : "no files selected",
		].filter(Boolean);
		lines.push(` ${this.theme.fg("dim", this.theme.tree.branch)} ${this.theme.fg("dim", flags.join(" · "))}`);
		if (this.plan.commitMessage) {
			lines.push(` ${this.theme.fg("dim", this.theme.tree.branch)} ${this.theme.fg("muted", this.plan.commitMessage.split("\n", 1)[0])}`);
		}
		if (this.plan.rationale || this.plan.context) {
			lines.push(` ${this.theme.fg("dim", this.theme.tree.last)} ${this.theme.fg("muted", this.plan.rationale || this.plan.context)}`);
		}
		return lines.map(line => truncateVisible(line, Math.max(20, width)));
	}
}

class CommitRunComponent implements Component {
	constructor(
		private readonly details: CommitRunDetails,
		private readonly expanded: boolean,
		private readonly theme: any,
		private readonly spinnerFrame?: number,
	) {}

	invalidate(): void {}

	render(width: number): string[] {
		const lines = renderCommitRun(this.details, this.expanded, this.theme, this.spinnerFrame);
		return lines.map(line => truncateVisible(line, Math.max(20, width)));
	}
}

class StaticLinesComponent implements Component {
	constructor(
		private readonly lines: string[],
		private readonly _theme: any,
	) {}

	invalidate(): void {}

	render(width: number): string[] {
		return this.lines.map(line => truncateVisible(line, Math.max(20, width)));
	}
}

async function executeCommitPlan(
	plan: CommitPlan,
	cwd: string,
	details: CommitRunDetails,
	onUpdate: () => void,
	signal: AbortSignal | undefined,
): Promise<void> {
	throwIfAborted(signal);
	await withStep(details, "Validating commit plan", onUpdate, async () => validateCommitPlan(plan));

	const repoRoot = await withStep(details, "Inspecting working tree", onUpdate, async () => {
		const root = (await runGit(cwd, ["rev-parse", "--show-toplevel"], signal, details)).stdout.trim();
		const status = parseStatusZ((await runGit(cwd, ["status", "--porcelain=v1", "-z", "--untracked-files=all"], signal, details)).stdout);
		if (status.length === 0) throw new WorkflowError("No working tree changes to commit.");

		const { selected, unmatched } = resolveSelectedFiles(plan.files, status);
		if (plan.files.length === 0) {
			throw new WorkflowError(`No files were selected from the current conversation context. Changed files: ${status.map(entry => entry.path).join(", ")}`);
		}
		if (unmatched.length > 0) {
			throw new WorkflowError(`Requested files are not changed: ${unmatched.join(", ")}`);
		}
		if (selected.length === 0) {
			throw new WorkflowError("Selected files do not match any working tree changes.");
		}

		details.selectedFiles = selected;
		details.ignoredFiles = status.map(entry => entry.path).filter(path => !selected.includes(path));

		const staged = parseZPaths((await runGit(cwd, ["diff", "--cached", "--name-only", "-z"], signal, details)).stdout);
		const unrelatedStaged = staged.filter(path => !selected.includes(path));
		if (unrelatedStaged.length > 0) {
			throw new WorkflowError(`Unrelated staged changes would be at risk: ${unrelatedStaged.join(", ")}. Unstage or include them explicitly.`);
		}
		return root;
	});

	const scanText = await withStep(details, "Reviewing selected diff", onUpdate, () => collectSecretScanText(cwd, repoRoot, details.selectedFiles, signal, details));
	await withStep(details, "Checking for secrets", onUpdate, async () => scanForSecrets(scanText));
	await withStep(details, "Running verification", onUpdate, async () => runVerification(plan, cwd, signal, details));

	if (plan.dryRun) {
		details.status = "succeeded";
		details.phase = "Commit preview complete";
		details.finalText = buildDryRunText(details);
		details.finishedAt = Date.now();
		onUpdate();
		return;
	}

	await withStep(details, "Staging selected changes", onUpdate, () => runGit(cwd, ["add", "--", ...details.selectedFiles], signal, details));
	await withStep(details, "Creating commit", onUpdate, () => runGit(cwd, ["commit", "--only", "-m", plan.commitMessage, "--", ...details.selectedFiles], signal, details));
	const commitHash = (await withStep(details, "Checking commit result", onUpdate, () => runGit(cwd, ["rev-parse", "--short", "HEAD"], signal, details))).stdout.trim();
	details.commitHash = commitHash;

	if (plan.push) {
		await withStep(details, "Pushing branch", onUpdate, () => runGit(cwd, ["push"], signal, details));
	}

	details.status = "succeeded";
	details.phase = plan.push ? "Commit created and pushed" : "Commit created";
	details.finalText = buildSuccessText(details);
	details.finishedAt = Date.now();
	onUpdate();
}

async function withStep<T>(details: CommitRunDetails, label: string, onUpdate: () => void, fn: () => Promise<T> | T): Promise<T> {
	upsertStep(details, label, "running");
	details.phase = label;
	onUpdate();
	try {
		const result = await fn();
		upsertStep(details, label, "done");
		onUpdate();
		return result;
	} catch (error) {
		upsertStep(details, label, "failed");
		onUpdate();
		throw error;
	}
}

function normalizeCommitPlan(params: CommitToolParams): CommitPlan {
	return {
		files: dedupe((params.files ?? []).map(file => file.trim()).filter(Boolean)),
		commitMessage: params.commitMessage?.trim() ?? "",
		rationale: params.rationale?.trim() ?? "",
		verification: (params.verification ?? []).map(item => ({
			command: item.command?.trim() ?? "",
			args: Array.isArray(item.args) ? item.args.map(arg => String(arg)) : [],
			description: item.description?.trim() || undefined,
			required: item.required,
		})),
		context: params.context?.trim() ?? "",
		dryRun: Boolean(params.dryRun),
		push: Boolean(params.push),
		acceptRisk: Boolean(params.acceptRisk),
	};
}

function createRunDetails(plan: CommitPlan): CommitRunDetails {
	return {
		id: `commit-${Date.now().toString(36)}`,
		status: "running",
		phase: "Starting commit workflow",
		startedAt: Date.now(),
		steps: [],
		toolCount: 0,
		failedToolCount: 0,
		dryRun: plan.dryRun,
		push: plan.push,
		acceptRisk: plan.acceptRisk,
		context: plan.context || undefined,
		rationale: plan.rationale || undefined,
		commitMessage: plan.commitMessage || undefined,
		selectedFiles: [],
		ignoredFiles: [],
		verificationCount: plan.verification.length,
		warnings: [],
	};
}

function validateCommitPlan(plan: CommitPlan): void {
	if (!plan.commitMessage) throw new WorkflowError("Commit message is required.");
	if (plan.commitMessage.includes("\0")) throw new WorkflowError("Commit message contains a NUL byte.");
	const subject = plan.commitMessage.split("\n", 1)[0];
	if (!CONVENTIONAL_COMMIT_RE.test(subject)) {
		throw new WorkflowError(`Commit message must be conventional-commit formatted. Received: ${subject}`);
	}
	for (const file of plan.files) validateRepoPath(file);
	if (plan.verification.length === 0 && !plan.acceptRisk) {
		throw new WorkflowError("No verification command was provided. Pass verification commands or rerun /commit --accept-risk only if the user accepts that risk.");
	}
	for (const verification of plan.verification) validateVerification(verification);
}

function validateRepoPath(path: string): void {
	if (!path) throw new WorkflowError("Selected file path is empty.");
	if (path.includes("\0")) throw new WorkflowError(`Selected file path contains a NUL byte: ${path}`);
	if (path.startsWith("/") || path.startsWith("~")) throw new WorkflowError(`Selected file path must be repo-relative: ${path}`);
	if (path.split(/[\\/]+/).includes("..")) throw new WorkflowError(`Selected file path must not traverse directories: ${path}`);
}

function validateVerification(verification: VerificationPlan): void {
	if (!verification.command) throw new WorkflowError("Verification command is empty.");
	if (verification.command.includes("/") || verification.command.includes("\0")) {
		throw new WorkflowError(`Verification command must be an executable name, not a path: ${verification.command}`);
	}
	const args = verification.args ?? [];
	if (verification.command === "git" && args.length > 0 && MUTATING_GIT_VERBS.has(args[0])) {
		throw new WorkflowError(`Verification command may not mutate git state: git ${args[0]}`);
	}
	for (const arg of args) {
		if (arg.includes("\0")) throw new WorkflowError("Verification argument contains a NUL byte.");
	}
}

async function runVerification(plan: CommitPlan, cwd: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<void> {
	if (plan.verification.length === 0) {
		details.warnings.push("No verification was run because --accept-risk was set.");
		return;
	}
	for (const verification of plan.verification) {
		const label = verification.description || [verification.command, ...(verification.args ?? [])].join(" ");
		details.phase = `Running verification: ${label}`;
		const result = await runCommand(cwd, verification.command, verification.args ?? [], signal, details);
		if (result.exitCode !== 0) {
			throw new WorkflowError(`Verification failed: ${label}\n${trimOutput(result.stderr || result.stdout)}`);
		}
	}
}

async function collectSecretScanText(cwd: string, repoRoot: string, selectedFiles: string[], signal: AbortSignal | undefined, details: CommitRunDetails): Promise<string> {
	const diff = await runGit(cwd, ["diff", "--no-ext-diff", "HEAD", "--", ...selectedFiles], signal, details);
	let text = diff.stdout;
	if (text.length > MAX_SECRET_SCAN_CHARS) {
		throw new WorkflowError("Selected diff is too large to secret-scan safely.");
	}
	const untracked = parseZPaths((await runGit(cwd, ["ls-files", "--others", "--exclude-standard", "-z", "--", ...selectedFiles], signal, details)).stdout);
	for (const file of untracked) {
		validateRepoPath(file);
		const blob = Bun.file(`${repoRoot}/${file}`);
		if (blob.size > MAX_SECRET_SCAN_CHARS) throw new WorkflowError(`Untracked file is too large to secret-scan safely: ${file}`);
		text += `\n--- untracked file: ${file} ---\n${await blob.text()}`;
		if (text.length > MAX_SECRET_SCAN_CHARS) throw new WorkflowError("Selected files are too large to secret-scan safely.");
	}
	return text;
}

function scanForSecrets(text: string): void {
	for (const { name, pattern } of SECRET_PATTERNS) {
		if (pattern.test(text)) throw new WorkflowError(`Potential ${name} found in selected changes; commit blocked.`);
	}
}

async function runGit(cwd: string, args: string[], signal: AbortSignal | undefined, details: CommitRunDetails): Promise<CommandResult> {
	const result = await runCommand(cwd, "git", args, signal, details);
	if (result.exitCode !== 0) {
		throw new CommandError(`git ${args[0] ?? ""} failed\n${trimOutput(result.stderr || result.stdout)}`, result);
	}
	return result;
}

async function runCommand(cwd: string, command: string, args: string[], signal: AbortSignal | undefined, details: CommitRunDetails): Promise<CommandResult> {
	throwIfAborted(signal);
	details.toolCount += 1;
	const child = Bun.spawn({
		cmd: [command, ...args],
		cwd,
		stdin: "ignore",
		stdout: "pipe",
		stderr: "pipe",
	});
	const abortChild = () => child.kill();
	signal?.addEventListener("abort", abortChild, { once: true });
	try {
		const [stdout, stderr, exitCode] = await Promise.all([readStream(child.stdout), readStream(child.stderr), child.exited]);
		return { stdout, stderr, exitCode };
	} finally {
		signal?.removeEventListener("abort", abortChild);
	}
}

async function readStream(stream: ReadableStream<Uint8Array> | null): Promise<string> {
	if (!stream) return "";
	return new Response(stream).text();
}

function parseStatusZ(raw: string): GitStatusEntry[] {
	const parts = raw.split("\0").filter(Boolean);
	const entries: GitStatusEntry[] = [];
	for (let index = 0; index < parts.length; index += 1) {
		const entry = parts[index];
		if (entry.length < 4) continue;
		const code = entry.slice(0, 2);
		const path = entry.slice(3);
		entries.push({ code, path });
		if ((code.includes("R") || code.includes("C")) && index + 1 < parts.length) index += 1;
	}
	return entries;
}

function parseZPaths(raw: string): string[] {
	return raw.split("\0").filter(Boolean);
}

function resolveSelectedFiles(requested: string[], status: GitStatusEntry[]): { selected: string[]; unmatched: string[] } {
	const selected = new Set<string>();
	const changed = status.map(entry => entry.path);
	for (const file of requested) {
		const prefix = file.endsWith("/") ? file : `${file}/`;
		for (const changedFile of changed) {
			if (changedFile === file || changedFile.startsWith(prefix)) selected.add(changedFile);
		}
	}
	const unmatched = requested.filter(file => {
		const prefix = file.endsWith("/") ? file : `${file}/`;
		return !changed.some(changedFile => changedFile === file || changedFile.startsWith(prefix));
	});
	return { selected: [...selected], unmatched };
}

async function loadCommitSkillText(): Promise<string> {
	const candidates = [
		process.env.OMP_AGENT_DIR ? `${process.env.OMP_AGENT_DIR}/skills/commit/SKILL.md` : undefined,
		process.env.OMP_CONFIG_ROOT ? `${process.env.OMP_CONFIG_ROOT}/agent/skills/commit/SKILL.md` : undefined,
		process.env.HOME ? `${process.env.HOME}/.omp/agent/skills/commit/SKILL.md` : undefined,
		new URL("../skills/commit/SKILL.md", import.meta.url).pathname,
	];
	for (const candidate of candidates) {
		if (!candidate) continue;
		try {
			const file = Bun.file(candidate);
			if (await file.exists()) return await file.text();
		} catch {
			// Try the next candidate. OMP may load legacy extension files from a temp directory.
		}
	}
	return [
		"Follow the repo-managed commit workflow:",
		"- Inspect git status and diffs before staging.",
		"- Stage only files explicitly selected for this commit.",
		"- Check selected changes for secrets.",
		"- Run narrow meaningful verification before committing.",
		"- Use a concise conventional commit message.",
		"- Preserve unrelated user changes.",
	].join("\n");
}

async function buildToolInvocationPrompt(parsed: ParsedArgs): Promise<string> {
	const skillText = await loadCommitSkillText();
	const flags = {
		dryRun: parsed.dryRun,
		push: parsed.push,
		acceptRisk: parsed.acceptRisk,
		context: parsed.context || undefined,
	};
	return [
		"The user invoked /commit. Use the existing conversation context to plan the commit; do not start a new session or a nested omp process.",
		"Call the omp_commit tool exactly once. Do not call git, bash, read, search, or any other tool; omp_commit owns hidden git operations and live UI.",
		"Commit skill guidance:",
		skillText.trim(),
		"Tool argument contract:",
		JSON.stringify(
			{
				files: ["repo-relative file or directory to include"],
				commitMessage: "type(scope): concise subject",
				rationale: "why this file set and message match the current conversation",
				verification: [{ command: "executable", args: ["arg"], description: "short label", required: true }],
				dryRun: parsed.dryRun || undefined,
				push: parsed.push || undefined,
				acceptRisk: parsed.acceptRisk || undefined,
				context: parsed.context || undefined,
			},
			null,
			2,
		),
		"Rules:",
		"- files MUST be only the files intentionally belonging to this commit, inferred from the current conversation context.",
		"- If the current context is insufficient to select files confidently, pass files: [] and explain the uncertainty in rationale; omp_commit will block safely with the actual changed files.",
		"- Provide narrow verification commands that should run before staging. If none are meaningful, only set acceptRisk when the user passed --accept-risk.",
		"- Preserve unrelated user changes. Do not include files just because they are modified.",
		"- After omp_commit returns, summarize only the outcome, blocker, verification evidence, and residual risk.",
		parsed.model ? `Note: --model ${parsed.model} was provided but /commit now runs in the current session model; do not pass model to the tool.` : "",
		`Slash-command flags: ${JSON.stringify(flags)}`,
	].filter(Boolean).join("\n\n");
}

function parseCommitArgs(input: string): ParsedArgs {
	const tokens = tokenize(input);
	const context: string[] = [];
	let dryRun = false;
	let push = false;
	let acceptRisk = false;
	let model: string | undefined;
	let passthrough = false;
	for (let i = 0; i < tokens.length; i += 1) {
		const token = tokens[i];
		if (passthrough) {
			context.push(token);
			continue;
		}
		if (token === "--") {
			passthrough = true;
		} else if (token === "--dry-run" || token === "-n") {
			dryRun = true;
		} else if (token === "--push") {
			push = true;
		} else if (token === "--accept-risk") {
			acceptRisk = true;
		} else if ((token === "--model" || token === "-m") && tokens[i + 1]) {
			model = tokens[++i];
		} else if (token === "--no-changelog") {
			context.push("Do not update changelog files.");
		} else {
			context.push(token);
		}
	}
	return { dryRun, push, acceptRisk, context: context.join(" ").trim(), model };
}

function tokenize(input: string): string[] {
	const tokens: string[] = [];
	let current = "";
	let quote: '"' | "'" | undefined;
	for (let i = 0; i < input.length; i += 1) {
		const char = input[i];
		if (quote) {
			if (char === quote) quote = undefined;
			else current += char;
			continue;
		}
		if (char === '"' || char === "'") {
			quote = char;
			continue;
		}
		if (/\s/.test(char)) {
			if (current) {
				tokens.push(current);
				current = "";
			}
			continue;
		}
		current += char;
	}
	if (current) tokens.push(current);
	return tokens;
}

function buildToolResultText(details: CommitRunDetails): string {
	if (details.status === "failed") return details.errorText || details.phase;
	if (details.finalText) return details.finalText;
	return details.phase;
}

function buildDryRunText(details: CommitRunDetails): string {
	return [
		"Commit preview complete.",
		`Message: ${details.commitMessage}`,
		`Files: ${details.selectedFiles.join(", ")}`,
		details.verificationCount > 0 ? `Verification commands: ${details.verificationCount}` : "Verification: accepted risk; no command run",
		details.ignoredFiles.length > 0 ? `Ignored modified files: ${details.ignoredFiles.join(", ")}` : "No ignored modified files.",
	].join("\n");
}

function buildSuccessText(details: CommitRunDetails): string {
	return [
		`Commit created${details.commitHash ? `: ${details.commitHash}` : ""}.`,
		`Message: ${details.commitMessage}`,
		`Files: ${details.selectedFiles.join(", ")}`,
		details.verificationCount > 0 ? `Verification commands passed: ${details.verificationCount}` : "Verification: accepted risk; no command run",
		details.ignoredFiles.length > 0 ? `Ignored modified files left untouched: ${details.ignoredFiles.join(", ")}` : "No ignored modified files.",
		details.push ? "Pushed to remote." : "Not pushed.",
	].join("\n");
}

function renderCommitRun(details: CommitRunDetails, expanded: boolean, theme: any, spinnerFrame?: number): string[] {
	const lines: string[] = [];
	const running = details.status === "running";
	const statusColor = details.status === "failed" ? "error" : details.status === "succeeded" ? "success" : "accent";
	const icon = running ? spinner(spinnerFrame) : details.status === "failed" ? "✖" : "✔";
	const title = details.dryRun ? "Commit preview" : "Commit";
	const badges = [details.push ? "push" : undefined, details.acceptRisk ? "risk accepted" : undefined].filter(Boolean);
	const suffix = badges.length > 0 ? ` ${theme.fg("dim", badges.map(badge => `[${badge}]`).join(" "))}` : "";
	lines.push(`${theme.fg(statusColor, icon)} ${theme.fg("accent", theme.bold(title))}${suffix}`);
	lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Status")}: ${theme.fg(statusColor, details.phase)}`);
	lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Internal actions")}: ${theme.fg("muted", `${details.toolCount}`)}${details.failedToolCount > 0 ? theme.fg("error", ` (${details.failedToolCount} failed)`) : ""}`);
	if (details.commitMessage) lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Message")}: ${theme.fg("muted", details.commitMessage.split("\n", 1)[0])}`);
	if (details.rationale) lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Rationale")}: ${theme.fg("muted", details.rationale)}`);
	if (details.selectedFiles.length > 0) lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Files")}: ${theme.fg("muted", details.selectedFiles.join(", "))}`);
	if (details.ignoredFiles.length > 0) lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Ignored")}: ${theme.fg("muted", details.ignoredFiles.join(", "))}`);

	const visibleSteps = expanded ? details.steps : details.steps.slice(-MAX_VISIBLE_STEPS);
	if (details.steps.length > visibleSteps.length) {
		lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", `… ${details.steps.length - visibleSteps.length} earlier steps`)}`);
	}
	for (const [index, step] of visibleSteps.entries()) {
		const isLast = index === visibleSteps.length - 1 && !details.finalText && !details.errorText;
		const prefix = isLast ? theme.tree.last : theme.tree.branch;
		const stepIcon = step.status === "failed" ? "✖" : step.status === "done" ? "✔" : spinner(spinnerFrame);
		const color = step.status === "failed" ? "error" : step.status === "done" ? "success" : "accent";
		lines.push(` ${theme.fg("dim", prefix)} ${theme.fg(color, stepIcon)} ${theme.fg("muted", step.label)}`);
	}

	if (details.errorText) {
		lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("error", "Blocked")}`);
		for (const line of details.errorText.split("\n").slice(0, MAX_FINAL_LINES)) {
			lines.push(` ${theme.fg("dim", theme.tree.vertical)}  ${theme.fg("error", line)}`);
		}
	}

	if (details.finalText) {
		const finalLines = details.finalText.split("\n").filter(Boolean);
		const shown = expanded ? finalLines : finalLines.slice(0, MAX_FINAL_LINES);
		lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Result")}`);
		for (const line of shown) lines.push(` ${theme.fg("dim", theme.tree.vertical)}  ${theme.fg("muted", line)}`);
		if (shown.length < finalLines.length) lines.push(` ${theme.fg("dim", theme.tree.vertical)}  ${theme.fg("dim", "…")}`);
	}

	if (details.finishedAt) {
		lines.push(` ${theme.fg("dim", theme.tree.last)} ${theme.fg("dim", `Completed in ${formatDuration(details.finishedAt - details.startedAt)}`)}`);
	}
	return lines;
}

function spinner(frame: number | undefined): string {
	return SPINNER_FRAMES[(frame ?? Math.floor(Date.now() / 120)) % SPINNER_FRAMES.length];
}

function upsertStep(details: CommitRunDetails, label: string, status: StepStatus): void {
	const last = details.steps[details.steps.length - 1];
	if (last?.label === label && last.status === "running") {
		last.status = status;
		if (status !== "running") last.finishedAt = Date.now();
		return;
	}
	if (last?.status === "running") {
		last.status = "done";
		last.finishedAt = Date.now();
	}
	details.steps.push({ label, status, startedAt: Date.now(), finishedAt: status === "running" ? undefined : Date.now() });
}

function finishRunningSteps(details: CommitRunDetails, status: StepStatus): void {
	for (const step of details.steps) {
		if (step.status === "running") {
			step.status = status;
			step.finishedAt = Date.now();
		}
	}
}

function isCommitRunDetails(value: unknown): value is CommitRunDetails {
	return Boolean(
		value &&
			typeof value === "object" &&
			"id" in value &&
			"status" in value &&
			"steps" in value &&
			Array.isArray((value as { steps?: unknown }).steps),
	);
}

function formatError(error: unknown): string {
	if (error instanceof CommandError) return error.message;
	if (error instanceof Error) return error.message;
	return String(error);
}

function throwIfAborted(signal: AbortSignal | undefined): void {
	if (signal?.aborted) throw new WorkflowError("Commit workflow cancelled.");
}

function trimOutput(text: string): string {
	const trimmed = text.trim();
	return trimmed.length > MAX_OUTPUT_CHARS ? `${trimmed.slice(0, MAX_OUTPUT_CHARS)}…` : trimmed;
}

function dedupe(values: string[]): string[] {
	return [...new Set(values)];
}

function truncateVisible(input: string, width: number): string {
	let visible = 0;
	let result = "";
	for (let i = 0; i < input.length; i += 1) {
		const char = input[i];
		if (char === "\u001b") {
			const end = input.indexOf("m", i);
			if (end !== -1) {
				result += input.slice(i, end + 1);
				i = end;
				continue;
			}
		}
		visible += 1;
		if (visible > width - 1) return `${result}…`;
		result += char;
	}
	return result;
}

function formatDuration(ms: number): string {
	const seconds = Math.max(0, Math.round(ms / 1000));
	if (seconds < 60) return `${seconds}s`;
	const minutes = Math.floor(seconds / 60);
	const remainder = seconds % 60;
	return `${minutes}m ${remainder}s`;
}
