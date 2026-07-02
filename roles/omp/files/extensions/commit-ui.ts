import type { Component } from "@oh-my-pi/pi-tui";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const TOOL_NAME = "omp_commit";
const MIN_RENDER_WIDTH = 20;
const MIN_WRAP_CONTENT_WIDTH = 12;
const MAX_CARD_FIELD_LINES = 3;
const MAX_EXPANDED_CARD_FIELD_LINES = 8;
const MAX_RESULT_WARNINGS = 4;
const MAX_RESULT_FILES = 8;
const MAX_OUTPUT_CHARS = 1_600;
const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const PULSE_COLORS = ["accent", "success", "warning", "accent", "muted", "accent"] as const;
const PULSE_BAR_WIDTH = 22;
const COMMIT_HEARTBEAT_MS = 120;
const COMMIT_WORKING_MESSAGE = "Planning commit…";

type RunStatus = "pending" | "running" | "succeeded" | "failed";
type StepStatus = "pending" | "running" | "done" | "failed";
type CommitStatus = "pending" | "running" | "succeeded" | "failed";
type StepKey = "plan" | "tree" | "stage" | "commit" | "push";

interface CommitToolCommitParams {
	files?: unknown;
	commitMessage?: unknown;
	message?: unknown;
	rationale?: unknown;
	verification?: unknown;
	verificationEvidence?: unknown;
	acceptRisk?: unknown;
}

interface CommitToolParams extends CommitToolCommitParams {
	commits?: unknown;
	context?: unknown;
	dryRun?: unknown;
	push?: unknown;
	multiCommit?: unknown;
}

interface CommitSpec {
	files: string[];
	deriveFilesFromStatus: boolean;
	commitMessage: string;
	rationale: string;
}

interface CommitPlan {
	commits: CommitSpec[];
	context: string;
	dryRun: boolean;
	push: boolean;
	multiCommit: boolean;
}

interface ParsedArgs {
	dryRun: boolean;
	push: boolean;
	multiCommit: boolean;
	context: string;
	ignoredModel?: string;
}

interface GitStatusEntry {
	code: string;
	path: string;
	oldPath?: string;
}

interface CommandResult {
	stdout: string;
	stderr: string;
	exitCode: number;
}

interface CommitStep {
	key: StepKey;
	label: string;
	status: StepStatus;
}

interface CommitResultDetails {
	commitMessage?: string;
	rationale?: string;
	requestedFiles: string[];
	selectedFiles: string[];
	commitFiles: string[];
	status: CommitStatus;
	phase: string;
	commitHash?: string;
	errorText?: string;
}

interface CommitRunDetails {
	kind: "omp_commit";
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
	pushSucceeded?: boolean;
	multiCommit: boolean;
	context?: string;
	rationale?: string;
	commitMessage?: string;
	selectedFiles: string[];
	ignoredFiles: string[];
	commitHash?: string;
	commits: CommitResultDetails[];
	warnings: string[];
	errorText?: string;
	finalText?: string;
}

interface ToolUpdate {
	content: { type: "text"; text: string }[];
	details: CommitRunDetails;
}

interface DashboardCommit {
	subject: string;
	files: string[];
	requestedFiles: string[];
	rationale?: string;
	status: CommitStatus;
	phase: string;
	hash?: string;
	errorText?: string;
}

interface DashboardModel {
	title: string;
	status: RunStatus;
	phase: string;
	dryRun: boolean;
	push: boolean;
	multiCommit: boolean;
	startedAt?: number;
	finishedAt?: number;
	commits: DashboardCommit[];
	chips: string[];
	rail: CommitStep[];
	warnings: string[];
	ignoredFiles: string[];
	outcome: string[];
	context?: string;
}

interface CommitCommandUi {
	notify(message: string, level: string): void;
	setWorkingMessage?(message: string | undefined): void | Promise<void>;
}

interface CommitCommandContext {
	ui: CommitCommandUi;
	isIdle(): boolean;
	waitForIdle(): Promise<void>;
}

class WorkflowError extends Error {}

class CommandError extends WorkflowError {
	constructor(message: string, readonly result: CommandResult) {
		super(message);
	}
}

async function setCommandWorkingMessage(ui: CommitCommandUi | undefined, message: string | undefined): Promise<void> {
	const setWorkingMessage = ui?.setWorkingMessage;
	if (typeof setWorkingMessage !== "function") return;
	await setWorkingMessage.call(ui, message);
}

