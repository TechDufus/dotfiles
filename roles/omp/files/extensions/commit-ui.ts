import * as fs from "node:fs";
import * as path from "node:path";
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
const COMMIT_SUBJECT_MAX_CHARS = 50;
const COMMIT_BODY_LINE_MAX_CHARS = 72;
const PREFERRED_COMMIT_TYPES = ["fix", "feat", "refactor", "docs", "test", "chore", "ci"] as const;
const COMMIT_MESSAGE_DESCRIPTION = `Conventional commit message preserved verbatim: subject must be type(scope): summary, preferably using ${PREFERRED_COMMIT_TYPES.join(", ")}, with a ${COMMIT_SUBJECT_MAX_CHARS}-character maximum; optional body starts after a blank second line and every non-blank body line is at most ${COMMIT_BODY_LINE_MAX_CHARS} characters.`;
const COMMIT_MESSAGE_ALIAS_DESCRIPTION = `Compatibility alias for commitMessage. ${COMMIT_MESSAGE_DESCRIPTION}`;
const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const PULSE_COLORS = ["accent", "success", "warning", "accent", "muted", "accent"] as const;
const PULSE_BAR_WIDTH = 22;
const COMMIT_WIDGET_FRAME_MS = 120;
const COMMIT_PARTIAL_UPDATE_MS = 120;
const COMMIT_UI_PAINT_YIELD_MS = 16;
const COMMIT_WORKING_MESSAGE = "Planning commit…";
const PRIVATE_KEY_BLOCK_PATTERN = /-----BEGIN [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----/;
const TOKEN_WARNING_PATTERNS: readonly { label: string; pattern: RegExp }[] = [
	{ label: "GitHub-looking token", pattern: /\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/ },
	{ label: "GitLab-looking token", pattern: /\bglpat-[A-Za-z0-9_-]{20,}\b/ },
	{ label: "OpenAI-looking token", pattern: /\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}\b/ },
];
const GITLEAKS_SCAN_TIMEOUT_SECONDS = 60;
const GITLEAKS_SCAN_TIMEOUT_MS = GITLEAKS_SCAN_TIMEOUT_SECONDS * 1_000;

type IntervalHandle = Parameters<typeof clearInterval>[0];

type RunStatus = "pending" | "running" | "succeeded" | "failed";
type StepStatus = "pending" | "running" | "done" | "failed";
type CommitStatus = "pending" | "running" | "succeeded" | "failed";
type StepKey = "plan" | "tree" | "stage" | "scan" | "commit" | "push";


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

interface CommitTransaction {
	workspacePath: string;
	candidateIndexPath: string;
	scanTreePath: string;
	rawInputPath: string;
	realIndexPath: string;
	realIndexFingerprint: string;
	expectedBase?: string;
	expectedRef?: string;
	configPath: string;
	ignorePath: string;
	dirReportPath: string;
	stdinReportPath: string;
	reportMarker: string;
	receiptPath: string;
	receiptMarker: string;
	referenceInputPath: string;
	commitProcessPath: string;
	hooksPath: string;
	originalHooksPath: string;
	messagePath: string;
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

interface CommitWidgetTui {
	requestRender(): void;
}

type CommitWidgetComponent = Component & { dispose?(): void };
type CommitWidgetFactory = (tui: CommitWidgetTui, theme: unknown) => CommitWidgetComponent;

interface CommitWidgetOptions {
	placement?: "aboveEditor" | "belowEditor";
}

interface UnrefableInterval {
	unref(): void;
}

interface CommitCommandUi {
	notify(message: string, level: string): void;
	setWorkingMessage?(message: string | undefined): void | Promise<void>;
	setWidget?(key: string, content: CommitWidgetFactory | string[] | undefined, options?: CommitWidgetOptions): void | Promise<void>;
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

function unrefInterval(handle: IntervalHandle | undefined): void {
	if (hasIntervalUnref(handle)) handle.unref();
}

function hasIntervalUnref(handle: unknown): handle is UnrefableInterval {
	return typeof handle === "object" && handle !== null && "unref" in handle && typeof handle.unref === "function";
}

export default function commitUi(pi: ExtensionAPI): void {
	const z = pi.zod;
	let activeSession: CommitCommandSession | undefined;
	pi.setLabel?.("commit UI");

	const commitParam = z.object({
		files: z.array(z.string()).optional().describe("Repo-relative files or directories for this commit. Split commits must name the changed files they own."),
		commitMessage: z.string().optional().describe(COMMIT_MESSAGE_DESCRIPTION),
		message: z.string().optional().describe(COMMIT_MESSAGE_ALIAS_DESCRIPTION),
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
			commitMessage: z.string().optional().describe(COMMIT_MESSAGE_DESCRIPTION),
			message: z.string().optional().describe(COMMIT_MESSAGE_ALIAS_DESCRIPTION),
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
			let heartbeat: IntervalHandle | undefined;
			try {
				const plan = normalizeCommitPlan(params);
				const details = createRunDetails(plan);
				const emit = () => {
					const snapshot = cloneCommitRunDetails(details);
					activeSession?.mirror(snapshot);
					if (!onUpdate) return;
					onUpdate({ content: [{ type: "text", text: snapshot.phase }], details: snapshot });
				};
				emit();
				await waitForUiPaint();
				if (onUpdate) {
					heartbeat = setInterval(() => {
						try {
							emit();
						} catch {
							// Heartbeat repainting must never alter commit behavior.
						}
					}, COMMIT_PARTIAL_UPDATE_MS);
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
				}

				return {
					content: [{ type: "text", text: buildToolResultText(details) }],
					details,
					isError: details.status === "failed",
				};
			} finally {
				clearInterval(heartbeat);
				await activeSession?.clearCommandUi();
			}
		},

		renderCall(args: unknown, _options: unknown, theme: unknown) {
			return new CommitQueuedReceiptComponent(normalizeCommitPlan(args), theme);
		},
		renderResult(result: unknown, options: unknown, theme: unknown) {
			const details = readDetails(result);
			if (!isCommitRunDetails(details)) {
				return new StaticLinesComponent([paint(theme, "muted", firstResultText(result) ?? "Commit workflow")]);
			}
			return new CommitResultCardComponent(details, Boolean(readRecordFlag(options, "expanded")), theme, getSpinnerFrame(options));
		},
	});

	const restoreActiveSession = async () => {
		const session = activeSession;
		if (!session) return;
		activeSession = undefined;
		await session.restoreActiveTools();
	};

	pi.registerCommand("commit", {
		description: "Plan from current context, then commit behind one live progress card",
		handler: async (args: string, ctx: CommitCommandContext) => {
			if (activeSession) {
				ctx.ui.notify("A commit workflow is already running.", "warning");
				return;
			}

			const parsed = parseCommitArgs(args);
			const session = new CommitCommandSession(pi, ctx.ui);
			activeSession = session;
			try {
				await session.startLiveWidget(parsed);
				ctx.ui.notify(COMMIT_WORKING_MESSAGE, "info");
				await session.setWorkingMessage(COMMIT_WORKING_MESSAGE);
				if (!ctx.isIdle()) {
					ctx.ui.notify("Commit queued until the current turn finishes.", "info");
					await ctx.waitForIdle();
				}

				await session.beginToolTurn(parsed);
			} catch (error) {
				if (activeSession === session) activeSession = undefined;
				await session.abort();
				throw error;
			}
		},
	});

	pi.on("turn_end", restoreActiveSession);
	pi.on("agent_end", restoreActiveSession);
}

class CommitCommandSession {
	private previousActiveTools: string[] | undefined;
	private widgetController: CommitLiveWidgetController | undefined;
	private commandUiCleared = false;
	private activeToolsIsolated = false;
	private activeToolsRestored = false;

	constructor(
		private readonly pi: ExtensionAPI,
		private readonly ui: CommitCommandUi,
	) {}

