import type { Component } from "@oh-my-pi/pi-tui";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const TOOL_NAME = "omp_commit";
const MIN_RENDER_WIDTH = 20;
const MIN_WRAP_CONTENT_WIDTH = 12;
const MAX_WRAPPED_FIELD_LINES = 3;
const MAX_EXPANDED_WRAPPED_FIELD_LINES = 8;
const MAX_VISIBLE_STEPS = 7;
const MAX_FINAL_LINES = 8;
const MAX_OUTPUT_CHARS = 2_000;
const MAX_SECRET_SCAN_CHARS = 2_000_000;
const MAX_COMMIT_SUBJECT_CHARS = 50;
const MAX_COMMIT_BODY_LINE_CHARS = 72;

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const PULSE_FRAMES = ["●···", "·●··", "··●·", "···●"];
const CONVENTIONAL_COMMIT_RE = /^[a-z]+(?:\([a-z0-9-]+\))?!?: .+/;
const MUTATING_GIT_VERBS = new Set(["add", "am", "apply", "checkout", "cherry-pick", "clean", "commit", "merge", "mv", "pull", "push", "rebase", "reset", "restore", "revert", "rm", "stash", "switch"]);

const COMMIT_MESSAGE_ONLY_RE = /\b(?:commit message|message for (?:this )?commit|draft (?:a )?commit|suggest (?:a )?commit|write (?:a )?commit message)\b/i;
const COMMIT_NEGATION_RE = /\b(?:do\s+not|don't|dont)\s+commit\b|\bwithout\s+committing\b|\bnot\s+commit(?:ting)?\b/i;
const SHOULD_COMMIT_RE = /\bshould\s+i\s+commit\b/i;
const NATURAL_COMMIT_PATTERNS = [
	/^\s*(?:(?:please|go ahead and|let(?:'s| us)(?: go ahead and)?)\s+)?commit(?:\b|[\s:])/i,
	/^\s*(?:(?:please|go ahead and)\s+)?(?:make|create|cut)\s+(?:a\s+|the\s+|another\s+)?commit\b/i,
	/\b(?:can|could|would|will)\s+you\s+(?:please\s+)?(?:commit|(?:make|create|cut)\s+(?:a\s+)?commit)\b/i,
	/^\s*(?:please\s+)?(?:wrap|finish)\b.{0,80}\bwith\s+(?:a\s+)?commit\b/i,
	/^\s*(?:please\s+)?(?:run|use)\s+\/commit\b/i,
];
const NATURAL_PUSH_RE = /--push\b|\bcommit\b.{0,40}\band\s+push\b|\band\s+push\b|\bpush\s+(?:it|this|the\s+branch|after(?:wards)?|too|as\s+well)\b/i;
const NATURAL_NO_PUSH_RE = /--no-push\b|\b(?:do\s+not|don't|dont|no)\s+push\b|\bwithout\s+pushing\b/i;
const NATURAL_DRY_RUN_RE = /--dry-run\b|\bdry[-\s]?run\b|\bpreview\b/i;
const NATURAL_ACCEPT_RISK_RE = /--accept-risk\b|\baccept(?:ing)?\s+risk\b/i;
const NATURAL_ATOMIC_RE = /--atomic\b|\batomic\s+commits?\b|\bmultiple\s+commits?\b|\bsplit\b.{0,40}\bcommits?\b|\bseparate\s+commits?\b/i;

interface SecretPattern {
	name: string;
	pattern: RegExp;
}

interface SecretScanEntry {
	file: string;
	line: number;
	text: string;
}

const SECRET_PATTERNS: SecretPattern[] = [
	{ name: "private key", pattern: /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/ },
	{ name: "AWS access key", pattern: /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/ },
	{ name: "GitHub token", pattern: /\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/ },
	{ name: "Slack token", pattern: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/ },
	{ name: "generic secret assignment", pattern: /(?:password|passwd|pwd|secret|api[_-]?key|access[_-]?key|token)\s*[:=]\s*["']?[^"'\s]{12,}/i },
];

type RunStatus = "running" | "succeeded" | "failed";
type StepStatus = "running" | "done" | "failed";
type CommitUiStatus = "pending" | "running" | "succeeded" | "failed";

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

interface VerificationEvidence {
	description: string;
	command?: string;
	args?: string[];
	source?: string;
}

interface CommitToolCommitParams {
	files?: string[];
	commitMessage?: string;
	rationale?: string;
	verification?: VerificationPlan[];
	verificationEvidence?: VerificationEvidence[];
	acceptRisk?: boolean;
}

interface CommitToolParams extends CommitToolCommitParams {
	commits?: CommitToolCommitParams[];
	context?: string;
	dryRun?: boolean;
	push?: boolean;
	multiCommit?: boolean;
}

interface CommitSpec {
	files: string[];
	commitMessage: string;
	rationale: string;
	verification: VerificationPlan[];
	verificationEvidence: VerificationEvidence[];
	acceptRisk: boolean;
}

interface CommitPlan {
	commits: CommitSpec[];
	context: string;
	dryRun: boolean;
	push: boolean;
	acceptRisk: boolean;
	multiCommit: boolean;
}

interface ParsedArgs {
	dryRun: boolean;
	push: boolean;
	acceptRisk: boolean;
	multiCommit: boolean;
	context: string;
	model?: string;
}
type CommitRequestSource = "slash-command" | "natural-language";

interface GitStatusEntry {
	code: string;
	path: string;
}

interface CommandResult {
	stdout: string;
	stderr: string;
	exitCode: number;
}

interface CommitResultDetails {
	commitMessage?: string;
	rationale?: string;
	selectedFiles: string[];
	verificationCount: number;
	verificationEvidence: string[];
	acceptRisk: boolean;
	commitHash?: string;
	status?: CommitUiStatus;
	phase?: string;
	errorText?: string;
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
	multiCommit: boolean;
	context?: string;
	rationale?: string;
	commitMessage?: string;
	selectedFiles: string[];
	ignoredFiles: string[];
	verificationCount: number;
	verificationEvidence: string[];
	commitHash?: string;
	commits: CommitResultDetails[];
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
	const verificationParam = z.object({
		command: z.string().describe("Verification executable, without shell wrapping."),
		args: z.array(z.string()).optional().describe("Executable arguments."),
		description: z.string().optional().describe("Short human label for the verification."),
		required: z.boolean().optional().describe("Reserved for display; failing verification still blocks."),
	});
	const verificationEvidenceParam = z.object({
		description: z.string().describe("Concrete verification already observed in the conversation or explicitly reported by the user."),
		command: z.string().optional().describe("Executable that produced the evidence, when known."),
		args: z.array(z.string()).optional().describe("Arguments for the evidence command, when known."),
		source: z.string().optional().describe("Either observed or user-reported."),
	});
	const commitParam = z.object({
		files: z.array(z.string()).optional().describe("Repo-relative files or directories to include for this commit."),
		commitMessage: z.string().optional().describe("Full conventional commit message. First line is the subject; optional body paragraphs follow after one blank line."),
		rationale: z.string().optional().describe("Why these files and this message belong together."),
		verification: z.array(verificationParam).optional().describe("Narrow verification commands for this commit."),
		verificationEvidence: z.array(verificationEvidenceParam).optional().describe("Prior verification evidence for this commit."),
		acceptRisk: z.boolean().optional().describe("Allow this commit without verification only when the user explicitly accepted the risk."),
	});


	pi.registerTool({
		name: TOOL_NAME,
		label: "Commit",
		description: "Execute a reviewed commit plan in-process with one live progress card and hidden git operations.",
		defaultInactive: true,
		parameters: z.object({
			files: z.array(z.string()).optional().describe("Repo-relative files or directories to include. Leave empty only to block safely when the current context is insufficient."),
			commitMessage: z.string().optional().describe("Full conventional commit message. First line is the subject; optional body paragraphs follow after one blank line."),
			rationale: z.string().optional().describe("Why these files and this message match the current conversation context."),
			verification: z.array(verificationParam).optional().describe("Narrow verification commands to run before staging/committing."),
			verificationEvidence: z.array(verificationEvidenceParam).optional().describe("Prior verification evidence to record without rerunning heavy checks. Do not invent evidence."),
			commits: z.array(commitParam).optional().describe("Split commit plans. Omit for single commits; never pass an empty array."),
			context: z.string().optional().describe("Additional slash-command context."),
			dryRun: z.boolean().optional().describe("Validate and preview without staging, committing, or pushing."),
			push: z.boolean().optional().describe("Push after all requested commits succeed."),
			multiCommit: z.boolean().optional().describe("Render and execute this request as a sequential commit group."),
			acceptRisk: z.boolean().optional().describe("Allow committing without verification only when the user explicitly accepted the risk."),
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

	const startCommitWorkflow = async (parsed: ParsedArgs, source: CommitRequestSource) => {
		restoreActiveTools = pi.getActiveTools();
		await pi.setActiveTools([TOOL_NAME]);
		pi.sendMessage(
			{
				customType: "commit-request",
				content: await buildToolInvocationPrompt(parsed, source),
				display: false,
				details: parsed,
				attribution: "user",
			},
			{ triggerTurn: true, deliverAs: "nextTurn" },
		);
	};

	pi.on("input", async (event, ctx) => {
		const parsed = parseNaturalCommitRequest(event.text, event.images, event.source);
		if (!parsed) return undefined;
		if (restoreActiveTools) {
			ctx.ui.notify("A commit workflow is already running.", "warning");
			return { handled: true };
		}
		if (!ctx.isIdle()) {
			ctx.ui.notify("Commit requests are auto-routed only while idle; run /commit after the current turn finishes.", "warning");
			return { handled: true };
		}

		await startCommitWorkflow(parsed, "natural-language");
		return { handled: true };
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

			await startCommitWorkflow(parsed, "slash-command");
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
		const renderWidth = Math.max(MIN_RENDER_WIDTH, width);
		const commitCount = this.plan.commits.length;
		const fileCount = new Set(this.plan.commits.flatMap(commit => commit.files)).size;
		const title = this.plan.dryRun ? "Commit preview" : commitCount > 1 ? "Commit group" : "Commit";
		const lines = [`${this.theme.fg("accent", "●")} ${this.theme.fg("accent", this.theme.bold(title))}`];
		const flags = [
			this.plan.push ? "push" : undefined,
			this.plan.multiCommit || commitCount > 1 ? `${commitCount} split commit${commitCount === 1 ? "" : "s"}` : undefined,
			this.plan.acceptRisk ? "risk accepted" : undefined,
			fileCount > 0 ? `${fileCount} file${fileCount === 1 ? "" : "s"}` : "no files selected",
		].filter(Boolean);
		lines.push(` ${this.theme.fg("dim", this.theme.tree.branch)} ${this.theme.fg("dim", flags.join(" · "))}`);
		const subjects = this.plan.commits.map(commit => commit.commitMessage.split("\n", 1)[0]).filter(Boolean);
		if (subjects.length > 0) {
			const message = commitCount > 1 ? `${commitCount} commits: ${subjects.slice(0, 3).join("; ")}${subjects.length > 3 ? "; …" : ""}` : subjects[0];
			appendWrappedText(lines, ` ${this.theme.fg("dim", this.theme.tree.branch)} `, ` ${this.theme.fg("dim", this.theme.tree.vertical)}  `, message, this.theme, "muted", renderWidth, MAX_WRAPPED_FIELD_LINES);
		}
		const rationale = this.plan.context || this.plan.commits.find(commit => commit.rationale)?.rationale;
		if (rationale) {
			appendWrappedField(lines, this.theme, renderWidth, this.theme.tree.last, " ", this.plan.context ? "Context" : "Rationale", rationale, MAX_WRAPPED_FIELD_LINES);
		}
		return lines.map(line => truncateVisible(line, renderWidth));
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
		const renderWidth = Math.max(MIN_RENDER_WIDTH, width);
		const lines = renderCommitRun(this.details, this.expanded, this.theme, this.spinnerFrame, renderWidth);
		return lines.map(line => truncateVisible(line, renderWidth));
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
	await withStep(details, "Validating commit plan", onUpdate, async () => {
		repairCommitMessages(plan, details);
		validateCommitPlan(plan);
	});

	const repoRoot = await withStep(details, "Inspecting working tree", onUpdate, async () => {
		const root = (await runGit(cwd, ["rev-parse", "--show-toplevel"], signal, details)).stdout.trim();
		const status = parseStatusZ((await runGit(cwd, ["status", "--porcelain=v1", "-z", "--untracked-files=all"], signal, details)).stdout);
		if (status.length === 0) throw new WorkflowError("No working tree changes to commit.");

		const statusPaths = status.map(entry => entry.path);
		const selectedByFile = new Map<string, number>();
		for (const [index, commit] of plan.commits.entries()) {
			const label = formatCommitLabel(index, plan.commits.length);
			const { selected, unmatched } = resolveSelectedFiles(commit.files, status);
			if (commit.files.length === 0) {
				throw new WorkflowError(`${label}: no files were selected from the current conversation context. Changed files: ${statusPaths.join(", ")}`);
			}
			if (unmatched.length > 0) {
				throw new WorkflowError(`${label}: requested files are not changed: ${unmatched.join(", ")}`);
			}
			if (selected.length === 0) {
				throw new WorkflowError(`${label}: selected files do not match any working tree changes.`);
			}
			details.commits[index].selectedFiles = selected;
			for (const file of selected) {
				const previousIndex = selectedByFile.get(file);
				if (previousIndex !== undefined) {
					throw new WorkflowError(`${file} is selected by multiple commits: ${formatCommitLabel(previousIndex, plan.commits.length)} and ${label}.`);
				}
				selectedByFile.set(file, index);
			}
		}

		details.selectedFiles = details.commits.flatMap(commit => commit.selectedFiles);
		details.ignoredFiles = statusPaths.filter(path => !selectedByFile.has(path));

		const staged = parseZPaths((await runGit(cwd, ["diff", "--cached", "--name-only", "-z"], signal, details)).stdout);
		const unrelatedStaged = staged.filter(path => !selectedByFile.has(path));
		if (unrelatedStaged.length > 0) {
			throw new WorkflowError(`Unrelated staged changes would be at risk: ${unrelatedStaged.join(", ")}. Unstage or include them explicitly.`);
		}
		return root;
	});

	const scanEntries = await withStep(details, "Reviewing selected diff", onUpdate, () => collectSecretScanEntries(cwd, repoRoot, details.selectedFiles, signal, details));
	await withStep(details, "Checking for secrets", onUpdate, async () => scanForSecrets(scanEntries));
	await withStep(details, "Running verification", onUpdate, async () => runVerification(plan, cwd, signal, details));

	if (plan.dryRun) {
		details.status = "succeeded";
		details.phase = "Commit preview complete";
		details.finalText = buildDryRunText(details);
		details.finishedAt = Date.now();
		onUpdate();
		return;
	}

	for (const [index, commit] of plan.commits.entries()) {
		const label = formatCommitLabel(index, plan.commits.length);
		const result = details.commits[index];
		try {
			setCommitState(result, "running", "Staging selected changes");
			onUpdate();
			await withStep(details, `${label}: staging selected changes`, onUpdate, () => runGit(cwd, ["add", "--", ...result.selectedFiles], signal, details));
			setCommitState(result, "running", "Creating commit");
			onUpdate();
			await withStep(details, `${label}: creating commit`, onUpdate, () => runGit(cwd, ["commit", "--only", ...commitMessageArgs(commit.commitMessage), "--", ...result.selectedFiles], signal, details));
			setCommitState(result, "running", "Checking commit result");
			onUpdate();
			const commitHash = (await withStep(details, `${label}: checking commit result`, onUpdate, () => runGit(cwd, ["rev-parse", "--short", "HEAD"], signal, details))).stdout.trim();
			result.commitHash = commitHash;
			details.commitHash = commitHash;
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
		await withStep(details, "Pushing branch", onUpdate, () => runGit(cwd, ["push"], signal, details));
	}

	details.status = "succeeded";
	const commitNoun = plan.commits.length === 1 ? "Commit" : `${plan.commits.length} commits`;
	details.phase = plan.push ? `${commitNoun} created and pushed` : `${commitNoun} created`;
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

function setCommitState(commit: CommitResultDetails, status: CommitUiStatus, phase: string, errorText?: string): void {
	commit.status = status;
	commit.phase = phase;
	if (errorText) commit.errorText = errorText;
	else if (status !== "failed") delete commit.errorText;
}

function normalizeCommitPlan(params: CommitToolParams): CommitPlan {
	const explicitCommits = Array.isArray(params.commits) ? params.commits : [];
	const explicitNonEmptyCommits = explicitCommits.filter(hasCommitSpecContent);
	const useExplicitCommits =
		Boolean(params.multiCommit) ||
		explicitNonEmptyCommits.length > 0 ||
		(explicitCommits.length > 0 && !hasCommitSpecContent(params));
	const sourceCommits = useExplicitCommits
		? (explicitNonEmptyCommits.length > 0 ? explicitNonEmptyCommits : explicitCommits)
		: [params];
	const inheritedAcceptRisk = Boolean(params.acceptRisk);
	const commits = sourceCommits.map(commit => normalizeCommitSpec(commit, inheritedAcceptRisk));
	return {
		commits,
		context: params.context?.trim() ?? "",
		dryRun: Boolean(params.dryRun),
		push: Boolean(params.push),
		acceptRisk: commits.some(commit => commit.acceptRisk),
		multiCommit: Boolean(params.multiCommit) || commits.length > 1,
	};
}

function hasCommitSpecContent(params: CommitToolCommitParams): boolean {
	return Boolean(
		(params.files ?? []).some(file => file.trim()) ||
			params.commitMessage?.trim() ||
			params.rationale?.trim() ||
			(params.verification ?? []).length > 0 ||
			(params.verificationEvidence ?? []).length > 0,
	);
}

function normalizeCommitSpec(params: CommitToolCommitParams, inheritedAcceptRisk: boolean): CommitSpec {
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
		verificationEvidence: (params.verificationEvidence ?? []).map(item => ({
			description: item.description?.trim() ?? "",
			command: item.command?.trim() || undefined,
			args: Array.isArray(item.args) ? item.args.map(arg => String(arg)) : [],
			source: item.source?.trim() || undefined,
		})),
		acceptRisk: params.acceptRisk === undefined ? inheritedAcceptRisk : Boolean(params.acceptRisk),
	};
}

function createRunDetails(plan: CommitPlan): CommitRunDetails {
	const commits: CommitResultDetails[] = plan.commits.map(commit => ({
		commitMessage: commit.commitMessage || undefined,
		rationale: commit.rationale || undefined,
		selectedFiles: [],
		verificationCount: commit.verification.length,
		verificationEvidence: commit.verificationEvidence.map(formatVerificationEvidence),
		acceptRisk: commit.acceptRisk,
		status: "pending",
	}));
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
		multiCommit: plan.multiCommit,
		context: plan.context || undefined,
		rationale: plan.commits.length === 1 ? plan.commits[0]?.rationale || undefined : undefined,
		commitMessage: plan.commits.length === 1 ? plan.commits[0]?.commitMessage || undefined : undefined,
		selectedFiles: [],
		ignoredFiles: [],
		verificationCount: commits.reduce((count, commit) => count + commit.verificationCount, 0),
		verificationEvidence: commits.flatMap(commit => commit.verificationEvidence),
		commitHash: undefined,
		commits,
		warnings: [],
	};
}

function validateCommitPlan(plan: CommitPlan): void {
	if (plan.commits.length === 0) throw new WorkflowError("At least one commit plan is required.");
	for (const [index, commit] of plan.commits.entries()) {
		validateCommitSpec(commit, formatCommitLabel(index, plan.commits.length));
	}
}

function validateCommitSpec(commit: CommitSpec, label: string): void {
	const prefix = label === "Commit" ? "" : `${label}: `;
	if (!commit.commitMessage) throw new WorkflowError(`${prefix}commit message is required.`);
	if (commit.commitMessage.includes("\0")) throw new WorkflowError(`${prefix}commit message contains a NUL byte.`);
	const lines = commit.commitMessage.split("\n");
	const subject = lines[0] ?? "";
	if (!CONVENTIONAL_COMMIT_RE.test(subject)) {
		throw new WorkflowError(`${prefix}commit message subject must be conventional-commit formatted. Received: ${subject}`);
	}
	if (subject.length > MAX_COMMIT_SUBJECT_CHARS) {
		throw new WorkflowError(`${prefix}commit message subject must be ${MAX_COMMIT_SUBJECT_CHARS} characters or fewer. Received ${subject.length}.`);
	}
	if (lines.length > 1 && lines[1] !== "") {
		throw new WorkflowError(`${prefix}commit message body must be separated from the subject by one blank line.`);
	}
	for (const [lineIndex, line] of lines.slice(2).entries()) {
		if (line.length > MAX_COMMIT_BODY_LINE_CHARS) {
			throw new WorkflowError(`${prefix}commit message body line ${lineIndex + 3} must be ${MAX_COMMIT_BODY_LINE_CHARS} characters or fewer. Received ${line.length}.`);
		}
	}
	for (const file of commit.files) validateRepoPath(file);
	if (commit.verification.length === 0 && commit.verificationEvidence.length === 0 && !commit.acceptRisk) {
		throw new WorkflowError(`${prefix}no verification command or prior verification evidence was provided. Pass narrow verification, concrete evidence, or rerun /commit --accept-risk only if the user accepts that risk.`);
	}
	for (const verification of commit.verification) validateVerification(verification);
	for (const evidence of commit.verificationEvidence) validateVerificationEvidence(evidence);
}

function repairCommitMessages(plan: CommitPlan, details: CommitRunDetails): void {
	for (const [index, commit] of plan.commits.entries()) {
		const repaired = repairCommitMessage(commit.commitMessage);
		if (repaired === commit.commitMessage) continue;
		commit.commitMessage = repaired;
		details.commits[index].commitMessage = repaired;
		if (plan.commits.length === 1) details.commitMessage = repaired;
		details.warnings.push(`${formatCommitLabel(index, plan.commits.length)}: commit message repaired to fit ${MAX_COMMIT_SUBJECT_CHARS}/${MAX_COMMIT_BODY_LINE_CHARS} character limits.`);
	}
}

function repairCommitMessage(message: string): string {
	if (!message || message.includes("\0")) return message;
	const lines = message.split("\n");
	if (lines.length > 1 && lines[1] !== "") return message;

	const subjectRepair = repairCommitSubject(lines[0] ?? "");
	if (!subjectRepair && !lines.slice(2).some(line => line.length > MAX_COMMIT_BODY_LINE_CHARS)) return message;

	const subject = subjectRepair?.subject ?? lines[0] ?? "";
	const bodyLines = lines.slice(2);
	if (subjectRepair?.overflow) bodyLines.unshift(subjectRepair.overflow, "");
	const repairedBody = wrapBodyLines(bodyLines);
	return repairedBody.length > 0 ? [subject, "", ...repairedBody].join("\n") : subject;
}

function repairCommitSubject(subject: string): { subject: string; overflow: string } | undefined {
	if (subject.length <= MAX_COMMIT_SUBJECT_CHARS) return undefined;
	const match = subject.match(/^([a-z]+(?:\([a-z0-9-]+\))?!?: )(.+)$/);
	if (!match) return undefined;

	const prefix = match[1] ?? "";
	const words = (match[2] ?? "").trim().split(/\s+/).filter(Boolean);
	const kept: string[] = [];
	let next = prefix;
	for (const word of words) {
		const candidate = kept.length === 0 ? `${prefix}${word}` : `${next} ${word}`;
		if (candidate.length > MAX_COMMIT_SUBJECT_CHARS) break;
		kept.push(word);
		next = candidate;
	}
	if (kept.length === 0) return undefined;
	if (kept.length === words.length) return next === subject ? undefined : { subject: next, overflow: "" };
	return { subject: next, overflow: words.slice(kept.length).join(" ") };
}

function wrapBodyLines(lines: string[]): string[] {
	const wrapped: string[] = [];
	let paragraph: string[] = [];
	const flush = () => {
		if (paragraph.length === 0) return;
		wrapped.push(...wrapWords(paragraph.join(" "), MAX_COMMIT_BODY_LINE_CHARS));
		paragraph = [];
	};
	for (const line of lines) {
		if (line.trim() === "") {
			flush();
			if (wrapped.length > 0 && wrapped[wrapped.length - 1] !== "") wrapped.push("");
			continue;
		}
		paragraph.push(line.trim());
	}
	flush();
	while (wrapped[wrapped.length - 1] === "") wrapped.pop();
	return wrapped;
}

function wrapWords(text: string, width: number): string[] {
	const lines: string[] = [];
	let current = "";
	for (const word of text.split(/\s+/).filter(Boolean)) {
		if (word.length > width) {
			if (current) lines.push(current);
			for (let index = 0; index < word.length; index += width) lines.push(word.slice(index, index + width));
			current = "";
			continue;
		}
		const candidate = current ? `${current} ${word}` : word;
		if (candidate.length > width) {
			if (current) lines.push(current);
			current = word;
		} else {
			current = candidate;
		}
	}
	if (current) lines.push(current);
	return lines;
}

function commitMessageArgs(message: string): string[] {
	const paragraphs = message.split(/\n{2,}/).map(paragraph => paragraph.trim()).filter(Boolean);
	return paragraphs.flatMap(paragraph => ["-m", paragraph]);
}

function formatCommitLabel(index: number, total: number): string {
	return total === 1 ? "Commit" : `Commit ${index + 1}/${total}`;
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

function validateVerificationEvidence(evidence: VerificationEvidence): void {
	if (!evidence.description) throw new WorkflowError("Verification evidence description is required.");
	if (evidence.description.includes("\0")) throw new WorkflowError("Verification evidence contains a NUL byte.");
	if (evidence.command?.includes("\0")) {
		throw new WorkflowError("Verification evidence command contains a NUL byte.");
	}
	if (evidence.source && evidence.source !== "observed" && evidence.source !== "user-reported") {
		throw new WorkflowError(`Verification evidence source must be observed or user-reported: ${evidence.source}`);
	}
	for (const arg of evidence.args ?? []) {
		if (arg.includes("\0")) throw new WorkflowError("Verification evidence argument contains a NUL byte.");
	}
}

async function runVerification(plan: CommitPlan, cwd: string, signal: AbortSignal | undefined, details: CommitRunDetails): Promise<void> {
	for (const [index, commit] of plan.commits.entries()) {
		const commitLabel = formatCommitLabel(index, plan.commits.length);
		if (commit.verification.length === 0) {
			if (commit.verificationEvidence.length > 0) {
				details.warnings.push(`${commitLabel}: used prior verification evidence instead of rerunning commands: ${commit.verificationEvidence.length}.`);
				continue;
			}
			details.warnings.push(`${commitLabel}: no verification was run because risk was accepted.`);
			continue;
		}
		for (const verification of commit.verification) {
			const label = verification.description || [verification.command, ...(verification.args ?? [])].join(" ");
			const displayLabel = plan.commits.length === 1 ? label : `${commitLabel}: ${label}`;
			details.phase = `Running verification: ${displayLabel}`;
			const result = await runCommand(cwd, verification.command, verification.args ?? [], signal, details);
			if (result.exitCode !== 0) {
				throw new WorkflowError(`Verification failed: ${displayLabel}\n${trimOutput(result.stderr || result.stdout)}`);
			}
		}
	}
}

async function collectSecretScanEntries(cwd: string, repoRoot: string, selectedFiles: string[], signal: AbortSignal | undefined, details: CommitRunDetails): Promise<SecretScanEntry[]> {
	const diff = await runGit(cwd, ["diff", "--no-ext-diff", "--unified=0", "HEAD", "--", ...selectedFiles], signal, details);
	if (diff.stdout.length > MAX_SECRET_SCAN_CHARS) {
		throw new WorkflowError("Selected diff is too large to secret-scan safely.");
	}
	const entries = parseAddedDiffLines(diff.stdout);
	let scannedChars = diff.stdout.length;
	const untracked = parseZPaths((await runGit(cwd, ["ls-files", "--others", "--exclude-standard", "-z", "--", ...selectedFiles], signal, details)).stdout);
	for (const file of untracked) {
		validateRepoPath(file);
		const blob = Bun.file(`${repoRoot}/${file}`);
		if (blob.size > MAX_SECRET_SCAN_CHARS) throw new WorkflowError(`Untracked file is too large to secret-scan safely: ${file}`);
		const content = await blob.text();
		scannedChars += content.length;
		if (scannedChars > MAX_SECRET_SCAN_CHARS) throw new WorkflowError("Selected files are too large to secret-scan safely.");
		for (const [index, line] of content.split(/\r?\n/).entries()) {
			entries.push({ file, line: index + 1, text: line });
		}
	}
	return entries;
}

function parseAddedDiffLines(diff: string): SecretScanEntry[] {
	const entries: SecretScanEntry[] = [];
	let file = "";
	let nextLine = 0;
	for (const line of diff.split(/\r?\n/)) {
		if (line.startsWith("+++ ")) {
			file = parseDiffNewPath(line);
			continue;
		}
		const hunk = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);
		if (hunk) {
			nextLine = Number(hunk[1]);
			continue;
		}
		if (!file) continue;
		if (line.startsWith("+") && !line.startsWith("+++")) {
			entries.push({ file, line: nextLine, text: line.slice(1) });
			nextLine += 1;
			continue;
		}
		if (line.startsWith("-") && !line.startsWith("---")) continue;
		if (line.startsWith(" ") || line === "") nextLine += 1;
	}
	return entries;
}

function parseDiffNewPath(line: string): string {
	const raw = line.startsWith("+++ b/") ? line.slice(6) : line.slice(4);
	const path = raw.split("\t", 1)[0];
	return path === "/dev/null" ? "" : path;
}

function scanForSecrets(entries: SecretScanEntry[]): void {
	for (const entry of entries) {
		for (const { name, pattern } of SECRET_PATTERNS) {
			if (pattern.test(entry.text)) {
				throw new WorkflowError(`Potential ${name} found in selected changes at ${entry.file}:${entry.line}: ${redactSecretExcerpt(entry.text)}`);
			}
		}
	}
}

function redactSecretExcerpt(text: string): string {
	const compact = text.trim().replace(/\s+/g, " ");
	const clipped = compact.length > 180 ? `${compact.slice(0, 177)}...` : compact;
	return clipped.replace(/[A-Za-z0-9_./+=-]{12,}/g, "<redacted>");
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
		"- Run narrow meaningful verification or record concrete prior verification evidence before committing.",
		"- Use a concise conventional commit message.",
		"- Preserve unrelated user changes.",
	].join("\n");
}

async function buildToolInvocationPrompt(parsed: ParsedArgs, source: CommitRequestSource): Promise<string> {
	const skillText = await loadCommitSkillText();
	const flags = {
		dryRun: parsed.dryRun,
		push: parsed.push,
		acceptRisk: parsed.acceptRisk,
		multiCommit: parsed.multiCommit,
		context: parsed.context || undefined,
	};
	const triggerDescription = source === "natural-language"
		? "The user asked to commit in natural language. Use the existing conversation context to plan the commit; do not answer conversationally, start a new session, or start a nested omp process."
		: "The user invoked /commit. Use the existing conversation context to plan the commit; do not start a new session or a nested omp process.";
	const toolCallRule = parsed.multiCommit
		? "Call the omp_commit tool exactly once with a commits array containing every planned split commit. Do not make separate omp_commit calls, and do not call git, bash, read, search, or any other tool; the tool owns sequential grouped execution and one live UI card."
		: "Call the omp_commit tool exactly once. Do not call git, bash, read, search, or any other tool; omp_commit owns hidden git operations and live UI.";
	return [
		triggerDescription,
		toolCallRule,
		"Commit skill guidance:",
		skillText.trim(),
		"Single-commit tool arguments:",
		JSON.stringify(
			{
				files: ["repo-relative file or directory to include"],
				commitMessage: "type(scope): concise subject\\n\\nOptional body paragraph explaining why, when useful.",
				rationale: "why this file set and message match the current conversation",
				verification: [{ command: "executable", args: ["arg"], description: "short label", required: true }],
				verificationEvidence: [{ description: "observed or user-reported verification already available in this conversation", command: "executable", args: ["arg"], source: "observed" }],
				dryRun: parsed.dryRun || undefined,
				push: parsed.push || undefined,
				acceptRisk: parsed.acceptRisk || undefined,
				context: parsed.context || undefined,
			},
			null,
			2,
		),
		parsed.multiCommit ? "Split/multiple commit tool arguments:" : "",
		parsed.multiCommit ? JSON.stringify(
			{
				commits: [{
					files: ["repo-relative file or directory for this split commit"],
					commitMessage: "type(scope): concise subject\\n\\nOptional body paragraph explaining why this split exists.",
					rationale: "why this split commit is separate",
					verification: [{ command: "executable", args: ["arg"], description: "short label", required: true }],
					verificationEvidence: [{ description: "observed or user-reported verification for this split commit", command: "executable", args: ["arg"], source: "observed" }],
				}],
				dryRun: parsed.dryRun || undefined,
				push: parsed.push || undefined,
				multiCommit: true,
				acceptRisk: parsed.acceptRisk || undefined,
				context: parsed.context || undefined,
			},
			null,
			2,
		) : "",
		"Rules:",
		"- For a single logical commit, pass top-level files/commitMessage/rationale/verification fields and omit the commits field entirely; do not include an empty array or blank commit object.",
		"- For split/multiple commit mode, pass one non-empty commits array containing every logical commit. Each commits[] entry MUST include only the files for that split commit; do not make multiple omp_commit tool calls.",
		`- Commit messages MAY be a block: subject line, blank line, then one or more body paragraphs in the same commitMessage string.`,
		`- Commit subject line MUST be ${MAX_COMMIT_SUBJECT_CHARS} characters or fewer. Body lines MUST be ${MAX_COMMIT_BODY_LINE_CHARS} characters or fewer.`,
		"- Use a body when the rationale belongs in git history; keep implementation notes in rationale if they are only for this workflow.",
		"- files MUST be only the files intentionally belonging to the commit, inferred from the current conversation context.",
		"- If the current context is insufficient to select files confidently, pass files: [] for a single commit or a commits entry with files: [] for split commit mode and explain the uncertainty in rationale; omp_commit will block safely with the actual changed files.",
		"- Prefer narrow, meaningful verification over broad validation. Do not choose a massive build/test step when a targeted command or prior concrete evidence covers the committed change.",
		"- If verification already appears in the conversation, pass verificationEvidence instead of rerunning it. Use source=observed for tool output seen in-session and source=user-reported only for explicit user-reported checks; never invent evidence.",
		"- If neither meaningful verification nor concrete prior evidence exists, only set acceptRisk when the user explicitly accepted that risk.",
		"- Preserve unrelated user changes. Do not include files just because they are modified.",
		parsed.multiCommit ? "- Split/multiple commit mode is requested: make separate commits for separate logical changes inside this one sequential tool call, and let the single tool UI report all created commits." : "",
		"- After omp_commit returns, summarize only the outcome, blocker, verification evidence, and residual risk.",
		parsed.model ? `Note: --model ${parsed.model} was provided but /commit now runs in the current session model; do not pass model to the tool.` : "",
		`Commit-request flags: ${JSON.stringify(flags)}`,
	].filter(Boolean).join("\n\n");
}

function parseNaturalCommitRequest(text: string, images: unknown[] | undefined, source: string): ParsedArgs | undefined {
	const trimmed = text.trim();
	if (!trimmed || trimmed.startsWith("/") || source === "extension" || (images?.length ?? 0) > 0) {
		return undefined;
	}
	if (COMMIT_MESSAGE_ONLY_RE.test(trimmed) || COMMIT_NEGATION_RE.test(trimmed) || SHOULD_COMMIT_RE.test(trimmed)) {
		return undefined;
	}
	if (!NATURAL_COMMIT_PATTERNS.some(pattern => pattern.test(trimmed))) {
		return undefined;
	}

	const parsed = parseCommitArgs(trimmed);
	if (NATURAL_DRY_RUN_RE.test(trimmed)) parsed.dryRun = true;
	if (NATURAL_ACCEPT_RISK_RE.test(trimmed)) parsed.acceptRisk = true;
	if (NATURAL_ATOMIC_RE.test(trimmed)) parsed.multiCommit = true;
	if (NATURAL_NO_PUSH_RE.test(trimmed)) parsed.push = false;
	else if (NATURAL_PUSH_RE.test(trimmed)) parsed.push = true;
	return parsed;
}

function parseCommitArgs(input: string): ParsedArgs {
	const tokens = tokenize(input);
	const context: string[] = [];
	let dryRun = false;
	let push = false;
	let acceptRisk = false;
	let multiCommit = false;
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
		} else if (token === "--no-push") {
			push = false;
		} else if (token === "--atomic" || token === "--multiple") {
			multiCommit = true;
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
	if (NATURAL_DRY_RUN_RE.test(input)) dryRun = true;
	if (NATURAL_ACCEPT_RISK_RE.test(input)) acceptRisk = true;
	if (NATURAL_ATOMIC_RE.test(input)) multiCommit = true;
	if (NATURAL_NO_PUSH_RE.test(input)) push = false;
	else if (NATURAL_PUSH_RE.test(input)) push = true;
	return { dryRun, push, acceptRisk, multiCommit, context: context.join(" ").trim(), model };
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
	const commits = getCommitRunCommits(details);
	if (commits.length === 1) {
		const commit = commits[0];
		return [
			"Commit preview complete.",
			`Message: ${commit.commitMessage}`,
			`Files: ${commit.selectedFiles.join(", ")}`,
			formatVerificationSummary(commit, false),
			details.ignoredFiles.length > 0 ? `Ignored modified files: ${details.ignoredFiles.join(", ")}` : "No ignored modified files.",
		].join("\n");
	}
	return [
		"Commit preview complete.",
		`Commits: ${commits.length}`,
		...formatCommitSummaryLines(commits, false),
		details.ignoredFiles.length > 0 ? `Ignored modified files: ${details.ignoredFiles.join(", ")}` : "No ignored modified files.",
	].join("\n");
}

function buildSuccessText(details: CommitRunDetails): string {
	const commits = getCommitRunCommits(details);
	if (commits.length === 1) {
		const commit = commits[0];
		return [
			`Commit created${commit.commitHash ? `: ${commit.commitHash}` : ""}.`,
			`Message: ${commit.commitMessage}`,
			`Files: ${commit.selectedFiles.join(", ")}`,
			formatVerificationSummary(commit, true),
			details.ignoredFiles.length > 0 ? `Ignored modified files left untouched: ${details.ignoredFiles.join(", ")}` : "No ignored modified files.",
			details.push ? "Pushed to remote." : "Not pushed.",
		].join("\n");
	}
	return [
		`Commits created: ${commits.length}.`,
		...formatCommitSummaryLines(commits, true),
		details.ignoredFiles.length > 0 ? `Ignored modified files left untouched: ${details.ignoredFiles.join(", ")}` : "No ignored modified files.",
		details.push ? "Pushed to remote." : "Not pushed.",
	].join("\n");
}

function formatCommitSummaryLines(commits: CommitResultDetails[], completed: boolean): string[] {
	const lines: string[] = [];
	for (const [index, commit] of commits.entries()) {
		const hash = completed && commit.commitHash ? `${commit.commitHash} ` : "";
		lines.push(`- ${index + 1}. ${hash}${commit.commitMessage}`);
		lines.push(`  Files: ${commit.selectedFiles.join(", ")}`);
		lines.push(`  ${formatVerificationSummary(commit, completed)}`);
	}
	return lines;
}

function formatVerificationSummary(details: { verificationCount: number; verificationEvidence?: string[]; acceptRisk: boolean }, completed: boolean): string {
	const evidenceCount = details.verificationEvidence?.length ?? 0;
	const parts: string[] = [];
	if (details.verificationCount > 0) parts.push(`commands ${completed ? "passed" : "planned"}: ${details.verificationCount}`);
	if (evidenceCount > 0) parts.push(`evidence: ${evidenceCount}`);
	if (parts.length > 0) return `Verification ${parts.join("; ")}`;
	return details.acceptRisk ? "Verification: accepted risk; no command run" : "Verification: none";
}

function getCommitRunCommits(details: CommitRunDetails): CommitResultDetails[] {
	const commits = (details as { commits?: CommitResultDetails[] }).commits;
	if (Array.isArray(commits) && commits.length > 0) return commits;
	return [{
		commitMessage: details.commitMessage,
		rationale: details.rationale,
		selectedFiles: details.selectedFiles ?? [],
		verificationCount: details.verificationCount ?? 0,
		verificationEvidence: details.verificationEvidence ?? [],
		acceptRisk: details.acceptRisk,
		commitHash: details.commitHash,
	}];
}

function formatVerificationEvidence(evidence: VerificationEvidence): string {
	const command = evidence.command ? ` (${[evidence.command, ...(evidence.args ?? [])].join(" ")})` : "";
	const source = evidence.source ? `${evidence.source}: ` : "";
	return `${source}${evidence.description}${command}`;
}

function renderCommitRun(details: CommitRunDetails, expanded: boolean, theme: any, spinnerFrame: number | undefined, width: number): string[] {
	const lines: string[] = [];
	const commits = getCommitRunCommits(details);
	const running = details.status === "running";
	const statusColor = details.status === "failed" ? "error" : details.status === "succeeded" ? "success" : "accent";
	const icon = running ? runningGlyph(spinnerFrame) : details.status === "failed" ? "✖" : "✔";
	const title = details.dryRun ? "Commit preview" : commits.length > 1 ? "Commit group" : "Commit";
	const maxFieldLines = expanded ? MAX_EXPANDED_WRAPPED_FIELD_LINES : MAX_WRAPPED_FIELD_LINES;
	const badges = [
		details.push ? "push" : undefined,
		details.multiCommit || commits.length > 1 ? `${commits.length} split commit${commits.length === 1 ? "" : "s"}` : undefined,
		details.acceptRisk ? "risk accepted" : undefined,
		(details.verificationEvidence?.length ?? 0) > 0 ? "verification evidence" : undefined,
	].filter(Boolean);
	const suffix = badges.length > 0 ? ` ${theme.fg("dim", badges.map(badge => `[${badge}]`).join(" "))}` : "";
	lines.push(`${theme.fg(statusColor, icon)} ${theme.fg("accent", theme.bold(title))}${suffix}`);
	appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, "Status", details.phase, MAX_WRAPPED_FIELD_LINES, statusColor);
	appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, running ? "Progress" : "Checklist", running ? latestCommitAction(commits, details) : formatStepSummary(details), MAX_WRAPPED_FIELD_LINES);

	if (commits.length > 1) {
		lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Commits")}: ${theme.fg("muted", `${commits.length}`)}`);
		const visibleCommits = expanded ? commits : commits.slice(0, MAX_VISIBLE_STEPS);
		for (const [index, commit] of visibleCommits.entries()) {
			const state = commitUiStatus(commit);
			const hash = commit.commitHash ? ` ${commit.commitHash}` : "";
			const row = `${commitStatusIcon(state)} ${state} ${index + 1}/${commits.length}${hash} ${commitSubject(commit)} — ${formatFileCount(commit.selectedFiles.length)} — ${commitVerificationState(commit, details.status === "succeeded")}`;
			appendWrappedText(lines, ` ${theme.fg("dim", theme.tree.branch)} `, ` ${theme.fg("dim", theme.tree.vertical)}  `, row, theme, commitStatusColor(state), width, maxFieldLines);
			if (expanded) {
				if (commit.rationale) appendWrappedField(lines, theme, width, theme.tree.vertical, theme.tree.vertical, "Rationale", commit.rationale, maxFieldLines);
				if (commit.selectedFiles.length > 0) appendWrappedField(lines, theme, width, theme.tree.vertical, theme.tree.vertical, "Files", commit.selectedFiles.join(", "), maxFieldLines);
				if ((commit.verificationEvidence?.length ?? 0) > 0) appendWrappedField(lines, theme, width, theme.tree.vertical, theme.tree.vertical, "Evidence", commit.verificationEvidence.join("; "), maxFieldLines);
				if (commit.errorText) appendWrappedField(lines, theme, width, theme.tree.vertical, theme.tree.vertical, "Error", commit.errorText, maxFieldLines, "error");
			}
		}
		if (visibleCommits.length < commits.length) lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "…")}`);
	} else {
		const commit = commits[0];
		if (commit.commitMessage) appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, "Message", commit.commitMessage.split("\n", 1)[0], maxFieldLines);
		if (commit.rationale) appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, "Rationale", commit.rationale, maxFieldLines);
		if (commit.selectedFiles.length > 0) appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, "Files", commit.selectedFiles.join(", "), maxFieldLines);
		appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, "Verification", formatSingleCommitVerification(commit, details.status === "succeeded"), maxFieldLines);
	}
	if (details.ignoredFiles.length > 0) appendWrappedField(lines, theme, width, theme.tree.branch, theme.tree.vertical, "Ignored", details.ignoredFiles.join(", "), maxFieldLines);

	if (expanded) {
		const visibleSteps = details.steps;
		for (const [index, step] of visibleSteps.entries()) {
			const isLast = index === visibleSteps.length - 1 && !details.finalText && !details.errorText;
			const prefix = isLast ? theme.tree.last : theme.tree.branch;
			const continuation = isLast ? " " : theme.tree.vertical;
			const stepIcon = step.status === "failed" ? "✖" : step.status === "done" ? "✔" : runningGlyph(spinnerFrame);
			const color = step.status === "failed" ? "error" : step.status === "done" ? "success" : "accent";
			appendWrappedText(lines, ` ${theme.fg("dim", prefix)} ${theme.fg(color, stepIcon)} `, ` ${theme.fg("dim", continuation)}  `, step.label, theme, "muted", width, MAX_WRAPPED_FIELD_LINES);
		}
	}

	if (details.errorText) {
		lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("error", "Blocked")}`);
		for (const line of details.errorText.split("\n").slice(0, MAX_FINAL_LINES)) {
			appendWrappedText(lines, ` ${theme.fg("dim", theme.tree.vertical)}  `, ` ${theme.fg("dim", theme.tree.vertical)}  `, line, theme, "error", width, maxFieldLines);
		}
		const created = commits.filter(commit => commit.commitHash);
		if (created.length > 0) {
			appendWrappedField(lines, theme, width, theme.tree.vertical, theme.tree.vertical, "Already created", `${created.map(commit => `${commit.commitHash} ${commitSubject(commit)}`).join("; ")}. Review git history before retrying; this commit group is only partially complete.`, maxFieldLines, "error");
		}
	}

	if (details.finalText) {
		const finalLines = details.finalText.split("\n").filter(Boolean);
		const shown = expanded ? finalLines : finalLines.slice(0, MAX_FINAL_LINES);
		lines.push(` ${theme.fg("dim", theme.tree.branch)} ${theme.fg("dim", "Result")}`);
		for (const line of shown) {
			appendWrappedText(lines, ` ${theme.fg("dim", theme.tree.vertical)}  `, ` ${theme.fg("dim", theme.tree.vertical)}  `, line, theme, "muted", width, maxFieldLines);
		}
		if (shown.length < finalLines.length) lines.push(` ${theme.fg("dim", theme.tree.vertical)}  ${theme.fg("dim", "…")}`);
	}

	if (details.finishedAt) {
		lines.push(` ${theme.fg("dim", theme.tree.last)} ${theme.fg("dim", `Completed in ${formatDuration(details.finishedAt - details.startedAt)}`)}`);
	}
	return lines;
}

function latestCommitAction(commits: CommitResultDetails[], details: CommitRunDetails): string {
	for (const [index, commit] of commits.entries()) {
		if (commit.status === "running" && commit.phase) return `${formatCommitLabel(index, commits.length)}: ${commit.phase}`;
	}
	for (let index = details.steps.length - 1; index >= 0; index -= 1) {
		if (details.steps[index].status === "running") return details.steps[index].label;
	}
	return details.phase;
}

function formatStepSummary(details: CommitRunDetails): string {
	if (details.steps.length === 0) {
		const count = `${details.toolCount} internal action${details.toolCount === 1 ? "" : "s"}`;
		return details.failedToolCount > 0 ? `${count} (${details.failedToolCount} failed)` : count;
	}
	const summary = new Map<string, StepStatus>();
	for (const step of details.steps) {
		summary.set(stepSummaryLabel(step.label), step.status);
	}
	return [...summary.entries()].map(([label, status]) => `${stepSummaryIcon(status)} ${label}`).join(" · ");
}

function stepSummaryLabel(label: string): string {
	const normalized = label.toLowerCase();
	if (normalized.includes("validating commit plan")) return "plan";
	if (normalized.includes("inspecting working tree")) return "tree";
	if (normalized.includes("reviewing selected diff")) return "diff";
	if (normalized.includes("checking for secrets")) return "secrets";
	if (normalized.includes("running verification")) return "verify";
	if (normalized.includes("staging selected changes")) return "stage";
	if (normalized.includes("creating commit")) return "commit";
	if (normalized.includes("checking commit result")) return "hash";
	if (normalized.includes("pushing branch")) return "push";
	return label.replace(/^Commit \d+\/\d+: /, "");
}

function stepSummaryIcon(status: StepStatus): string {
	if (status === "failed") return "✖";
	if (status === "done") return "✓";
	return "•";
}

function commitUiStatus(commit: CommitResultDetails): CommitUiStatus {
	if (commit.status) return commit.status;
	return commit.commitHash ? "succeeded" : "pending";
}

function commitStatusIcon(status: CommitUiStatus): string {
	if (status === "failed") return "✖";
	if (status === "succeeded") return "✔";
	if (status === "running") return "●";
	return "○";
}

function commitStatusColor(status: CommitUiStatus): string {
	if (status === "failed") return "error";
	if (status === "succeeded") return "success";
	if (status === "running") return "accent";
	return "muted";
}

function commitSubject(commit: CommitResultDetails): string {
	return commit.commitMessage?.split("\n", 1)[0] || "(no message)";
}

function formatFileCount(count: number): string {
	return `${count} file${count === 1 ? "" : "s"}`;
}

function commitVerificationState(commit: CommitResultDetails, completed: boolean): string {
	if (commit.verificationCount > 0) return completed ? "verified" : "verification planned";
	if ((commit.verificationEvidence?.length ?? 0) > 0) return "evidence";
	return commit.acceptRisk ? "risk accepted" : "no verification";
}

function formatSingleCommitVerification(commit: CommitResultDetails, completed: boolean): string {
	const summary = formatVerificationSummary(commit, completed);
	return (commit.verificationEvidence?.length ?? 0) > 0 ? `${summary}; ${commit.verificationEvidence.join("; ")}` : summary;
}

function frameIndex(frame: number | undefined): number {
	return frame ?? Math.floor(Date.now() / 120);
}

function runningGlyph(frame: number | undefined): string {
	const index = frameIndex(frame);
	return `${SPINNER_FRAMES[index % SPINNER_FRAMES.length]} ${PULSE_FRAMES[index % PULSE_FRAMES.length]}`;
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

function appendWrappedField(lines: string[], theme: any, width: number, branch: string, continuation: string, label: string, value: string, maxLines: number, color = "muted"): void {
	appendWrappedText(
		lines,
		` ${theme.fg("dim", branch)} ${theme.fg("dim", label)}: `,
		` ${theme.fg("dim", continuation)}  `,
		value,
		theme,
		color,
		width,
		maxLines,
	);
}

function appendWrappedText(lines: string[], prefix: string, continuationPrefix: string, value: string, theme: any, color: string, width: number, maxLines: number): void {
	const safeWidth = Math.max(MIN_RENDER_WIDTH, width) - 1;
	const firstWidth = Math.max(MIN_WRAP_CONTENT_WIDTH, safeWidth - visibleLength(prefix));
	const nextWidth = Math.max(MIN_WRAP_CONTENT_WIDTH, safeWidth - visibleLength(continuationPrefix));
	const chunks = wrapPlainText(value, firstWidth, nextWidth, maxLines);
	for (const [index, chunk] of chunks.entries()) {
		lines.push(`${index === 0 ? prefix : continuationPrefix}${theme.fg(color, chunk)}`);
	}
}

function wrapPlainText(value: string, firstWidth: number, nextWidth: number, maxLines: number): string[] {
	let remaining = value.replace(/\s+/g, " ").trim();
	const lines: string[] = [];
	while (remaining.length > 0 && lines.length < maxLines) {
		const width = Math.max(1, lines.length === 0 ? firstWidth : nextWidth);
		if (remaining.length <= width) {
			lines.push(remaining);
			remaining = "";
			break;
		}
		const breakAt = findWrapBreak(remaining, width);
		lines.push(remaining.slice(0, breakAt).trimEnd());
		remaining = remaining.slice(breakAt).trimStart();
	}
	if (remaining.length > 0 && lines.length > 0) {
		const width = Math.max(1, lines.length === 1 ? firstWidth : nextWidth);
		lines[lines.length - 1] = appendEllipsis(lines[lines.length - 1], width);
	}
	return lines;
}

function findWrapBreak(value: string, width: number): number {
	let lastWhitespace = -1;
	const limit = Math.min(value.length, width + 1);
	for (let index = 0; index < limit; index += 1) {
		if (/\s/.test(value[index])) lastWhitespace = index;
	}
	return lastWhitespace > 0 ? lastWhitespace : Math.max(1, width);
}

function appendEllipsis(value: string, width: number): string {
	if (width <= 1) return "…";
	return `${value.slice(0, width - 1).trimEnd()}…`;
}

function visibleLength(input: string): number {
	let visible = 0;
	for (let i = 0; i < input.length; i += 1) {
		if (input[i] === "\u001b") {
			const end = input.indexOf("m", i);
			if (end !== -1) {
				i = end;
				continue;
			}
		}
		visible += 1;
	}
	return visible;
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