export default function commitUi(pi: ExtensionAPI): void {
	const z = pi.zod;
	let restoreActiveTools: string[] | undefined;
	let activeCommandUi: CommitCommandUi | undefined;
	pi.setLabel?.("commit UI");

	const commitParam = z.object({
		files: z.array(z.string()).optional().describe("Repo-relative files or directories for this commit. Split commits must name the changed files they own."),
		commitMessage: z.string().optional().describe("Exact non-empty commit message. Multi-paragraph messages are preserved."),
		message: z.string().optional().describe("Compatibility alias for commitMessage."),
		rationale: z.string().optional().describe("Short reason for grouping these files."),
		verification: z.unknown().optional().describe("Legacy metadata accepted for compatibility and ignored."),
		verificationEvidence: z.unknown().optional().describe("Legacy metadata accepted for compatibility and ignored."),
		acceptRisk: z.boolean().optional().describe("Legacy compatibility flag accepted and ignored."),
	});

	pi.registerTool({
		name: TOOL_NAME,
		label: "Commit",
		description: "Create one or more git commits from an explicit in-session plan.",
		defaultInactive: true,
		parameters: z.object({
			files: z.array(z.string()).optional().describe("Repo-relative files or directories. Omit or pass [] for a single status-derived commit."),
			commitMessage: z.string().optional().describe("Exact non-empty commit message. Multi-paragraph messages are preserved."),
			message: z.string().optional().describe("Compatibility alias for commitMessage."),
			rationale: z.string().optional().describe("Short reason for this commit."),
			commits: z.array(commitParam).optional().describe("Split commit plans. Each entry must name its files."),
			context: z.string().optional().describe("Additional /commit context."),
			dryRun: z.boolean().optional().describe("Preview selected files and messages without staging, committing, or pushing."),
			push: z.boolean().optional().describe("Run git push once after all local commits succeed."),
			multiCommit: z.boolean().optional().describe("Compatibility hint for split commit rendering."),
			verification: z.unknown().optional().describe("Legacy metadata accepted for compatibility and ignored."),
			verificationEvidence: z.unknown().optional().describe("Legacy metadata accepted for compatibility and ignored."),
			acceptRisk: z.boolean().optional().describe("Legacy compatibility flag accepted and ignored."),
		}),
		async execute(_toolCallId: string, params: unknown, signal: AbortSignal | undefined, onUpdate: ((update: ToolUpdate) => void) | undefined, ctx: { cwd: string }) {
			const plan = normalizeCommitPlan(params);
			const details = createRunDetails(plan);
			const emit = () => {
				if (!onUpdate) return;
				const snapshot = cloneCommitRunDetails(details);
				onUpdate({ content: [{ type: "text", text: snapshot.phase }], details: snapshot });
			};
			let heartbeat: Timer | undefined;
			emit();
			if (onUpdate) {
				heartbeat = setInterval(() => {
					try {
						emit();
					} catch {
						// Heartbeat repainting must never alter commit behavior.
					}
				}, COMMIT_HEARTBEAT_MS);
			}

			try {
				await executeCommitPlan(plan, ctx.cwd, details, emit, signal);
			} catch (error) {
				details.status = "failed";
				details.errorText = formatError(error);
				details.phase = "Commit blocked";
				details.finishedAt = Date.now();
				markRunningSteps(details, "failed");
				details.finalText = buildToolResultText(details);
				emit();
			} finally {
				clearInterval(heartbeat);
				await resetActiveCommandWorkingMessage();
			}

			return {
				content: [{ type: "text", text: buildToolResultText(details) }],
				details,
				isError: details.status === "failed",
			};
		},
		renderCall(args: unknown, _options: unknown, theme: unknown) {
			return new CommitCallComponent(normalizeCommitPlan(args), theme);
		},
		renderResult(result: unknown, options: unknown, theme: unknown) {
			const details = readDetails(result);
			if (!isCommitRunDetails(details)) {
				return new StaticLinesComponent([paint(theme, "muted", firstResultText(result) ?? "Commit workflow")]);
			}
			return new CommitRunComponent(details, Boolean(readRecordFlag(options, "expanded")), theme, getSpinnerFrame(options));
		},
	});

	const resetActiveCommandWorkingMessage = async () => {
		const ui = activeCommandUi;
		activeCommandUi = undefined;
		await setCommandWorkingMessage(ui, undefined);
	};

	const startCommitWorkflow = async (parsed: ParsedArgs) => {
		restoreActiveTools = pi.getActiveTools();
		await pi.setActiveTools([TOOL_NAME]);
		pi.sendMessage(
			{
				customType: "commit-request",
				content: buildToolInvocationPrompt(parsed),
				display: false,
				details: parsed,
				attribution: "user",
			},
			{ triggerTurn: true, deliverAs: "nextTurn" },
		);
	};

	pi.registerCommand("commit", {
		description: "Plan from current context, then commit behind one live progress card",
		handler: async (args: string, ctx: CommitCommandContext) => {
			if (restoreActiveTools) {
				ctx.ui.notify("A commit workflow is already running.", "warning");
				return;
			}

			const parsed = parseCommitArgs(args);
			activeCommandUi = ctx.ui;
			ctx.ui.notify(COMMIT_WORKING_MESSAGE, "info");
			await setCommandWorkingMessage(ctx.ui, COMMIT_WORKING_MESSAGE);
			try {
				if (!ctx.isIdle()) {
					ctx.ui.notify("Commit queued until the current turn finishes.", "info");
					await ctx.waitForIdle();
				}

				await startCommitWorkflow(parsed);
			} catch (error) {
				await resetActiveCommandWorkingMessage();
				throw error;
			}
		},
	});

	const restoreTools = async () => {
		await resetActiveCommandWorkingMessage();
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
		private readonly theme: unknown,
	) {}

	invalidate(): void {}

	render(width: number): string[] {
		return renderCommitCallTeaser(this.plan, this.theme, width);
	}
}

class CommitRunComponent implements Component {
	constructor(
		private readonly details: CommitRunDetails,
		private readonly expanded: boolean,
		private readonly theme: unknown,
		private readonly spinnerFrame?: number,
	) {}

	invalidate(): void {}

	render(width: number): string[] {
		return renderDashboard(dashboardFromDetails(this.details), this.expanded, this.theme, this.spinnerFrame, width);
	}
}

class StaticLinesComponent implements Component {
	constructor(private readonly lines: string[]) {}

	invalidate(): void {}

	render(width: number): string[] {
		return this.lines.map(line => truncateVisible(line, Math.max(MIN_RENDER_WIDTH, width)));
	}
}

function renderCommitCallTeaser(plan: CommitPlan, theme: unknown, width: number): string[] {
	const renderWidth = Math.max(MIN_RENDER_WIDTH, width);
	const fileCount = new Set(plan.commits.flatMap(commit => commit.files)).size;
	const metadata = fileCount > 0 ? ` · ${formatFileCount(fileCount)}` : "";
	return [
		truncateVisible(`${paint(theme, "accent", "/commit queued")}${paint(theme, "muted", metadata)}`, renderWidth),
	];
}



async function executeCommitPlan(
	plan: CommitPlan,
	cwd: string,
	details: CommitRunDetails,
	onUpdate: () => void,
	signal: AbortSignal | undefined,
): Promise<void> {
	throwIfAborted(signal);
	await runStep(details, "plan", "Plan", onUpdate, () => validateCommitPlan(plan));
	syncDetailsFromPlan(plan, details);

	const status = await runStep(details, "tree", "Tree", onUpdate, async () => {
		details.phase = "Inspecting working tree";
		onUpdate();
		const rawStatus = (await runGit(cwd, ["status", "--porcelain=v1", "-z", "--untracked-files=all"], signal, details)).stdout;
		const entries = parseStatusZ(rawStatus);
		if (entries.length === 0) throw new WorkflowError("No working tree changes to commit.");
		resolveSelections(plan, details, entries);
		await guardUnrelatedStagedChanges(cwd, details, signal);
		return entries;
	});

	if (plan.dryRun) {
		details.status = "succeeded";
		details.phase = "Commit preview ready";
		details.finalText = buildDryRunText(details);
		details.finishedAt = Date.now();
		onUpdate();
		return;
	}

	for (const [index, commit] of plan.commits.entries()) {
		const result = details.commits[index];
		if (!result) continue;
		const label = formatCommitLabel(index, plan.commits.length);
		try {
			setCommitState(result, "running", "Staging selected files");
			details.phase = `${label}: staging selected files`;
			onUpdate();
			await runStep(details, "stage", "Stage", onUpdate, () => runGit(cwd, ["add", "-A", "--", ...result.selectedFiles], signal, details));

			setCommitState(result, "running", "Creating commit");
			details.phase = `${label}: creating commit`;
			onUpdate();
			await runStep(details, "commit", "Commit", onUpdate, () => commitSelectedFiles(cwd, commit.commitMessage, result.commitFiles, signal, details));

			setCommitState(result, "running", "Reading commit hash");
			details.phase = `${label}: reading commit hash`;
			onUpdate();
			const hash = (await runGit(cwd, ["rev-parse", "--short", "HEAD"], signal, details)).stdout.trim();
			result.commitHash = hash;
			details.commitHash = hash;
			setCommitState(result, "succeeded", "Created");
			onUpdate();
		} catch (error) {
			setCommitState(result, "failed", result.phase || `${label} failed`, formatError(error));
			details.phase = `${label} blocked`;
			onUpdate();
			throw error;
		}
	}

	if (plan.push) {
		details.phase = "Pushing branch";
		onUpdate();
		try {
			await runStep(details, "push", "Push", onUpdate, () => runGit(cwd, ["push"], signal, details));
			details.pushSucceeded = true;
		} catch (error) {
			if (signal?.aborted) throw error;
			details.pushSucceeded = false;
			addWarning(details, `Push failed after local commits were created. ${formatError(error)}`);
			details.phase = `${formatCommitGroup(plan.commits.length)} created locally; push failed`;
			onUpdate();
		}
	}

	const commitNoun = formatCommitGroup(plan.commits.length);
	details.status = "succeeded";
	details.phase = plan.push
		? details.pushSucceeded
			? `${commitNoun} created and pushed`
			: `${commitNoun} created locally; push failed`
		: `${commitNoun} created`;
	details.finalText = buildSuccessText(details);
	details.finishedAt = Date.now();
	void status;
	onUpdate();
}