	async startLiveWidget(parsed: ParsedArgs): Promise<void> {
		const setWidget = this.ui.setWidget;
		if (typeof setWidget !== "function") return;
		this.disposeWidget();
		const widget = new CommitLiveWidgetController(createPlanningRunDetails(parsed));
		this.widgetController = widget;
		try {
			await setWidget.call(this.ui, TOOL_NAME, (tui, theme) => widget.createComponent(tui, theme), { placement: "aboveEditor" });
		} catch (error) {
			if (this.widgetController === widget) this.widgetController = undefined;
			widget.dispose();
			throw error;
		}
	}

	async setWorkingMessage(message: string | undefined): Promise<void> {
		await setCommandWorkingMessage(this.ui, message);
	}

	async beginToolTurn(parsed: ParsedArgs): Promise<void> {
		this.previousActiveTools = this.pi.getActiveTools();
		await this.pi.setActiveTools([TOOL_NAME]);
		this.activeToolsIsolated = true;
		this.pi.sendMessage(
			{
				customType: "commit-request",
				content: buildToolInvocationPrompt(parsed),
				display: false,
				details: parsed,
				attribution: "user",
			},
			{ triggerTurn: true, deliverAs: "nextTurn" },
		);
	}

	mirror(details: CommitRunDetails): void {
		this.widgetController?.update(details);
	}

	async clearCommandUi(): Promise<void> {
		if (this.commandUiCleared) return;
		this.commandUiCleared = true;
		this.disposeWidget();
		try {
			await this.clearWidget();
		} finally {
			await this.setWorkingMessage(undefined);
		}
	}

	async abort(): Promise<void> {
		await this.restoreActiveTools();
	}

	async restoreActiveTools(): Promise<void> {
		await this.clearCommandUi();
		if (this.activeToolsRestored) return;
		this.activeToolsRestored = true;
		if (!this.activeToolsIsolated || !this.previousActiveTools) return;
		const tools = this.previousActiveTools;
		this.previousActiveTools = undefined;
		await this.pi.setActiveTools(tools);
	}

	private disposeWidget(): void {
		const widget = this.widgetController;
		this.widgetController = undefined;
		widget?.dispose();
	}

	private async clearWidget(): Promise<void> {
		const setWidget = this.ui.setWidget;
		if (typeof setWidget !== "function") return;
		await setWidget.call(this.ui, TOOL_NAME, undefined);
	}
}

class CommitQueuedReceiptComponent implements Component {
	constructor(
		private readonly plan: CommitPlan,
		private readonly theme: unknown,
	) {}

	invalidate(): void {}

	render(width: number): string[] {
		return renderQueuedReceipt(this.plan, this.theme, width);
	}
}

class CommitResultCardComponent implements Component {
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

class CommitLiveWidgetController {
	private details: CommitRunDetails;
	private readonly components = new Set<CommitLiveWidgetComponent>();
	private disposed = false;

	constructor(details: CommitRunDetails) {
		this.details = cloneCommitRunDetails(details);
	}

	createComponent(tui: CommitWidgetTui, theme: unknown): CommitLiveWidgetComponent {
		const component = new CommitLiveWidgetComponent(this, tui, theme);
		this.components.add(component);
		return component;
	}

	snapshot(): CommitRunDetails {
		return this.details;
	}

	update(details: CommitRunDetails): void {
		if (this.disposed) return;
		this.details = cloneCommitRunDetails(details);
		for (const component of this.components) {
			component.requestRender();
		}
	}

	detach(component: CommitLiveWidgetComponent): void {
		this.components.delete(component);
	}

	dispose(): void {
		if (this.disposed) return;
		this.disposed = true;
		for (const component of [...this.components]) {
			component.dispose();
		}
		this.components.clear();
	}
}

class CommitLiveWidgetComponent implements Component {
	private spinnerFrame = 0;
	private interval: IntervalHandle | undefined;
	private disposed = false;

	constructor(
		private readonly controller: CommitLiveWidgetController,
		private readonly tui: CommitWidgetTui,
		private readonly theme: unknown,
	) {
		this.interval = setInterval(() => {
			this.spinnerFrame = (this.spinnerFrame + 1) % SPINNER_FRAMES.length;
			this.requestRender();
		}, COMMIT_WIDGET_FRAME_MS);
		unrefInterval(this.interval);
	}

	invalidate(): void {}

	requestRender(): void {
		try {
			this.tui.requestRender();
		} catch {
			// Widget repainting must never alter commit behavior.
		}
	}

	render(width: number): string[] {
		return renderDashboard(dashboardFromDetails(this.controller.snapshot()), false, this.theme, this.spinnerFrame, width);
	}

	dispose(): void {
		if (this.disposed) return;
		this.disposed = true;
		clearInterval(this.interval);
		this.interval = undefined;
		this.controller.detach(this);
	}
}


class StaticLinesComponent implements Component {
	constructor(private readonly lines: string[]) {}

	invalidate(): void {}