async function runStep<T>(
	details: CommitRunDetails,
	key: StepKey,
	label: string,
	onUpdate: () => void,
	fn: () => Promise<T> | T,
): Promise<T> {
	setStep(details, key, label, "running");
	onUpdate();
	try {
		const value = await fn();
		setStep(details, key, label, "done");
		onUpdate();
		return value;
	} catch (error) {
		setStep(details, key, label, "failed");
		onUpdate();
		throw error;
	}
}

function setStep(details: CommitRunDetails, key: StepKey, label: string, status: StepStatus): void {
	const existing = details.steps.find(step => step.key === key);
	if (existing) {
		existing.label = label;
		existing.status = status;
		return;
	}
	details.steps.push({ key, label, status });
}

function markRunningSteps(details: CommitRunDetails, status: StepStatus): void {
	for (const step of details.steps) {
		if (step.status === "running") step.status = status;
	}
}

function setCommitState(commit: CommitResultDetails, status: CommitStatus, phase: string, errorText?: string): void {
	commit.status = status;
	commit.phase = phase;
	if (errorText) commit.errorText = errorText;
}

function normalizeCommitPlan(params: unknown): CommitPlan {
	const root = isRecord(params) ? params : {};
	const explicitCommits = Array.isArray(root.commits) ? root.commits : undefined;
	const sourceCommits = explicitCommits ?? [root];
	const commits = sourceCommits.map(normalizeCommitSpec);
	const context = stringValue(root.context)?.trim() ?? "";
	return {
		commits,
		context,
		dryRun: Boolean(root.dryRun),
		push: Boolean(root.push),
		multiCommit: Boolean(root.multiCommit) || commits.length > 1,
	};
}

function normalizeCommitSpec(value: unknown): CommitSpec {
	const record = isRecord(value) ? value : {};
	const files = dedupe(stringArrayValue(record.files).map(file => file.trim()).filter(Boolean));
	const commitMessage = stringValue(record.commitMessage) ?? stringValue(record.message) ?? "";
	return {
		files,
		deriveFilesFromStatus: files.length === 0,
		commitMessage,
		rationale: stringValue(record.rationale)?.trim() ?? "",
	};
}

function createRunDetails(plan: CommitPlan): CommitRunDetails {
	const commits = plan.commits.map(commit => ({
		commitMessage: commit.commitMessage || undefined,
		rationale: commit.rationale || undefined,
		requestedFiles: [...commit.files],
		selectedFiles: [],
		commitFiles: [],
		status: "pending" as CommitStatus,
		phase: "Waiting",
	}));
	return {
		kind: "omp_commit",
		id: `commit-${Date.now().toString(36)}`,
		status: "running",
		phase: "Starting commit workflow",
		startedAt: Date.now(),
		steps: [],
		toolCount: 0,
		failedToolCount: 0,
		dryRun: plan.dryRun,
		push: plan.push,
		pushSucceeded: undefined,
		multiCommit: plan.multiCommit,
		context: plan.context || undefined,
		rationale: plan.commits.length === 1 ? plan.commits[0]?.rationale || undefined : undefined,
		commitMessage: plan.commits.length === 1 ? plan.commits[0]?.commitMessage || undefined : undefined,
		selectedFiles: [],
		ignoredFiles: [],
		commitHash: undefined,
		commits,
		warnings: [],
	};
}

function cloneCommitRunDetails(details: CommitRunDetails): CommitRunDetails {
	return {
		...details,
		steps: details.steps.map(step => ({ ...step })),
		selectedFiles: [...details.selectedFiles],
		ignoredFiles: [...details.ignoredFiles],
		commits: details.commits.map(commit => ({
			...commit,
			requestedFiles: [...commit.requestedFiles],
			selectedFiles: [...commit.selectedFiles],
			commitFiles: [...commit.commitFiles],
		})),
		warnings: [...details.warnings],
	};
}

function validateCommitPlan(plan: CommitPlan): void {
	if (plan.commits.length === 0) throw new WorkflowError("At least one commit plan is required.");
	if (plan.context.includes("\0")) throw new WorkflowError("Commit context contains a NUL byte.");
	for (const [index, commit] of plan.commits.entries()) {
		const label = formatCommitLabel(index, plan.commits.length);
		validateCommitSpec(commit, label);
	}
}

function validateCommitSpec(commit: CommitSpec, label: string): void {
	const prefix = label === "Commit" ? "" : `${label}: `;
	if (!commit.commitMessage.trim()) throw new WorkflowError(`${prefix}commit message is required.`);
	if (commit.commitMessage.includes("\0")) throw new WorkflowError(`${prefix}commit message contains a NUL byte.`);
	if (commit.rationale.includes("\0")) throw new WorkflowError(`${prefix}rationale contains a NUL byte.`);
	commit.files = dedupe(commit.files.map(file => validateRepoPath(file, prefix)));
	commit.deriveFilesFromStatus = commit.files.length === 0;
}

function validateRepoPath(input: string, prefix: string): string {
	if (input.includes("\0")) throw new WorkflowError(`${prefix}file path contains a NUL byte.`);
	const normalizedSeparators = input.trim().replace(/\\/g, "/");
	if (!normalizedSeparators) throw new WorkflowError(`${prefix}file path is empty.`);
	if (normalizedSeparators.startsWith("/") || /^[A-Za-z]:/.test(normalizedSeparators)) {
		throw new WorkflowError(`${prefix}file path must be repo-relative: ${redactSuspiciousTokens(normalizedSeparators)}`);
	}
	const parts = normalizedSeparators.split("/");
	if (parts.includes("..")) {
		throw new WorkflowError(`${prefix}file path must not contain '..': ${redactSuspiciousTokens(normalizedSeparators)}`);
	}
	const cleaned = parts.filter(part => part && part !== ".").join("/");
	return cleaned || ".";
}

function syncDetailsFromPlan(plan: CommitPlan, details: CommitRunDetails): void {
	details.context = plan.context || undefined;
	details.rationale = plan.commits.length === 1 ? plan.commits[0]?.rationale || undefined : undefined;
	details.commitMessage = plan.commits.length === 1 ? plan.commits[0]?.commitMessage || undefined : undefined;
	for (const [index, commit] of plan.commits.entries()) {
		const result = details.commits[index];
		if (!result) continue;
		result.commitMessage = commit.commitMessage || undefined;
		result.rationale = commit.rationale || undefined;
		result.requestedFiles = [...commit.files];
	}
}

function resolveSelections(plan: CommitPlan, details: CommitRunDetails, status: GitStatusEntry[]): void {
	const statusPaths = status.map(entry => entry.path);
	const selectedByFile = new Map<string, number>();
	const statusByPath = new Map(status.map(entry => [entry.path, entry]));
	const ignoredRequestedPaths: string[] = [];
	for (const [index, commit] of plan.commits.entries()) {
		const label = formatCommitLabel(index, plan.commits.length);
		let selected: string[];
		if (commit.files.length === 0) {
			if (!commit.deriveFilesFromStatus || plan.commits.length > 1) {
				throw new WorkflowError(`${label}: no files were selected; split commits must name changed files explicitly.`);
			}
			selected = [...statusPaths];
			addWarning(details, `${label}: no files supplied; selected all current git status paths.`);
		} else {
			const resolved = resolveSelectedFiles(commit.files, statusPaths);
			selected = resolved.selected;
			if (selected.length === 0) {
				throw new WorkflowError(`${label}: requested files are not changed: ${resolved.unmatched.join(", ")}`);
			}
			if (resolved.unmatched.length > 0) {
				ignoredRequestedPaths.push(...resolved.unmatched);
				addWarning(details, `${label}: ignored requested paths that are not changed: ${resolved.unmatched.join(", ")}.`);
			}
		}

		const commitFiles = dedupe([
			...selected,
			...selected.flatMap(file => {
				const entry = statusByPath.get(file);
				return entry?.oldPath ? [entry.oldPath] : [];
			}),
		]);
		const result = details.commits[index];
		if (result) {
			result.selectedFiles = selected;
			result.commitFiles = commitFiles;
		}
		for (const file of selected) {
			const previousIndex = selectedByFile.get(file);
			if (previousIndex !== undefined) {
				throw new WorkflowError(`${file} is selected by multiple commits: ${formatCommitLabel(previousIndex, plan.commits.length)} and ${label}.`);
			}
			selectedByFile.set(file, index);
		}
	}

	details.selectedFiles = details.commits.flatMap(commit => commit.selectedFiles);
	details.ignoredFiles = dedupe([...statusPaths.filter(path => !selectedByFile.has(path)), ...ignoredRequestedPaths]);
}

function resolveSelectedFiles(requested: string[], statusPaths: string[]): { selected: string[]; unmatched: string[] } {
	const selected = new Set<string>();
	const unmatched: string[] = [];
	for (const file of requested) {
		const matchesAll = file === ".";
		const prefix = file.endsWith("/") ? file : `${file}/`;
		let matched = false;
		for (const changedFile of statusPaths) {
			if (matchesAll || changedFile === file || changedFile.startsWith(prefix)) {
				selected.add(changedFile);
				matched = true;
			}
		}
		if (!matched) unmatched.push(file);
	}
	return { selected: statusPaths.filter(path => selected.has(path)), unmatched };
}

async function guardUnrelatedStagedChanges(cwd: string, details: CommitRunDetails, signal: AbortSignal | undefined): Promise<void> {
	const staged = parseZPaths((await runGit(cwd, ["diff", "--cached", "--name-only", "-z"], signal, details)).stdout);
	const selected = new Set(details.commits.flatMap(commit => commit.commitFiles.length > 0 ? commit.commitFiles : commit.selectedFiles));
	const unrelated = staged.filter(path => !selected.has(path));
	if (unrelated.length > 0) {
		throw new WorkflowError(`Unrelated staged changes would be at risk: ${unrelated.join(", ")}. Unstage or include them explicitly.`);
	}
}

async function commitSelectedFiles(
	cwd: string,
	message: string,
	selectedFiles: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<void> {
	await withMessageFile(message, messageFile => runGit(cwd, ["commit", "--only", "--cleanup=verbatim", "-F", messageFile, "--", ...selectedFiles], signal, details));
}

async function withMessageFile<T>(message: string, fn: (messageFile: string) => Promise<T>): Promise<T> {
	const tmpBase = (Bun.env.TMPDIR || "/tmp/").replace(/\/?$/, "/");
	const file = `${tmpBase}omp-commit-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}.txt`;
	try {
		await Bun.write(file, message);
		return await fn(file);
	} finally {
		try {
			await Bun.file(file).delete();
		} catch {
			// Best-effort cleanup; the file lives in the OS temp directory.
		}
	}
}

async function runGit(cwd: string, args: string[], signal: AbortSignal | undefined, details: CommitRunDetails): Promise<CommandResult> {
	const result = await runCommand(cwd, "git", args, signal, details);
	if (result.exitCode !== 0) {
		details.failedToolCount += 1;
		throw new CommandError(`git ${args[0] ?? ""} failed: ${trimOutput(result.stderr || result.stdout)}`, result);
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
		throwIfAborted(signal);
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
		const oldPath = code.includes("R") && index + 1 < parts.length ? parts[index + 1] : undefined;
		entries.push({ code, path, oldPath });
		if ((code.includes("R") || code.includes("C")) && index + 1 < parts.length) index += 1;
	}
	return entries;
}

function parseZPaths(raw: string): string[] {
	return raw.split("\0").filter(Boolean);
}

function buildToolInvocationPrompt(parsed: ParsedArgs): string {
	const flags = {
		dryRun: parsed.dryRun || undefined,
		push: parsed.push || undefined,
		multiCommit: parsed.multiCommit || undefined,
		context: parsed.context || undefined,
	};
	const singleExample = {
		files: ["repo-relative file or directory, or omit/pass [] to include every changed status path"],
		commitMessage: "Short exact commit message\n\nOptional body paragraph.",
		rationale: "why this commit matches the current conversation",
		dryRun: parsed.dryRun || undefined,
		push: parsed.push || undefined,
		context: parsed.context || undefined,
	};
	const splitExample = {
		commits: [{
			files: ["exact repo-relative file or directory for this split"],
			commitMessage: "Short exact message for this split",
			rationale: "why these files belong together",
		}],
		dryRun: parsed.dryRun || undefined,
		push: parsed.push || undefined,
		multiCommit: true,
		context: parsed.context || undefined,
	};
	return [
		"The user invoked /commit. Use the existing conversation context to plan the commit in this same session.",
		parsed.multiCommit
			? "Call the omp_commit tool exactly once with one commits[] array containing every planned split commit. Do not call any other tools."
			: "Call the omp_commit tool exactly once. Do not call git, bash, read, grep, web, or any other tool.",
		"The tool owns status inspection, path selection checks, staging, committing, optional push, and dry-run preview.",
		"Single-commit shape:",
		JSON.stringify(singleExample, null, 2),
		parsed.multiCommit ? "Split-commit shape:" : "",
		parsed.multiCommit ? JSON.stringify(splitExample, null, 2) : "",
		"Rules:",
		"- For one commit, use top-level files/commitMessage/rationale and omit commits[]. Omit files or pass [] only when all current git status paths should be committed.",
		"- For split mode, pass one non-empty commits[] array. Each entry must name the changed files for that split.",
		"- Commit messages only need to be non-empty; preserve the exact wording and paragraphs that belong in git history.",
		"- Preserve unrelated user changes. Include only files supported by the conversation context.",
		"- After the tool returns, summarize the outcome, any blocker, warnings, ignored files, and push result.",
		parsed.ignoredModel ? `Note: --model ${parsed.ignoredModel} was provided but /commit uses the current session model.` : "",
		`Commit-request flags: ${JSON.stringify(flags)}`,
	].filter(Boolean).join("\n\n");
}

function parseCommitArgs(input: string): ParsedArgs {
	const tokens = tokenize(input);
	const context: string[] = [];
	let dryRun = false;
	let push = false;
	let multiCommit = false;
	let ignoredModel: string | undefined;
	let passthrough = false;
	for (let index = 0; index < tokens.length; index += 1) {
		const token = tokens[index];
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
		} else if (token === "--no-push") {
			push = false;
		} else if (token === "--split" || token === "--multiple" || token === "--multi" || token === "--atomic") {
			multiCommit = true;
		} else if ((token === "--model" || token === "-m") && tokens[index + 1]) {
			ignoredModel = tokens[++index];
		} else if (token === "--no-changelog") {
			context.push("Do not update changelog files.");
		} else {
			context.push(token);
		}
	}
	return { dryRun, push, multiCommit, context: context.join(" ").trim(), ignoredModel };
}