	render(width: number): string[] {
		return this.lines.map(line => truncateVisible(line, Math.max(MIN_RENDER_WIDTH, width)));
	}
}

function renderQueuedReceipt(plan: CommitPlan, theme: unknown, width: number): string[] {
	const renderWidth = Math.max(MIN_RENDER_WIDTH, width);
	const fileCount = new Set(plan.commits.flatMap(commit => commit.files)).size;
	const metadata = fileCount > 0 ? ` · ${formatFileCount(fileCount)}` : "";
	return [
		truncateVisible(`${paint(theme, "accent", "/commit queued")}${paint(theme, "muted", metadata)}`, renderWidth),
	];
}
function waitForUiPaint(): Promise<void> {
	const { promise, resolve } = Promise.withResolvers<void>();
	setTimeout(resolve, COMMIT_UI_PAINT_YIELD_MS);
	return promise;
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
		await waitForUiPaint();
		const rawStatus = (await runGit(cwd, ["status", "--porcelain=v1", "-z", "--untracked-files=all"], signal, details)).stdout;
		const entries = parseStatusZ(rawStatus);
		if (entries.length === 0) throw new WorkflowError("No working tree changes to commit.");
		resolveSelections(plan, details, entries);
		await guardUnrelatedStagedChanges(cwd, details, signal);
		details.phase = "Checking selected changes";
		onUpdate();
		await inspectSelectedChangeSafety(cwd, details, entries, signal);
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
			const createdOid = await withCommitTransaction(cwd, signal, details, async transaction => {
				setCommitState(result, "running", "Staging selected files");
				details.phase = `${label}: staging selected files`;
				onUpdate();
				await runStep(details, "stage", "Stage", onUpdate, () => stageCommitCandidate(cwd, transaction, result.commitFiles, signal, details));

				const scannedTree = await writeCandidateTree(cwd, transaction, signal, details);

				setCommitState(result, "running", "Scanning staged files");
				details.phase = `${label}: scanning staged files`;
				onUpdate();
				await runStep(details, "scan", "Scan", onUpdate, () => scanStagedChanges(cwd, transaction, result.commitFiles, signal, details));

				setCommitState(result, "running", "Creating commit");
				details.phase = `${label}: creating commit`;
				onUpdate();
				const oid = await runStep(details, "commit", "Commit", onUpdate, () =>
					commitCandidate(cwd, transaction, commit.commitMessage, scannedTree, signal, details),
				);

				try {
					const reconciled = await reconcileCommittedPaths(cwd, transaction, result.commitFiles, oid, details);
					if (!reconciled) addWarning(details, "Committed paths were not reconciled because newer staged changes were preserved.");
				} catch {
					addWarning(details, "Committed paths were not reconciled because newer staged changes were preserved.");
				}
				return oid;
			});

			setCommitState(result, "running", "Reading commit hash");
			details.phase = `${label}: reading commit hash`;
			onUpdate();
			await waitForUiPaint();
			const hash = (await runGit(cwd, ["rev-parse", "--short", createdOid], undefined, details)).stdout.trim();
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
	await waitForUiPaint();
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
	const files = dedupe(stringArrayValue(record.files));
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

function createPlanningRunDetails(parsed: ParsedArgs): CommitRunDetails {
	const details = createRunDetails({
		commits: [{
			files: [],
			deriveFilesFromStatus: true,
			commitMessage: "Planning from current context",
			rationale: "Scanning files from current context",
		}],
		context: parsed.context,
		dryRun: parsed.dryRun,
		push: parsed.push,
		multiCommit: parsed.multiCommit,
	});
	details.phase = "Planning from current context";
	details.steps = [{ key: "plan", label: "Plan", status: "running" }];
	const commit = details.commits[0];
	if (commit) commit.phase = "Scanning current context";
	return details;
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

function validateCommitMessage(message: string, prefix: string): void {
	if (!message.trim()) throw new WorkflowError(`${prefix}commit message is required.`);
	if (message.includes("\0")) throw new WorkflowError(`${prefix}commit message contains a NUL byte.`);

	const lines = message.split(/\r?\n/);
	const subject = lines[0] ?? "";
	if (!parseConventionalCommitSubject(subject)) {
		throw new WorkflowError(`${prefix}commit message subject must match "type(scope): summary" (preferred types: ${PREFERRED_COMMIT_TYPES.join(", ")}).`);
	}
	if (subject.length > COMMIT_SUBJECT_MAX_CHARS) {
		throw new WorkflowError(`${prefix}commit message subject must be ${COMMIT_SUBJECT_MAX_CHARS} characters or fewer.`);
	}

	const bodyLines = lines.slice(1);
	const hasBody = bodyLines.some(line => line.trim().length > 0);
	if (hasBody && lines[1] !== "") {
		throw new WorkflowError(`${prefix}commit message body must start after a blank second line.`);
	}

	for (const [offset, line] of bodyLines.entries()) {
		if (line.trim().length > 0 && line.length > COMMIT_BODY_LINE_MAX_CHARS) {
			throw new WorkflowError(`${prefix}commit message body line ${offset + 2} must be ${COMMIT_BODY_LINE_MAX_CHARS} characters or fewer.`);
		}
	}
}

function parseConventionalCommitSubject(subject: string): { type: string; scope: string; summary: string } | undefined {
	const match = subject.match(/^([a-z][a-z0-9-]*)\(([a-z0-9][a-z0-9._/-]*)\): (.+)$/);
	if (!match) return undefined;
	const [, type, scope, summary] = match;
	if (!type || !scope || !summary.trim()) return undefined;
	return { type, scope, summary };
}

function validateCommitSpec(commit: CommitSpec, label: string): void {
	const prefix = label === "Commit" ? "" : `${label}: `;
	validateCommitMessage(commit.commitMessage, prefix);
	if (commit.rationale.includes("\0")) throw new WorkflowError(`${prefix}rationale contains a NUL byte.`);
	commit.files = dedupe(commit.files.map(file => validateRepoPath(file, prefix)));
	commit.deriveFilesFromStatus = commit.files.length === 0;
}

function validateRepoPath(input: string, prefix: string): string {
	if (input.includes("\0")) throw new WorkflowError(`${prefix}file path contains a NUL byte.`);
	if (input === "") throw new WorkflowError(`${prefix}file path is empty.`);
	if (path.isAbsolute(input)) {
		throw new WorkflowError(`${prefix}file path must be repo-relative: ${redactSuspiciousTokens(input)}`);
	}
	if (input.split("/").includes("..")) {
		throw new WorkflowError(`${prefix}file path must not contain '..': ${redactSuspiciousTokens(input)}`);
	}
	return input;
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

async function inspectSelectedChangeSafety(
	cwd: string,
	details: CommitRunDetails,
	status: GitStatusEntry[],
	signal: AbortSignal | undefined,
): Promise<void> {
	const selectedFiles = dedupe(details.commits.flatMap(commit => commit.selectedFiles));
	if (selectedFiles.length === 0) return;
	const changedContent = await readSelectedChangedContent(cwd, selectedFiles, status, signal, details);
	if (PRIVATE_KEY_BLOCK_PATTERN.test(changedContent)) {
		throw new WorkflowError("Selected changes contain a private key block. Remove it before committing.");
	}
	for (const { label, pattern } of TOKEN_WARNING_PATTERNS) {
		if (pattern.test(changedContent)) addWarning(details, `${label} found in selected changes; review before pushing.`);
	}
}

async function readSelectedChangedContent(
	cwd: string,
	selectedFiles: string[],
	status: GitStatusEntry[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<string> {
	const literalPathEnvironment = { GIT_LITERAL_PATHSPECS: "1" };
	const parts = [
		extractAddedDiffLines(
			(await runGit(cwd, ["diff", "--no-ext-diff", "--no-color", "--unified=0", "--", ...selectedFiles], signal, details, literalPathEnvironment)).stdout,
		),
		extractAddedDiffLines(
			(await runGit(cwd, ["diff", "--cached", "--no-ext-diff", "--no-color", "--unified=0", "--", ...selectedFiles], signal, details, literalPathEnvironment)).stdout,
		),
	];
	const statusByPath = new Map(status.map(entry => [entry.path, entry]));
	for (const file of selectedFiles) {
		if (statusByPath.get(file)?.code === "??") parts.push(await readUntrackedChangedContent(cwd, file, signal, details));
	}
	return parts.filter(Boolean).join("\n");
}

async function readUntrackedChangedContent(cwd: string, file: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<string> {
	const result = await runCommand(cwd, "git", ["diff", "--no-index", "--no-ext-diff", "--no-color", "--unified=0", "--", "/dev/null", file], signal, details);
	if (result.exitCode > 1) {
		details.failedToolCount += 1;
		throw new CommandError(`git diff failed: ${trimOutput(result.stderr || result.stdout)}`, result);
	}
	return extractAddedDiffLines(result.stdout);
}

function extractAddedDiffLines(rawDiff: string): string {
	return rawDiff
		.split("\n")
		.filter(line => line.startsWith("+") && !line.startsWith("+++"))
		.map(line => line.slice(1))
		.join("\n");
}

async function withCommitTransaction<T>(
	cwd: string,
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
	fn: (transaction: CommitTransaction) => Promise<T>,
): Promise<T> {
	const transaction = await createCommitTransaction(cwd, signal, details);
	try {
		return await fn(transaction);
	} finally {
		try {
			await fs.promises.rm(transaction.workspacePath, { recursive: true, force: true, maxRetries: 3, retryDelay: 50 });
		} catch {
			addWarning(details, "Private commit workspace cleanup could not be completed.");
		}
	}
}

async function createCommitTransaction(cwd: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<CommitTransaction> {
	let workspacePath: string | undefined;
	try {
		const privateWorkspace = await fs.promises.mkdtemp(path.join(Bun.env.TMPDIR || "/tmp", "omp-commit-"));
		workspacePath = privateWorkspace;
		await fs.promises.chmod(privateWorkspace, 0o700);

		const realIndexPath = parseGitPathOutput(
			(await runGit(cwd, ["rev-parse", "--path-format=absolute", "--git-path", "index"], signal, details)).stdout,
			"Unable to resolve Git index path.",
		);
		const realIndexFingerprint = await indexFingerprint(cwd, realIndexPath, details);
		const originalHooksPath = await resolveEffectiveHooksPath(cwd, signal, details);
		const configPath = path.join(privateWorkspace, "gitleaks.toml");
		const ignorePath = path.join(privateWorkspace, "gitleaks.ignore");
		const dirReportPath = path.join(privateWorkspace, "gitleaks-dir-report.json");
		const stdinReportPath = path.join(privateWorkspace, "gitleaks-stdin-report.json");
		const reportMarker = "omp-gitleaks-report-pending\n";
		const rawInputPath = path.join(privateWorkspace, "gitleaks-stdin.input");
		const receiptPath = path.join(privateWorkspace, "reference-transaction.receipt");
		const receiptMarker = "pending\n";
		const referenceInputPath = path.join(privateWorkspace, "reference-transaction.input");
		const commitProcessPath = path.join(privateWorkspace, "commit-process.marker");
		const scanTreePath = path.join(privateWorkspace, "scan-tree");
		await fs.promises.mkdir(scanTreePath, { mode: 0o700 });
		await writePrivateFile(configPath, "[extend]\nuseDefault = true\n");
		await writePrivateFile(ignorePath, "");
		await writePrivateFile(dirReportPath, reportMarker);
		await writePrivateFile(stdinReportPath, reportMarker);
		await writePrivateFile(rawInputPath, `${"A".repeat(512)}\n`);
		await writePrivateFile(receiptPath, receiptMarker);
		await writePrivateFile(referenceInputPath, "");
		await writePrivateFile(commitProcessPath, "pending\n");

		return {
			workspacePath: privateWorkspace,
			candidateIndexPath: path.join(privateWorkspace, "candidate.index"),
			scanTreePath,
			rawInputPath,
			realIndexPath,
			realIndexFingerprint,
			configPath,
			ignorePath,
			dirReportPath,
			stdinReportPath,
			reportMarker,
			receiptPath,
			receiptMarker,
			referenceInputPath,
			commitProcessPath,
			hooksPath: path.join(privateWorkspace, "hooks"),
			originalHooksPath,
			messagePath: path.join(privateWorkspace, "message"),
		};
	} catch (error) {
		if (workspacePath) {
			try {
				await fs.promises.rm(workspacePath, { recursive: true, force: true, maxRetries: 3, retryDelay: 50 });
			} catch {
				addWarning(details, "Private commit workspace cleanup could not be completed.");
			}
		}
		if (signal?.aborted) throw error;
		throw new WorkflowError("Unable to initialize a private commit transaction.");
	}
}

async function stageCommitCandidate(
	cwd: string,
	transaction: CommitTransaction,
	commitFiles: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<void> {
	transaction.expectedRef = await symbolicHead(cwd, signal, details);
	transaction.expectedBase = await verifiedHead(cwd, signal, details);
	if (transaction.expectedBase) {
		await runGit(cwd, ["read-tree", transaction.expectedBase], signal, details, candidateIndexEnvironment(transaction));
	}
	await runGit(cwd, ["add", "-A", "--", ...commitFiles], signal, details, candidatePathEnvironment(transaction));
	await ensurePrivateRegularFile(transaction.candidateIndexPath, 0o600);
}

async function symbolicHead(cwd: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<string | undefined> {
	const result = await runCommand(cwd, "git", ["symbolic-ref", "-q", "HEAD"], signal, details);
	if (result.exitCode === 1) return undefined;
	const ref = result.stdout.trim();
	if (result.exitCode !== 0 || !ref.startsWith("refs/") || ref.includes("\n")) {
		details.failedToolCount += 1;
		throw new WorkflowError("Unable to verify the current Git reference.");
	}
	return ref;
}

async function verifiedHead(cwd: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<string | undefined> {
	const result = await runCommand(cwd, "git", ["rev-parse", "--verify", "--quiet", "HEAD^{commit}"], signal, details);
	if (result.exitCode === 1) return undefined;
	if (result.exitCode !== 0 || !isGitObjectId(result.stdout.trim())) {
		details.failedToolCount += 1;
		throw new WorkflowError("Unable to verify the current commit base.");
	}
	return result.stdout.trim();
}

async function writeCandidateTree(
	cwd: string,
	transaction: CommitTransaction,
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<string> {
	const tree = (await runGit(cwd, ["write-tree"], signal, details, candidateIndexEnvironment(transaction))).stdout.trim();
	if (!isGitObjectId(tree)) throw new WorkflowError("Unable to record the scanned candidate tree.");
	return tree;
}
async function materializeCandidateBlobs(
	cwd: string,
	transaction: CommitTransaction,
	commitFiles: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<void> {
	const listed = await runGit(
		cwd,
		["ls-files", "--stage", "-z", "--", ...commitFiles],
		signal,
		details,
		candidatePathEnvironment(transaction),
	);
	const rawInput = await fs.promises.open(transaction.rawInputPath, "r+");
	try {
		await rawInput.truncate(0);
		await rawInput.write(`${"A".repeat(512)}\n`);
		const scanRootPrefix = `${path.resolve(transaction.scanTreePath)}${path.sep}`;
		for (const record of listed.stdout.split("\0")) {
			if (!record) continue;
			const separator = record.indexOf("\t");
			const metadata = separator >= 0 ? /^([0-7]{6}) ([0-9a-f]{40,128}) ([0-3])$/.exec(record.slice(0, separator)) : null;
			const file = separator >= 0 ? record.slice(separator + 1) : "";
			if (!metadata || !file || metadata[3] !== "0") {
				throw new WorkflowError("Unable to enumerate exact candidate blobs for scanning.");
			}
			const mode = metadata[1];
			const objectId = metadata[2];
			if (mode === "160000") continue;
			if (mode !== "100644" && mode !== "100755" && mode !== "120000") {
				throw new WorkflowError("Candidate contained an unsupported index entry.");
			}
			const destination = path.resolve(transaction.scanTreePath, file);
			if (!destination.startsWith(scanRootPrefix)) throw new WorkflowError("Candidate contained an unsafe scan path.");
			await fs.promises.mkdir(path.dirname(destination), { recursive: true, mode: 0o700 });
			const output = await fs.promises.open(destination, "wx", 0o600);
			try {
				const result = await runCommand(
					cwd,
					"git",
					["cat-file", "blob", objectId],
					signal,
					details,
					{ GIT_NO_REPLACE_OBJECTS: "1" },
					output,
				);
				if (result.exitCode !== 0) {
					details.failedToolCount += 1;
					throw new WorkflowError("Unable to materialize an exact candidate blob for scanning.");
				}
				await output.sync();
			} finally {
				await output.close();
			}
			await ensurePrivateRegularFile(destination, 0o600);
			for await (const chunk of fs.createReadStream(destination)) await rawInput.write(chunk);
			await rawInput.write("\n");
		}
		await rawInput.sync();
	} finally {
		await rawInput.close();
	}
	await ensurePrivateRegularFile(transaction.rawInputPath, 0o600);
}

async function scanStagedChanges(
	cwd: string,
	transaction: CommitTransaction,
	commitFiles: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<void> {
	await materializeCandidateBlobs(cwd, transaction, commitFiles, signal, details);
	const environment: Record<string, string | undefined> = {};
	for (const name of Object.keys(Bun.env)) {
		if (name.startsWith("GITLEAKS")) environment[name] = undefined;
	}
	const gitleaksCommand = await detectGitleaksCommand(cwd, signal, details, environment);
	await runGitleaksPass(
		cwd,
		transaction,
		gitleaksCommand,
		["dir", transaction.scanTreePath],
		transaction.dirReportPath,
		signal,
		details,
		environment,
	);
	const rawInput = await fs.promises.open(transaction.rawInputPath, "r");
	try {
		await runGitleaksPass(
			cwd,
			transaction,
			gitleaksCommand,
			["stdin"],
			transaction.stdinReportPath,
			signal,
			details,
			environment,
			rawInput,
		);
	} finally {
		await rawInput.close();
	}
}

async function runGitleaksPass(
	cwd: string,
	transaction: CommitTransaction,
	gitleaksCommand: string,
	commandArgs: string[],
	reportPath: string,
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
	environment: Record<string, string | undefined>,
	stdinFile?: fs.promises.FileHandle,
): Promise<void> {
	let result: CommandResult;
	try {
		result = await runGitleaksWithTimeout(
			cwd,
			gitleaksCommand,
			[
				...commandArgs,
				"--redact",
				"--no-banner",
				"--no-color",
				"--timeout",
				String(GITLEAKS_SCAN_TIMEOUT_SECONDS),
				"--config",
				transaction.configPath,
				"--gitleaks-ignore-path",
				transaction.ignorePath,
				"--ignore-gitleaks-allow",
				"--report-format",
				"json",
				"--report-path",
				reportPath,
			],
			signal,
			details,
			environment,
			stdinFile,
		);
	} catch (error) {
		if (signal?.aborted) throw error;
		details.failedToolCount += 1;
		throw error;
	}
	let findings: boolean;
	try {
		findings = await gitleaksReportHasFindings(reportPath, transaction.reportMarker);
	} catch (error) {
		if (signal?.aborted) throw error;
		details.failedToolCount += 1;
		throw new WorkflowError("Gitleaks scan failed; commit was not created.");
	}
	if (findings) {
		if (result.exitCode !== 0) details.failedToolCount += 1;
		throw new WorkflowError("Gitleaks detected potential secrets; commit was not created.");
	}
	if (result.exitCode !== 0) {
		details.failedToolCount += 1;
		throw new WorkflowError("Gitleaks scan failed; commit was not created.");
	}
}

async function detectGitleaksCommand(
	cwd: string,
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
	environment: Record<string, string | undefined>,
): Promise<string> {
	const requiredFlags = [
		"--redact",
		"--no-banner",
		"--no-color",
		"--timeout",
		"--config",
		"--gitleaks-ignore-path",
		"--ignore-gitleaks-allow",
		"--report-format",
		"--report-path",
	];
	const candidates = ["gitleaks"];
	const home = Bun.env.HOME;
	if (home) candidates.push(path.join(home, ".local", "bin", "gitleaks"));
	for (const candidate of candidates) {
		let compatible = true;
		for (const subcommand of ["dir", "stdin"]) {
			try {
				const result = await runGitleaksWithTimeout(
					cwd,
					candidate,
					[subcommand, "--help"],
					signal,
					details,
					environment,
				);
				const help = `${result.stdout}\n${result.stderr}`;
				if (result.exitCode !== 0 || requiredFlags.some(flag => !help.includes(flag))) compatible = false;
			} catch (error) {
				if (signal?.aborted) throw error;
				compatible = false;
			}
		}
		if (compatible) return candidate;
	}
	details.failedToolCount += 1;
	throw new WorkflowError("Gitleaks is unavailable or incompatible; commit was not created.");
}

async function runGitleaksWithTimeout(
	cwd: string,
	command: string,
	args: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
	environment: Record<string, string | undefined>,
	stdinFile?: fs.promises.FileHandle,
): Promise<CommandResult> {
	const controller = new AbortController();
	let timedOut = false;
	const timeout = setTimeout(() => {
		timedOut = true;
		controller.abort();
	}, GITLEAKS_SCAN_TIMEOUT_MS);
	const abort = () => controller.abort();
	if (signal?.aborted) controller.abort();
	else signal?.addEventListener("abort", abort, { once: true });
	try {
		return await runCommand(cwd, command, args, controller.signal, details, environment, undefined, stdinFile);
	} catch (error) {
		if (timedOut) throw new WorkflowError("Gitleaks scan timed out; commit was not created.");
		if (signal?.aborted) throw error;
		throw new WorkflowError("Gitleaks scan failed; commit was not created.");
	} finally {
		clearTimeout(timeout);
		signal?.removeEventListener("abort", abort);
	}
}

async function gitleaksReportHasFindings(reportPath: string, reportMarker: string): Promise<boolean> {
	const metadata = await fs.promises.lstat(reportPath);
	if (!metadata.isFile()) throw new WorkflowError("Gitleaks report was not a regular file.");
	await fs.promises.chmod(reportPath, 0o600);
	const rawReport = await fs.promises.readFile(reportPath, "utf8");
	if (!rawReport.trim() || rawReport === reportMarker) {
		throw new WorkflowError("Gitleaks report was not freshly written.");
	}
	const parsed: unknown = JSON.parse(rawReport);
	if (!Array.isArray(parsed)) throw new WorkflowError("Gitleaks report had an invalid format.");
	return parsed.length > 0;
}

async function commitCandidate(
	cwd: string,
	transaction: CommitTransaction,
	message: string,
	scannedTree: string,
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
): Promise<string> {
	await preparePrivateHooks(transaction, scannedTree);
	await writePrivateFile(transaction.messagePath, message);
	try {
		await runGit(
			cwd,
			["-c", `core.hooksPath=${transaction.hooksPath}`, "commit", "--cleanup=verbatim", "-F", transaction.messagePath],
			signal,
			details,
			candidateIndexEnvironment(transaction),
		);
	} catch (error) {
		const createdOid = await committedCandidateFromReceipt(cwd, transaction, scannedTree, details);
		if (createdOid) return createdOid;
		throw error;
	}
	const createdOid = await committedCandidateFromReceipt(cwd, transaction, scannedTree, details);
	if (!createdOid) throw new WorkflowError("Created commit did not match the scanned candidate transaction.");
	return createdOid;
}
async function committedCandidateFromReceipt(
	cwd: string,
	transaction: CommitTransaction,
	scannedTree: string,
	details: CommitRunDetails,
): Promise<string | undefined> {
	try {
		const metadata = await fs.promises.lstat(transaction.receiptPath);
		if (!metadata.isFile()) return undefined;
		await fs.promises.chmod(transaction.receiptPath, 0o600);
		const receipt = await fs.promises.readFile(transaction.receiptPath, "utf8");
		const match = /^committed:([0-9a-f]{40,128})\n$/.exec(receipt);
		if (!match) return undefined;
		const createdOid = match[1];
		const expectedTarget = transaction.expectedRef ?? "HEAD";
		const target = await runCommand(cwd, "git", ["--no-replace-objects", "rev-parse", "--verify", expectedTarget], undefined, details);
		if (target.exitCode !== 0 || target.stdout.trim() !== createdOid) return undefined;
		const tree = await runCommand(cwd, "git", ["--no-replace-objects", "rev-parse", "--verify", `${createdOid}^{tree}`], undefined, details);
		if (tree.exitCode !== 0 || tree.stdout.trim() !== scannedTree) return undefined;
		const ancestry = await runCommand(cwd, "git", ["--no-replace-objects", "rev-list", "--parents", "-n", "1", createdOid], undefined, details);
		if (ancestry.exitCode !== 0) return undefined;
		const commitAndParents = ancestry.stdout.trim().split(/\s+/);
		const expectedParents = transaction.expectedBase ? [createdOid, transaction.expectedBase] : [createdOid];
		if (commitAndParents.length !== expectedParents.length || commitAndParents.some((oid, index) => oid !== expectedParents[index])) {
			return undefined;
		}
		return createdOid;
	} catch {
		return undefined;
	}
}

function parseGitPathOutput(output: string, errorMessage: string): string {
	const terminatorLength = output.endsWith("\r\n") ? 2 : output.endsWith("\n") ? 1 : 0;
	if (terminatorLength === 0) throw new WorkflowError(errorMessage);
	const value = output.slice(0, -terminatorLength);
	if (!value || /[\0\r\n]/.test(value)) throw new WorkflowError(errorMessage);
	return value;
}

async function resolveEffectiveHooksPath(cwd: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<string> {
	const configured = await runCommand(cwd, "git", ["config", "--null", "--path", "--get", "core.hooksPath"], signal, details);
	if (configured.exitCode === 0) {
		if (!configured.stdout.endsWith("\0") || configured.stdout.indexOf("\0") !== configured.stdout.length - 1) {
			throw new WorkflowError("Configured hooks path is invalid.");
		}
		const value = configured.stdout.slice(0, -1);
		if (value === "") throw new WorkflowError("Configured hooks path is invalid.");
		if (path.isAbsolute(value)) return value;
		const topLevel = await runCommand(cwd, "git", ["rev-parse", "--show-toplevel"], signal, details);
		if (topLevel.exitCode === 0) {
			return path.resolve(parseGitPathOutput(topLevel.stdout, "Configured hooks path is invalid."), value);
		}
		const gitDirectory = parseGitPathOutput(
			(await runGit(cwd, ["rev-parse", "--path-format=absolute", "--git-dir"], signal, details)).stdout,
			"Configured hooks path is invalid.",
		);
		return path.resolve(gitDirectory, value);
	}
	if (configured.exitCode !== 1) {
		details.failedToolCount += 1;
		throw new WorkflowError("Unable to resolve configured Git hooks.");
	}
	return parseGitPathOutput(
		(await runGit(cwd, ["rev-parse", "--path-format=absolute", "--git-path", "hooks"], signal, details)).stdout,
		"Unable to resolve Git hooks path.",
	);
}

async function preparePrivateHooks(transaction: CommitTransaction, scannedTree: string): Promise<void> {
	if (!isGitObjectId(scannedTree)) throw new WorkflowError("Unable to secure the scanned candidate tree.");
	await fs.promises.mkdir(transaction.hooksPath, { mode: 0o700 });
	await fs.promises.chmod(transaction.hooksPath, 0o700);
	let hookNames: string[];
	try {
		hookNames = await fs.promises.readdir(transaction.originalHooksPath);
	} catch (error) {
		if (isFileNotFound(error) || (isRecord(error) && error.code === "ENOTDIR")) hookNames = [];
		else throw new WorkflowError("Unable to prepare configured Git hooks.");
	}
	for (const hookName of hookNames) {
		if (hookName === "commit-msg" || hookName === "reference-transaction") continue;
		const originalHook = path.join(transaction.originalHooksPath, hookName);
		try {
			await fs.promises.access(originalHook, fs.constants.X_OK);
		} catch {
			continue;
		}
		const privateHook = path.join(transaction.hooksPath, hookName);
		await writePrivateFile(privateHook, ["#!/bin/sh", "exec " + shellQuote(originalHook) + ' "$@"', ""].join("\n"));
		await fs.promises.chmod(privateHook, 0o700);
	}
	const commitMessageHook = path.join(transaction.hooksPath, "commit-msg");
	await writePrivateFile(
		commitMessageHook,
		commitMessageHookScript(
			path.join(transaction.originalHooksPath, "commit-msg"),
			transaction.commitProcessPath,
			transaction.expectedRef,
			transaction.expectedBase,
			scannedTree,
		),
	);
	await fs.promises.chmod(commitMessageHook, 0o700);
	const referenceTransactionHook = path.join(transaction.hooksPath, "reference-transaction");
	await writePrivateFile(
		referenceTransactionHook,
		referenceTransactionHookScript(
			path.join(transaction.originalHooksPath, "reference-transaction"),
			transaction.commitProcessPath,
			transaction.expectedRef ?? "HEAD",
			transaction.expectedBase,
			scannedTree,
			transaction.referenceInputPath,
			transaction.receiptPath,
		),
	);
	await fs.promises.chmod(referenceTransactionHook, 0o700);
}


function commitMessageHookScript(
	originalHook: string,
	commitProcessPath: string,
	expectedRef: string | undefined,
	expectedBase: string | undefined,
	scannedTree: string,
): string {
	const refGuard = expectedRef
		? [
				'current_ref=$(git symbolic-ref -q HEAD 2>/dev/null)',
				'if [ $? -ne 0 ] || [ "$current_ref" != ' + shellQuote(expectedRef) + " ]; then",
			]
		: [
				"git symbolic-ref -q HEAD >/dev/null 2>&1",
				"if [ $? -ne 1 ]; then",
			];
	const baseGuard = expectedBase
		? [
				'current_base=$(git rev-parse --verify --quiet HEAD^{commit} 2>/dev/null)',
				'if [ $? -ne 0 ] || [ "$current_base" != ' + shellQuote(expectedBase) + " ]; then",
			]
		: [
				"git rev-parse --verify --quiet HEAD^{commit} >/dev/null 2>&1",
				"if [ $? -ne 1 ]; then",
			];
	return [
		"#!/bin/sh",
		"umask 077",
		"commit_process_path=" + shellQuote(commitProcessPath),
		'case "$PPID" in ""|*[!0-9]*) exit 1 ;; esac',
		'commit_process_tmp="$commit_process_path.tmp.$$"',
		'if ! printf "%s\\n" "$PPID" > "$commit_process_tmp" || ! chmod 600 "$commit_process_tmp" || ! mv -f "$commit_process_tmp" "$commit_process_path"; then',
		'\trm -f "$commit_process_tmp"',
		"\texit 1",
		"fi",
		"original_hook=" + shellQuote(originalHook),
		'if [ -x "$original_hook" ]; then',
		'\t"$original_hook" "$@"',
		"\thook_status=$?",
		'\tif [ "$hook_status" -ne 0 ]; then exit "$hook_status"; fi',
		"fi",
		...refGuard,
		"\tprintf '%s\\n' 'Commit blocked because the repository reference changed after scanning.' >&2",
		"\texit 1",
		"fi",
		...baseGuard,
		"\tprintf '%s\\n' 'Commit blocked because the repository base changed after scanning.' >&2",
		"\texit 1",
		"fi",
		'current_tree=$(git write-tree 2>/dev/null)',
		'if [ $? -ne 0 ] || [ "$current_tree" != ' + shellQuote(scannedTree) + " ]; then",
		"\tprintf '%s\\n' 'Commit blocked because a hook changed the scanned candidate.' >&2",
		"\texit 1",
		"fi",
		"",
	].join("\n");
}

function referenceTransactionHookScript(
	originalHook: string,
	commitProcessPath: string,
	expectedTarget: string,
	expectedBase: string | undefined,
	scannedTree: string,
	inputPath: string,
	receiptPath: string,
): string {
	const oldGuard = expectedBase
		? ['[ "$old_oid" = ' + shellQuote(expectedBase) + " ] || valid_update=false"]
		: [
				'case "$old_oid" in',
				'\t*[!0]*) valid_update=false ;;',
				"esac",
				'[ "${#old_oid}" -eq "${#new_oid}" ] || valid_update=false',
			];
	const parentGuard = expectedBase
		? ['[ "$commit_line" = "$new_oid ' + expectedBase + '" ] || valid_commit=false']
		: ['[ "$commit_line" = "$new_oid" ] || valid_commit=false'];
	return [
		"#!/bin/sh",
		"umask 077",
		"original_hook=" + shellQuote(originalHook),
		"commit_process_path=" + shellQuote(commitProcessPath),
		"input_path=" + shellQuote(inputPath),
		"receipt_path=" + shellQuote(receiptPath),
		"phase=${1-}",
		'if ! cat > "$input_path"; then exit 1; fi',
		'chmod 600 "$input_path" || exit 1',
		"line_count=0",
		"contains_target=false",
		'while IFS= read -r input_line || [ -n "$input_line" ]; do',
		"\tline_count=$((line_count + 1))",
		"\tinput_ref=${input_line##* }",
		'\tif [ "$input_ref" = ' + shellQuote(expectedTarget) + " ]; then contains_target=true; fi",
		'done < "$input_path"',
		"old_oid= new_oid= updated_ref= extra=",
		'if [ "$line_count" -eq 1 ]; then',
		'\tIFS=" " read -r old_oid new_oid updated_ref extra < "$input_path"',
		"fi",
		"target_update=true",
		'[ "$line_count" -eq 1 ] || target_update=false',
		'[ -z "$extra" ] || target_update=false',
		'[ "$updated_ref" = ' + shellQuote(expectedTarget) + " ] || target_update=false",
		"valid_update=$target_update",
		'case "$new_oid" in',
		'\t""|*[!0-9a-f]*) valid_update=false ;;',
		"esac",
		'case "${#new_oid}" in',
		"\t40|64) ;;",
		"\t*) valid_update=false ;;",
		"esac",
		...oldGuard,
		'run_original () {',
		'\tif [ -x "$original_hook" ]; then',
		'\t\t"$original_hook" "$@" < "$input_path"',
		"\t\treturn $?",
		"\tfi",
		"\treturn 0",
		"}",
		'commit_process=$(cat "$commit_process_path" 2>/dev/null)',
		'if [ "$commit_process" != "$PPID" ]; then',
		'\trun_original "$@"',
		"\texit $?",
		"fi",
		'if [ "$phase" = prepared ]; then',
		'\trun_original "$@"',
		"\thook_status=$?",
		'\tif [ "$hook_status" -ne 0 ]; then exit "$hook_status"; fi',
		'\tif [ "$target_update" != true ] && [ "$contains_target" != true ]; then exit 0; fi',
		'\tif [ "$valid_update" != true ]; then',
		"\t\tprintf '%s\\n' 'Commit blocked because the reference transaction base did not match the scanned candidate.' >&2",
		"\t\texit 1",
		"\tfi",
		"\tvalid_commit=true",
		'\tcurrent_tree=$(git --no-replace-objects rev-parse --verify "$new_oid^{tree}" 2>/dev/null) || valid_commit=false',
		'\t[ "$current_tree" = ' + shellQuote(scannedTree) + " ] || valid_commit=false",
		'\tcommit_line=$(git --no-replace-objects rev-list --parents -n 1 "$new_oid" 2>/dev/null) || valid_commit=false',
		...parentGuard.map(line => `\t${line}`),
		'\tif [ "$valid_commit" != true ]; then',
		"\t\tprintf '%s\\n' 'Commit blocked because the reference transaction did not match the scanned candidate.' >&2",
		"\t\texit 1",
		"\tfi",
		'\treceipt_tmp="$receipt_path.tmp.$$"',
		'\tif ! printf "prepared:%s\\n" "$new_oid" > "$receipt_tmp" || ! chmod 600 "$receipt_tmp" || ! mv -f "$receipt_tmp" "$receipt_path"; then',
		'\t\trm -f "$receipt_tmp"',
		"\t\texit 1",
		"\tfi",
		"\texit 0",
		"fi",
		'if [ "$phase" = committed ] && [ "$target_update" = true ]; then',
		'\tprepared=$(cat "$receipt_path" 2>/dev/null)',
		'\tif [ "$valid_update" != true ] || [ "$prepared" != "prepared:$new_oid" ]; then exit 1; fi',
		'\treceipt_tmp="$receipt_path.tmp.$$"',
		'\tif ! printf "committed:%s\\n" "$new_oid" > "$receipt_tmp" || ! chmod 600 "$receipt_tmp" || ! mv -f "$receipt_tmp" "$receipt_path"; then',
		'\t\trm -f "$receipt_tmp"',
		"\t\texit 1",
		"\tfi",
		'\trun_original "$@"',
		"\texit $?",
		"fi",
		'if [ "$phase" = aborted ] && [ "$target_update" = true ]; then',
		'\tprepared=$(cat "$receipt_path" 2>/dev/null)',
		'\tif [ "$valid_update" = true ] && [ "$prepared" = "prepared:$new_oid" ]; then rm -f "$receipt_path"; fi',
		'\trun_original "$@"',
		"\texit $?",
		"fi",
		'run_original "$@"',
		"exit $?",
		"",
	].join("\n");
}
function shellQuote(value: string): string {
	return `'${value.replaceAll("'", "'\"'\"'")}'`;
}

async function reconcileCommittedPaths(
	cwd: string,
	transaction: CommitTransaction,
	commitFiles: string[],
	createdOid: string,
	details: CommitRunDetails,
): Promise<boolean> {
	const lockPath = `${transaction.realIndexPath}.lock`;
	const nestedLockPath = `${lockPath}.lock`;
	let lock: fs.promises.FileHandle | undefined;
	let lockPresent = false;
	try {
		try {
			lock = await fs.promises.open(lockPath, "wx", 0o600);
			lockPresent = true;
		} catch (error) {
			if (isRecord(error) && error.code === "EEXIST") return false;
			throw error;
		}
		if (await indexFingerprint(cwd, transaction.realIndexPath, details) !== transaction.realIndexFingerprint) return false;
		if (transaction.realIndexFingerprint === "missing") {
			await lock.close();
			lock = undefined;
			await runGit(cwd, ["read-tree", createdOid], undefined, details, { GIT_INDEX_FILE: lockPath });
		} else {
			await lock.writeFile(await fs.promises.readFile(transaction.realIndexPath));
			await lock.sync();
			await lock.close();
			lock = undefined;
		}
		await runGit(cwd, ["update-index", "--no-split-index"], undefined, details, { GIT_INDEX_FILE: lockPath });
		await runGit(
			cwd,
			["restore", "--staged", `--source=${createdOid}`, "--", ...commitFiles],
			undefined,
			details,
			{ GIT_INDEX_FILE: lockPath, GIT_LITERAL_PATHSPECS: "1" },
		);
		await ensurePrivateRegularFile(lockPath, 0o600);
		const completedLock = await fs.promises.open(lockPath, "r+");
		try {
			await completedLock.sync();
		} finally {
			await completedLock.close();
		}
		await fs.promises.rename(lockPath, transaction.realIndexPath);
		lockPresent = false;
		return true;
	} finally {
		try {
			if (lock) await lock.close();
		} finally {
			await fs.promises.rm(nestedLockPath, { force: true });
			if (lockPresent) await fs.promises.rm(lockPath, { force: true });
		}
	}
}


async function indexFingerprint(cwd: string, indexPath: string, details: CommitRunDetails): Promise<string> {
	try {
		const metadata = await fs.promises.lstat(indexPath);
		if (!metadata.isFile()) throw new WorkflowError("Git index is not a regular file.");
	} catch (error) {
		if (isFileNotFound(error)) return "missing";
		throw error;
	}
	const objectId = (await runGit(cwd, ["hash-object", "--no-filters", "--", indexPath], undefined, details)).stdout.trim();
	if (!isGitObjectId(objectId)) throw new WorkflowError("Unable to fingerprint the Git index.");
	return `present:${objectId}`;
}

function candidateIndexEnvironment(transaction: CommitTransaction): Record<string, string | undefined> {
	return { GIT_INDEX_FILE: transaction.candidateIndexPath };
}

function candidatePathEnvironment(transaction: CommitTransaction): Record<string, string | undefined> {
	return { GIT_INDEX_FILE: transaction.candidateIndexPath, GIT_LITERAL_PATHSPECS: "1" };
}


async function writePrivateFile(file: string, contents: string): Promise<void> {
	const handle = await fs.promises.open(file, "wx", 0o600);
	try {
		await handle.writeFile(contents);
		await handle.sync();
	} finally {
		await handle.close();
	}
	await fs.promises.chmod(file, 0o600);
}

async function ensurePrivateRegularFile(file: string, mode: number): Promise<void> {
	const metadata = await fs.promises.lstat(file);
	if (!metadata.isFile()) throw new WorkflowError("Private commit data was not a regular file.");
	await fs.promises.chmod(file, mode);
}


function isFileNotFound(error: unknown): boolean {
	return isRecord(error) && error.code === "ENOENT";
}

function isGitObjectId(value: string): boolean {
	return /^[0-9a-f]{40,128}$/i.test(value);
}

async function runGit(
	cwd: string,
	args: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
	environment?: Record<string, string | undefined>,
): Promise<CommandResult> {
	const result = await runCommand(cwd, "git", args, signal, details, environment);
	if (result.exitCode !== 0) {
		details.failedToolCount += 1;
		throw new CommandError(`git ${args[0] ?? ""} failed: ${trimOutput(result.stderr || result.stdout)}`, result);
	}
	return result;
}

async function runCommand(
	cwd: string,
	command: string,
	args: string[],
	signal: AbortSignal | undefined,
	details: CommitRunDetails,
	environment?: Record<string, string | undefined>,
	stdoutFile?: fs.promises.FileHandle,
	stdinFile?: fs.promises.FileHandle,
): Promise<CommandResult> {
	throwIfAborted(signal);
	details.toolCount += 1;
	const env = environment ? { ...Bun.env, ...environment } : undefined;
	if (env) {
		for (const [name, value] of Object.entries(env)) {
			if (value === undefined) delete env[name];
		}
	}
	const child = Bun.spawn({
		cmd: [command, ...args],
		cwd,
		env,
		stdin: stdinFile ? stdinFile.fd : "ignore",
		stdout: stdoutFile ? stdoutFile.fd : "pipe",
		stderr: "pipe",
		detached: true,
	});
	let abortTimer: Parameters<typeof clearTimeout>[0] | undefined;
	let rejectAbort: ((error: Error) => void) | undefined;
	let abortRequested = false;
	const abortCompletion = new Promise<never>((_resolve, reject) => {
		rejectAbort = reject;
	});
	const abortChild = () => {
		if (abortRequested) return;
		abortRequested = true;
		signalCommandGroup(child, "SIGTERM");
		abortTimer = setTimeout(() => {
			signalCommandGroup(child, "SIGKILL");
			rejectAbort?.(new WorkflowError("Commit workflow cancelled."));
		}, 1_000);
	};
	signal?.addEventListener("abort", abortChild, { once: true });
	if (signal?.aborted) abortChild();
	try {
		const stdout = stdoutFile ? Promise.resolve("") : readStream(child.stdout);
		const [stdoutText, stderr, exitCode] = await Promise.race([
			Promise.all([stdout, readStream(child.stderr), child.exited]) as Promise<[string, string, number]>,
			abortCompletion,
		]);
		throwIfAborted(signal);
		return { stdout: stdoutText, stderr, exitCode };
	} finally {
		clearTimeout(abortTimer);
		signal?.removeEventListener("abort", abortChild);
	}
}
function signalCommandGroup(
	child: { pid: number; kill(signal?: "SIGTERM" | "SIGKILL"): void },
	signal: "SIGTERM" | "SIGKILL",
): void {
	try {
		process.kill(-child.pid, signal);
	} catch {
		child.kill(signal);
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
		commitMessage: "fix(omp): Tune OMP advisor model defaults\n\nExplain the behavior change and any operator impact.",
		rationale: "why this commit matches the current conversation",
		dryRun: parsed.dryRun || undefined,
		push: parsed.push || undefined,
		context: parsed.context || undefined,
	};
	const splitExample = {
		commits: [{
			files: ["exact repo-relative file or directory for this split"],
			commitMessage: "docs(omp): Clarify commit workflow rules",
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
		"- Commit message subjects must use `type(scope): summary`; preferred types are fix, feat, refactor, docs, test, chore, and ci.",
		"- Keep the subject line at 50 characters or fewer.",
		"- If a body is needed, line 2 must be blank; keep every non-blank body line at 72 characters or fewer.",
		"- Preserve the exact valid message wording and paragraphs that belong in git history.",
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
	appendLiveActivity(lines, model, theme, spinnerFrame, renderWidth);
	appendChips(lines, model.chips, theme, renderWidth);
	appendRail(lines, model.rail, theme, spinnerFrame, renderWidth);
	appendCommitRows(lines, model, expanded, theme, spinnerFrame, renderWidth);
	if (expanded && model.context) appendCardField(lines, theme, renderWidth, "Context", model.context, MAX_EXPANDED_CARD_FIELD_LINES, "muted");
	appendListField(lines, theme, renderWidth, "Warnings", model.warnings, expanded ? 6 : 2, "warning");
	appendLeftOutField(lines, theme, renderWidth, model.ignoredFiles, expanded);
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

function appendLiveActivity(lines: string[], model: DashboardModel, theme: unknown, spinnerFrame: number | undefined, width: number): void {
	if (!isLiveRunStatus(model.status)) return;
	const pulse = paint(theme, pulseColor(spinnerFrame), "✦");
	const spinner = paint(theme, statusColor(model.status), spinnerGlyph(spinnerFrame));
	appendCardWrappedText(lines, theme, width, `${paint(theme, "dim", "Working")}: ${pulse} ${spinner} `, "  ", liveActivityText(model), "accent", 1);
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

function appendLeftOutField(lines: string[], theme: unknown, width: number, values: string[], expanded: boolean): void {
	if (values.length === 0) return;
	appendCardField(lines, theme, width, "Left out", formatCountedList(values, expanded ? MAX_RESULT_FILES : 1, "file"), expanded ? 4 : 1, "muted");
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
		detailsFileChip(details),
		details.push ? details.pushSucceeded ? "pushed" : details.pushSucceeded === false ? "push warning" : "push after" : undefined,
		details.warnings.length > 0 ? `${details.warnings.length} ${plural("warning", details.warnings.length)}` : undefined,
	].filter(isString);
}

function detailsFileChip(details: CommitRunDetails): string {
	if (details.selectedFiles.length > 0) return `${details.selectedFiles.length} ${plural("file", details.selectedFiles.length)}`;
	if (isLiveRunStatus(details.status)) {
		const requested = new Set(details.commits.flatMap(commit => commit.requestedFiles)).size;
		return requested > 0 ? `checking ${requested} requested ${plural("file", requested)}` : "scanning files";
	}
	return `${details.selectedFiles.length} ${plural("file", details.selectedFiles.length)}`;
}

function defaultRail(includePush: boolean): CommitStep[] {
	const steps: CommitStep[] = [
		{ key: "plan", label: "Plan", status: "pending" },
		{ key: "tree", label: "Tree", status: "pending" },
		{ key: "stage", label: "Stage", status: "pending" },
		{ key: "scan", label: "Scan", status: "pending" },
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
	return frame ?? Math.floor(Date.now() / COMMIT_WIDGET_FRAME_MS);
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

function isLiveRunStatus(status: RunStatus): boolean {
	return status === "running" || status === "pending";
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
	const selectedFiles = dashboardSelectedFileCount(model);
	if (selectedFiles > 0) return selectedFiles;
	return dashboardRequestedFileCount(model);
}

function dashboardSelectedFileCount(model: DashboardModel): number {
	const files = model.commits.flatMap(commit => commit.files);
	return new Set(files).size;
}

function dashboardRequestedFileCount(model: DashboardModel): number {
	const files = model.commits.flatMap(commit => commit.requestedFiles);
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
	const files = ` · ${commitFileSummary(model, commit)}`;
	const subject = `${hash}${commit.subject}`;
	if (commit.status === "running") {
		const phase = commit.phase && commit.phase !== "Ready" ? `${commit.phase} · ` : "";
		return `${label} · ${phase}${subject}${files}`;
	}
	if (commit.status === "failed") return `${label} · blocked · ${subject}${files}`;
	if (commit.status === "pending") return `${label} · queued · ${subject}${files}`;
	return `${label} · ${subject}${files}`;
}

function commitFileSummary(model: DashboardModel, commit: DashboardCommit): string {
	if (commit.files.length > 0) return formatFileCount(commit.files.length);
	if (isLiveRunStatus(model.status) && (commit.status === "pending" || commit.status === "running")) {
		return commit.requestedFiles.length > 0 ? `checking ${commit.requestedFiles.length} requested ${plural("file", commit.requestedFiles.length)}` : "scanning files";
	}
	if (commit.requestedFiles.length > 0) return `${formatFileCount(commit.requestedFiles.length)} requested`;
	return "all changes";
}

function liveActivityText(model: DashboardModel): string {
	const phase = model.phase || (model.status === "pending" ? "Queued" : "Working");
	return [phase, liveFileSignal(model)].filter(isString).join(" · ");
}

function liveFileSignal(model: DashboardModel): string {
	const selected = dashboardSelectedFileCount(model);
	if (selected > 0) return `${formatFileCount(selected)} selected`;
	const requested = dashboardRequestedFileCount(model);
	if (requested > 0) return `checking ${requested} requested ${plural("file", requested)}`;
	return "scanning files";
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

function formatCountedList(values: string[], limit: number, itemName = "item"): string {
	const count = `${values.length} ${plural(itemName, values.length)}`;
	const visible = values.slice(0, Math.max(0, limit)).map(redactSuspiciousTokens);
	const remaining = values.length - visible.length;
	if (visible.length === 0) return count;
	return `${count} · ${visible.join(", ")}${remaining > 0 ? `, +${remaining} more` : ""}`;
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
	return text.replace(/(?:gh[pousr]_|github_pat_|glpat-|xox[baprs]-|sk-(?:proj-)?)\S{8,}/g, "<redacted>");
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
	const earlyBreakLimit = Math.min(12, Math.floor(limit * 0.35));
	return lastSpace > earlyBreakLimit ? lastSpace : limit;
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