function tokenize(input: string): string[] {
	const tokens: string[] = [];
	let current = "";
	let quote: string | undefined;
	let escaping = false;
	for (const char of input) {
		if (escaping) {
			current += char;
			escaping = false;
			continue;
		}
		if (char === "\\") {
			escaping = true;
			continue;
		}
		if (quote) {
			if (char === quote) quote = undefined;
			else current += char;
			continue;
		}
		if (char === "'" || char === '"') {
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
	if (escaping) current += "\\";
	if (current) tokens.push(current);
	return tokens;
}

function buildToolResultText(details: CommitRunDetails): string {
	if (details.finalText) return redactSuspiciousTokens(details.finalText);
	if (details.status === "failed") {
		const parts = [`Commit blocked: ${details.errorText ?? details.phase}`];
		appendResultWarnings(parts, details);
		return redactSuspiciousTokens(parts.join("\n"));
	}
	return redactSuspiciousTokens(details.phase);
}

function buildDryRunText(details: CommitRunDetails): string {
	const parts = [`Commit preview: ${details.commits.length} ${plural("commit", details.commits.length)}, ${details.selectedFiles.length} ${plural("file", details.selectedFiles.length)}.`];
	parts.push(`Would create: ${formatCommitSummary(details.commits, false)}.`);
	appendIgnoredSummary(parts, details);
	appendResultWarnings(parts, details);
	return parts.join("\n");
}

function buildSuccessText(details: CommitRunDetails): string {
	const parts = [`${formatCommitGroup(details.commits.length)} created: ${formatCommitSummary(details.commits, true)}.`];
	if (details.push) parts.push(details.pushSucceeded ? "Push succeeded." : "Push failed; local commits remain.");
	appendIgnoredSummary(parts, details);
	appendResultWarnings(parts, details);
	return parts.join("\n");
}

function appendIgnoredSummary(parts: string[], details: CommitRunDetails): void {
	if (details.ignoredFiles.length === 0) return;
	parts.push(`Left unchanged: ${formatLimitedList(details.ignoredFiles, MAX_RESULT_FILES)}.`);
}

function appendResultWarnings(parts: string[], details: CommitRunDetails): void {
	if (details.warnings.length === 0) return;
	parts.push(`Warnings: ${formatLimitedList(details.warnings, MAX_RESULT_WARNINGS)}`);
}

function formatCommitSummary(commits: CommitResultDetails[], includeHash: boolean): string {
	return commits.map(commit => {
		const hash = includeHash && commit.commitHash ? `${commit.commitHash} ` : "";
		return `${hash}${commitSubject(commit.commitMessage)}`;
	}).join("; ");
}


function dashboardFromDetails(details: CommitRunDetails): DashboardModel {
	return {
		title: details.dryRun ? "Commit preview" : details.commits.length > 1 ? "Commit group" : "Commit",
		status: details.status,
		phase: details.phase,
		dryRun: details.dryRun,
		push: details.push,
		multiCommit: details.multiCommit,
		startedAt: details.startedAt,
		finishedAt: details.finishedAt,
		commits: details.commits.map(commit => {
			const selectedFiles = Array.isArray(commit.selectedFiles) ? commit.selectedFiles : [];
			const requestedFiles = Array.isArray(commit.requestedFiles) ? commit.requestedFiles : selectedFiles;
			const message = commit.commitMessage ?? (isRecord(commit) ? stringValue(commit.message) : undefined);
			return {
				subject: commitSubject(message),
				files: [...selectedFiles],
				requestedFiles: [...requestedFiles],
				rationale: commit.rationale,
				status: commit.status,
				phase: commit.phase,
				hash: commit.commitHash,
				errorText: commit.errorText,
			};
		}),
		chips: detailsChips(details),
		rail: railFromDetails(details),
		warnings: [...details.warnings],
		ignoredFiles: [...details.ignoredFiles],
		outcome: outcomeLines(details),
		context: details.context,
	};
}

function renderDashboard(model: DashboardModel, expanded: boolean, theme: unknown, spinnerFrame: number | undefined, width: number): string[] {
	const renderWidth = Math.max(MIN_RENDER_WIDTH, width);
	const lines: string[] = [];
	const title = `${paint(theme, statusColor(model.status), statusIcon(model.status, spinnerFrame))} ${dashboardTitleText(theme, model, spinnerFrame)}`;
	lines.push(cardBorder(theme, renderWidth, "╭", "╮", title));
	appendHero(lines, model, theme, spinnerFrame, renderWidth);
	appendPulseBar(lines, model, theme, spinnerFrame, renderWidth);
	appendChips(lines, model.chips, theme, renderWidth);
	appendRail(lines, model.rail, theme, spinnerFrame, renderWidth);
	appendCommitRows(lines, model, expanded, theme, spinnerFrame, renderWidth);
	if (expanded && model.context) appendCardField(lines, theme, renderWidth, "Context", model.context, MAX_EXPANDED_CARD_FIELD_LINES, "muted");
	appendListField(lines, theme, renderWidth, "Warnings", model.warnings, expanded ? 6 : 2, "warning");
	appendListField(lines, theme, renderWidth, "Left out", model.ignoredFiles, expanded ? 4 : 1, "muted");
	appendOutcome(lines, model, theme, renderWidth, expanded);
	const footer = dashboardFooter(model);
	lines.push(cardBorder(theme, renderWidth, "╰", "╯", footer ? paint(theme, "dim", footer) : undefined));
	return lines.map(line => truncateVisible(line, renderWidth));
}

function appendHero(lines: string[], model: DashboardModel, theme: unknown, spinnerFrame: number | undefined, width: number): void {
	const isLive = model.status === "running" || model.status === "pending";
	const pulse = isLive ? `${paint(theme, pulseColor(spinnerFrame), "✦")} ` : "";
	const prefix = `${pulse}${paint(theme, statusColor(model.status), statusIcon(model.status, spinnerFrame))} `;
	appendCardWrappedText(lines, theme, width, prefix, "  ", heroText(model), heroTextColor(model.status), MAX_CARD_FIELD_LINES);
}

function appendChips(lines: string[], chips: string[], theme: unknown, width: number): void {
	if (chips.length === 0) return;
	appendCardWrappedText(lines, theme, width, `${paint(theme, "dim", "Stats")}: `, "  ", chips.join(" · "), "muted", MAX_CARD_FIELD_LINES);
}

function appendRail(lines: string[], rail: CommitStep[], theme: unknown, spinnerFrame: number | undefined, width: number): void {
	if (rail.length === 0) return;
	const row = rail.map(step => `${paint(theme, stepStatusColor(step.status), stepIcon(step.status, spinnerFrame))} ${paint(theme, step.status === "done" ? "success" : step.status === "running" ? "accent" : step.status === "failed" ? "error" : "muted", step.label)}`).join(paint(theme, "dim", "  ─  "));
	appendCardLine(lines, theme, width, row);
}


function appendCommitRows(lines: string[], model: DashboardModel, expanded: boolean, theme: unknown, spinnerFrame: number | undefined, width: number): void {
	const limit = expanded ? model.commits.length : Math.min(model.commits.length, 3);
	for (const [index, commit] of model.commits.slice(0, limit).entries()) {
		let stepStatus: StepStatus = "pending";
		if (commit.status === "succeeded") stepStatus = "done";
		else if (commit.status === "failed") stepStatus = "failed";
		else if (commit.status === "running") stepStatus = "running";
		const glyph = paint(theme, stepStatusColor(stepStatus), stepIcon(stepStatus, spinnerFrame));
		appendCardWrappedText(lines, theme, width, `${glyph} `, "  ", commitRowText(model, commit, index), commitStatusColor(commit.status), MAX_CARD_FIELD_LINES);
		if (expanded) {
			if (commit.files.length > 0) appendCardField(lines, theme, width, "Files", commit.files.join(", "), MAX_EXPANDED_CARD_FIELD_LINES, "muted");
			else if (commit.requestedFiles.length > 0) appendCardField(lines, theme, width, "Requested", commit.requestedFiles.join(", "), MAX_EXPANDED_CARD_FIELD_LINES, "muted");
			if (commit.rationale) appendCardField(lines, theme, width, "Why", commit.rationale, MAX_CARD_FIELD_LINES, "muted");
			if (commit.errorText) appendCardField(lines, theme, width, "Blocked", commit.errorText, MAX_CARD_FIELD_LINES, "error");
		}
	}
	if (limit < model.commits.length) appendCardLine(lines, theme, width, paint(theme, "dim", `… ${model.commits.length - limit} more commits`));
}

function appendListField(lines: string[], theme: unknown, width: number, label: string, values: string[], maxLines: number, color: string): void {
	if (values.length === 0) return;
	appendCardField(lines, theme, width, label, values.map(redactSuspiciousTokens).join("; "), maxLines, color);
}

function appendOutcome(lines: string[], model: DashboardModel, theme: unknown, width: number, expanded: boolean): void {
	if (model.outcome.length === 0) return;
	appendCardSeparator(lines, theme, width, "outcome");
	const maxLines = expanded ? MAX_EXPANDED_CARD_FIELD_LINES : MAX_CARD_FIELD_LINES;
	appendCardWrappedText(lines, theme, width, "", "", model.outcome.join(" "), outcomeColor(model.status), maxLines);
}


function detailsChips(details: CommitRunDetails): string[] {
	return [
		details.dryRun ? "preview" : details.status === "succeeded" ? "done" : details.status,
		`${details.commits.length} ${plural("commit", details.commits.length)}`,
		`${details.selectedFiles.length} ${plural("file", details.selectedFiles.length)}`,
		details.push ? details.pushSucceeded ? "pushed" : details.pushSucceeded === false ? "push warning" : "push after" : undefined,
		details.warnings.length > 0 ? `${details.warnings.length} ${plural("warning", details.warnings.length)}` : undefined,
	].filter(isString);
}

function defaultRail(includePush: boolean): CommitStep[] {
	const steps: CommitStep[] = [
		{ key: "plan", label: "Plan", status: "pending" },
		{ key: "tree", label: "Tree", status: "pending" },
		{ key: "stage", label: "Stage", status: "pending" },
		{ key: "commit", label: "Commit", status: "pending" },
	];
	if (includePush) steps.push({ key: "push", label: "Push", status: "pending" });
	return steps;
}

function railFromDetails(details: CommitRunDetails): CommitStep[] {
	const defaults = defaultRail(details.push);
	const steps = Array.isArray(details.steps) ? details.steps : [];
	if (steps.length === 0 && details.status === "succeeded") {
		return defaults.map(step => ({ ...step, status: "done" }));
	}
	const known = new Map(steps.map(step => [step.key, step]));
	return defaults.map(step => known.get(step.key) ?? step);
}

function outcomeLines(details: CommitRunDetails): string[] {
	if (details.status === "failed") return [`Commit blocked: ${details.errorText ?? details.phase}`];
	if (details.status !== "succeeded") return [];
	if (details.dryRun) return ["No commit written."];
	if (!details.push) return [];
	return [details.pushSucceeded ? "Push succeeded." : "Push failed; commits are local."];
}

function statusIcon(status: RunStatus, spinnerFrame: number | undefined): string {
	if (status === "running" || status === "pending") return spinnerGlyph(spinnerFrame);
	return status === "succeeded" ? "✓" : "✖";
}

function stepIcon(status: StepStatus, spinnerFrame: number | undefined): string {
	if (status === "running") return spinnerGlyph(spinnerFrame);
	if (status === "done") return "✓";
	if (status === "failed") return "✖";
	return "○";
}

function spinnerGlyph(frame: number | undefined): string {
	return SPINNER_FRAMES[frameIndex(frame) % SPINNER_FRAMES.length] ?? SPINNER_FRAMES[0];
}

function frameIndex(frame: number | undefined): number {
	return frame ?? Math.floor(Date.now() / 120);
}

function statusColor(status: RunStatus): string {
	if (status === "succeeded") return "success";
	if (status === "failed") return "error";
	return "accent";
}


function dashboardTitleText(theme: unknown, model: DashboardModel, spinnerFrame: number | undefined): string {
	const title = dashboardTitle(model);
	if (model.status === "failed") return paint(theme, "error", strong(theme, title));
	return strong(theme, rainbowText(theme, title, spinnerFrame));
}

function appendPulseBar(lines: string[], model: DashboardModel, theme: unknown, spinnerFrame: number | undefined, width: number): void {
	const total = Math.max(8, Math.min(PULSE_BAR_WIDTH, cardContentWidth(width) - 12));
	const frame = frameIndex(spinnerFrame);
	const ratio = railProgressRatio(model.status, model.rail);
	const filledCount = progressFilledCount(model.status, ratio, total);
	let bar = "";
	for (let index = 0; index < total; index += 1) {
		const filled = index < filledCount;
		const glyph = filled ? "━" : "─";
		const color = progressBarColor(model.status, filled, index, frame);
		bar += paint(theme, color, glyph);
	}
	appendCardLine(lines, theme, width, `${paint(theme, "dim", "Progress")}: ${bar}`);
}

function progressFilledCount(status: RunStatus, ratio: number, total: number): number {
	if (status === "pending") return 0;
	if (status === "succeeded") return total;
	const count = Math.round(total * ratio);
	if (status === "failed") return Math.max(1, Math.min(total, count));
	return Math.max(1, Math.min(total, count));
}

function progressBarColor(status: RunStatus, filled: boolean, index: number, frame: number): string {
	if (!filled) return "dim";
	if (status === "failed") return "error";
	if (status === "succeeded") return "success";
	return PULSE_COLORS[(index + frame) % PULSE_COLORS.length] ?? "accent";
}

function railProgressRatio(status: RunStatus, rail: CommitStep[]): number {
	if (rail.length === 0) return status === "succeeded" ? 1 : 0;
	if (status === "succeeded") return 1;
	return rail.filter(step => step.status === "done").length / rail.length;
}


function rainbowText(theme: unknown, text: string, spinnerFrame: number | undefined): string {
	const frame = frameIndex(spinnerFrame);
	let visibleIndex = 0;
	let output = "";
	for (const char of text) {
		if (/\s/.test(char)) {
			output += char;
			continue;
		}
		const color = PULSE_COLORS[(visibleIndex + frame) % PULSE_COLORS.length] ?? "accent";
		output += paint(theme, color, char);
		visibleIndex += 1;
	}
	return output;
}


function heroTextColor(status: RunStatus): string {
	if (status === "failed") return "error";
	if (status === "succeeded") return "success";
	return "accent";
}

function commitStatusColor(status: CommitStatus): string {
	if (status === "succeeded") return "success";
	if (status === "failed") return "error";
	if (status === "running") return "accent";
	return "muted";
}

function outcomeColor(status: RunStatus): string {
	if (status === "failed") return "error";
	if (status === "succeeded") return "success";
	return "muted";
}

function pulseColor(spinnerFrame: number | undefined): string {
	const color = PULSE_COLORS[frameIndex(spinnerFrame) % PULSE_COLORS.length];
	return color ?? "accent";
}

function dashboardTitle(statusModel: DashboardModel): string {
	if (statusModel.status === "failed") return statusModel.dryRun ? "Preview blocked" : "Commit blocked";
	if (statusModel.status === "succeeded") return statusModel.dryRun ? "Preview ready" : "Commit complete";
	if (statusModel.status === "running") return statusModel.dryRun ? "Preview running" : "Commit running";
	return statusModel.dryRun ? "Preview queued" : "Commit queued";
}

function dashboardFooter(model: DashboardModel): string | undefined {
	if (model.finishedAt && model.startedAt) return `Done in ${formatDuration(model.finishedAt - model.startedAt)}`;
	if (model.startedAt && model.status === "running") return `Running ${formatDuration(Date.now() - model.startedAt)}`;
	return undefined;
}

function heroText(model: DashboardModel): string {
	if (model.status === "succeeded") return successHeroText(model);
	if (model.status === "failed") {
		return [model.dryRun ? "Preview blocked" : "Commit blocked", model.phase, dashboardDuration(model)].filter(isString).join(" · ");
	}
	const progress = railProgressText(model.rail);
	return [model.phase || "Running", progress].filter(isString).join(" · ");
}

function successHeroText(model: DashboardModel): string {
	const duration = dashboardDuration(model);
	if (model.dryRun) {
		return ["Preview ready", dashboardFileSummary(model), duration].filter(isString).join(" · ");
	}
	return [`${formatCommitGroup(model.commits.length)} created`, commitHashSummary(model), dashboardFileSummary(model), duration].filter(isString).join(" · ");
}

function dashboardDuration(model: DashboardModel): string | undefined {
	if (!model.finishedAt || !model.startedAt) return undefined;
	return formatDuration(model.finishedAt - model.startedAt);
}

function dashboardFileSummary(model: DashboardModel): string {
	const fileCount = dashboardFileCount(model);
	if (fileCount > 0) return formatFileCount(fileCount);
	return "all changes";
}

function dashboardFileCount(model: DashboardModel): number {
	const files = model.commits.flatMap(commit => commit.files.length > 0 ? commit.files : commit.requestedFiles);
	return new Set(files).size;
}

function commitHashSummary(model: DashboardModel): string | undefined {
	const hashes = model.commits.map(commit => commit.hash).filter(isString);
	if (hashes.length === 0) return undefined;
	if (hashes.length === 1) return hashes[0];
	return formatLimitedList(hashes, 3);
}

function railProgressText(rail: CommitStep[]): string | undefined {
	if (rail.length === 0) return undefined;
	const done = rail.filter(step => step.status === "done").length;
	return `${done}/${rail.length} steps`;
}

function commitRowText(model: DashboardModel, commit: DashboardCommit, index: number): string {
	const label = model.commits.length === 1 ? "Message" : formatCommitLabel(index, model.commits.length);
	const hash = commit.hash ? `${commit.hash} · ` : "";
	let files = " · all changes";
	if (commit.files.length > 0) files = ` · ${formatFileCount(commit.files.length)}`;
	else if (commit.requestedFiles.length > 0) files = ` · ${formatFileCount(commit.requestedFiles.length)} requested`;
	const subject = `${hash}${commit.subject}`;
	if (commit.status === "running") {
		const phase = commit.phase && commit.phase !== "Ready" ? `${commit.phase} · ` : "";
		return `${label} · ${phase}${subject}${files}`;
	}
	if (commit.status === "failed") return `${label} · blocked · ${subject}${files}`;
	if (commit.status === "pending") return `${label} · queued · ${subject}${files}`;
	return `${label} · ${subject}${files}`;
}

function stepStatusColor(status: StepStatus): string {
	if (status === "done") return "success";
	if (status === "failed") return "error";
	if (status === "running") return "accent";
	return "muted";
}


function formatCommitLabel(index: number, total: number): string {
	return total === 1 ? "Commit" : `Commit ${index + 1}/${total}`;
}

function formatCommitGroup(count: number): string {
	return count === 1 ? "Commit" : `${count} commits`;
}

function commitSubject(message: string | undefined): string {
	const subject = message?.split("\n", 1)[0]?.trim();
	return subject || "(missing message)";
}

function formatFileCount(count: number): string {
	return `${count} ${plural("file", count)}`;
}

function plural(word: string, count: number): string {
	return count === 1 ? word : `${word}s`;
}

function formatLimitedList(values: string[], limit: number): string {
	const visible = values.slice(0, limit).map(redactSuspiciousTokens);
	const suffix = values.length > limit ? `, … ${values.length - limit} more` : "";
	return `${visible.join(", ")}${suffix}`;
}

function addWarning(details: CommitRunDetails, text: string): void {
	details.warnings.push(redactSuspiciousTokens(text));
}

function formatError(error: unknown): string {
	if (error instanceof Error) return redactSuspiciousTokens(trimOutput(error.message));
	return redactSuspiciousTokens(trimOutput(String(error)));
}

function throwIfAborted(signal: AbortSignal | undefined): void {
	if (signal?.aborted) throw new WorkflowError("Commit workflow cancelled.");
}

function trimOutput(text: string): string {
	const compact = text.trim().replace(/\s+/g, " ");
	return compact.length > MAX_OUTPUT_CHARS ? `${compact.slice(0, MAX_OUTPUT_CHARS - 1)}…` : compact;
}

function redactSuspiciousTokens(text: string): string {
	return text.replace(/(?:gh[pousr]_|github_pat_|xox[baprs]-|sk-(?:proj-)?)\S{8,}/g, "<redacted>");
}

function cardBorder(theme: unknown, width: number, left: string, right: string, label?: string): string {
	const renderWidth = Math.max(MIN_RENDER_WIDTH, width);
	const innerWidth = Math.max(1, renderWidth - 2);
	if (!label) return paint(theme, "dim", `${left}${"─".repeat(innerWidth)}${right}`);
	const clipped = truncateVisible(label, Math.max(1, innerWidth - 3));
	const head = `${left}─ ${clipped} `;
	const fill = "─".repeat(Math.max(0, renderWidth - visibleLength(head) - 1));
	return `${paint(theme, "dim", `${left}─ `)}${clipped}${paint(theme, "dim", ` ${fill}${right}`)}`;
}

function appendCardLine(lines: string[], theme: unknown, width: number, content: string): void {
	const innerWidth = cardContentWidth(width);
	const clipped = truncateVisible(content, innerWidth);
	const padding = " ".repeat(Math.max(0, innerWidth - visibleLength(clipped)));
	lines.push(`${paint(theme, "dim", "│")} ${clipped}${padding} ${paint(theme, "dim", "│")}`);
}

function appendCardSeparator(lines: string[], theme: unknown, width: number, label?: string): void {
	lines.push(cardBorder(theme, width, "├", "┤", label ? paint(theme, "dim", label) : undefined));
}

function appendCardField(lines: string[], theme: unknown, width: number, label: string, value: string, maxLines: number, color = "muted"): void {
	appendCardWrappedText(lines, theme, width, `${paint(theme, "dim", label)}: `, "  ", value, color, maxLines);
}

function appendCardWrappedText(lines: string[], theme: unknown, width: number, prefix: string, continuationPrefix: string, value: string, color: string, maxLines: number): void {
	const innerWidth = cardContentWidth(width);
	const firstWidth = Math.max(1, innerWidth - visibleLength(prefix));
	const nextWidth = Math.max(1, innerWidth - visibleLength(continuationPrefix));
	const chunks = wrapPlainText(redactSuspiciousTokens(value), firstWidth, nextWidth, maxLines);
	for (const [index, chunk] of chunks.entries()) {
		appendCardLine(lines, theme, width, `${index === 0 ? prefix : continuationPrefix}${paint(theme, color, chunk)}`);
	}
}

function cardContentWidth(width: number): number {
	return Math.max(1, Math.max(MIN_RENDER_WIDTH, width) - 4);
}

function wrapPlainText(value: string, firstWidth: number, nextWidth: number, maxLines: number): string[] {
	const normalized = value.replace(/\s+/g, " ").trim();
	if (!normalized) return [""];
	const lines: string[] = [];
	let remaining = normalized;
	let width = Math.max(MIN_WRAP_CONTENT_WIDTH, firstWidth);
	while (remaining && lines.length < maxLines) {
		if (visibleLength(remaining) <= width) {
			lines.push(remaining);
			break;
		}
		const breakAt = findWrapBreak(remaining, width);
		lines.push(remaining.slice(0, breakAt).trimEnd());
		remaining = remaining.slice(breakAt).trimStart();
		width = Math.max(MIN_WRAP_CONTENT_WIDTH, nextWidth);
	}
	if (remaining && lines.length >= maxLines) {
		const last = lines[lines.length - 1] ?? "";
		lines[lines.length - 1] = appendEllipsis(last, Math.max(1, width));
	}
	return lines;
}

function findWrapBreak(value: string, width: number): number {
	const limit = Math.max(1, width);
	if (visibleLength(value) <= limit) return value.length;
	const slice = value.slice(0, limit + 1);
	const lastSpace = slice.lastIndexOf(" ");
	return lastSpace > 0 ? lastSpace : limit;
}

function appendEllipsis(value: string, width: number): string {
	if (visibleLength(value) < width) return `${value}…`;
	return `${truncateVisible(value, Math.max(1, width - 1))}…`;
}

function truncateVisible(input: string, width: number): string {
	if (width <= 0) return "";
	if (visibleLength(input) <= width) return input;
	let output = "";
	let visible = 0;
	for (let index = 0; index < input.length && visible < width - 1;) {
		if (input[index] === "\u001b") {
			const end = input.indexOf("m", index);
			if (end === -1) break;
			output += input.slice(index, end + 1);
			index = end + 1;
			continue;
		}
		output += input[index];
		index += 1;
		visible += 1;
	}
	return `${output}…`;
}

function visibleLength(input: string): number {
	return input.replace(/\u001b\[[0-9;]*m/g, "").length;
}

function formatDuration(ms: number): string {
	if (ms < 1_000) return `${Math.max(0, ms)}ms`;
	if (ms < 60_000) return `${(ms / 1_000).toFixed(1)}s`;
	const minutes = Math.floor(ms / 60_000);
	const seconds = Math.round((ms % 60_000) / 1_000);
	return `${minutes}m ${seconds}s`;
}

function isCommitRunDetails(value: unknown): value is CommitRunDetails {
	return isRecord(value)
		&& typeof value.phase === "string"
		&& typeof value.status === "string"
		&& Array.isArray(value.commits)
		&& Array.isArray(value.warnings);
}

function readDetails(result: unknown): unknown {
	return isRecord(result) ? result.details : undefined;
}

function firstResultText(result: unknown): string | undefined {
	if (!isRecord(result) || !Array.isArray(result.content)) return undefined;
	for (const item of result.content) {
		if (isRecord(item) && item.type === "text" && typeof item.text === "string") return item.text;
	}
	return undefined;
}

function getSpinnerFrame(options: unknown): number | undefined {
	if (!isRecord(options)) return undefined;
	return typeof options.spinnerFrame === "number" ? options.spinnerFrame : undefined;
}

function readRecordFlag(value: unknown, key: string): boolean {
	return isRecord(value) && Boolean(value[key]);
}

function stringValue(value: unknown): string | undefined {
	return typeof value === "string" ? value : undefined;
}

function stringArrayValue(value: unknown): string[] {
	return Array.isArray(value) ? value.filter(isString) : [];
}

function isString(value: unknown): value is string {
	return typeof value === "string";
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

interface ThemeRecord {
	fg?: (color: string, text: string) => string;
	bold?: (text: string) => string;
}

function paint(theme: unknown, color: string, text: string): string {
	if (!isThemeRecord(theme) || !theme.fg) return text;
	return theme.fg(color, text);
}

function strong(theme: unknown, text: string): string {
	if (!isThemeRecord(theme) || !theme.bold) return text;
	return theme.bold(text);
}

function isThemeRecord(value: unknown): value is ThemeRecord {
	return isRecord(value)
		&& (value.fg === undefined || typeof value.fg === "function")
		&& (value.bold === undefined || typeof value.bold === "function");
}

function dedupe(values: string[]): string[] {
	return [...new Set(values)];
}
