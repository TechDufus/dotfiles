import * as path from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const TOOL_NAME = "omp_commit";
const GIT_TIMEOUT_MS = 30_000;
const COMMIT_TIMEOUT_MS = 300_000;
const RECONCILE_TIMEOUT_MS = 5_000;
const MAX_VISIBLE_CHARS = 1_600;

interface ExecResult {
	stdout: string;
	stderr: string;
	code: number;
	killed?: boolean;
}

interface CommitParams {
	files: string[];
	commitMessage: string;
}

interface ToolContext {
	cwd: string;
}

interface CommandContext {
	isIdle(): boolean;
	waitForIdle(): Promise<void>;
}

class PhaseFailure extends Error {
	constructor(
		readonly phase: string,
		message: string,
	) {
		super(message);
		this.name = "PhaseFailure";
	}
}

class AmbiguousProcessFailure extends PhaseFailure {
	constructor(phase: string, message: string) {
		super(phase, message);
		this.name = "AmbiguousProcessFailure";
	}
}

export default function commitUi(pi: ExtensionAPI): void {
	const z = pi.zod;
	pi.registerTool({
		name: TOOL_NAME,
		label: "Commit",
		description: "Create one local commit after an explicit request. Stages and commits only the supplied paths and depends on the agent having completed contextual file, secret, and verification review.",
		parameters: z.object({
			files: z.array(
				z.string()
					.min(1)
					.refine((value: string) => !value.includes("\0"), "Paths must not contain NUL bytes."),
			).min(1).describe("Non-empty repo-relative file or directory pathspecs to stage and commit."),
			commitMessage: z.string()
				.refine((value: string) => !value.includes("\0") && value.trim().length > 0, "Commit message must be non-empty and NUL-free.")
				.describe("Commit message passed byte-for-byte to Git before normal hooks run."),
		}),
		async execute(_toolCallId: string, rawParams: unknown, signal: AbortSignal | undefined, _onUpdate: unknown, ctx: ToolContext) {
			let stagingStarted = false;
			try {
				const repositoryRoot = await resolveRepositoryRoot(pi, ctx.cwd, signal);
				const params = normalizeParams(rawParams);
				const files = normalizePathspecs(params.files);

				const status = await runGit(pi, "selected change check", repositoryRoot, [
					"--literal-pathspecs",
					"status",
					"--porcelain=v1",
					"-z",
					"--untracked-files=all",
					"--",
					...files,
				], signal, GIT_TIMEOUT_MS);
				if (status.stdout.length === 0) {
					throw new PhaseFailure("selected change check", "No selected changes were found.");
				}

				const previousHead = await readHead(pi, repositoryRoot, signal, GIT_TIMEOUT_MS, "HEAD check");
				stagingStarted = true;
				await runGit(pi, "staging", repositoryRoot, [
					"--literal-pathspecs",
					"add",
					"-A",
					"--",
					...files,
				], signal, GIT_TIMEOUT_MS);

				try {
					const commit = await runGitAllowFailure(pi, "commit", repositoryRoot, [
						"--literal-pathspecs",
						"commit",
						"--only",
						"--cleanup=verbatim",
						"-m",
						params.commitMessage,
						"--",
						...files,
					], signal, COMMIT_TIMEOUT_MS);
					if (commit.code !== 0) throw new PhaseFailure("commit", commandFailure(commit));
				} catch (error) {
					if (error instanceof AmbiguousProcessFailure) {
						return await reconcileCommitFailure(pi, repositoryRoot, previousHead, error);
					}
					throw error;
				}

				return await inspectSuccessfulCommit(pi, repositoryRoot, signal);
			} catch (error) {
				return errorResult(error, stagingStarted);
			}
		},
	});

	pi.registerCommand("commit", {
		description: "Create one local commit from established session evidence",
		handler: async (rawContext: string, ctx: CommandContext) => {
			if (!ctx.isIdle()) await ctx.waitForIdle();
			pi.sendMessage(
				{
					customType: "commit-request",
					content: buildCommitPrompt(rawContext),
					display: false,
					details: { context: rawContext },
					attribution: "user",
				},
				{ triggerTurn: true, deliverAs: "nextTurn" },
			);
		},
	});
}

function normalizeParams(value: unknown): CommitParams {
	if (!isRecord(value)) throw new PhaseFailure("input validation", "Tool parameters must be an object.");
	const files = value.files;
	const commitMessage = value.commitMessage;
	if (!Array.isArray(files) || files.length === 0) {
		throw new PhaseFailure("input validation", "files must be a non-empty array.");
	}
	if (!files.every(item => typeof item === "string")) {
		throw new PhaseFailure("input validation", "Every selected path must be a string.");
	}
	if (typeof commitMessage !== "string" || commitMessage.includes("\0") || commitMessage.trim().length === 0) {
		throw new PhaseFailure("input validation", "commitMessage must be non-empty and NUL-free.");
	}
	return { files, commitMessage };
}

function normalizePathspecs(files: string[]): string[] {
	const normalized: string[] = [];
	for (const raw of files) {
		if (raw.length === 0) throw new PhaseFailure("path validation", "Selected paths must not be empty.");
		if (raw.includes("\0")) throw new PhaseFailure("path validation", "Selected paths must not contain NUL bytes.");
		if (path.posix.isAbsolute(raw)) throw new PhaseFailure("path validation", "Selected paths must be repo-relative.");
		if (raw.split("/").includes("..")) throw new PhaseFailure("path validation", "Selected paths must not contain a '..' segment.");

		let selected = path.posix.normalize(raw);
		if (selected !== ".") selected = selected.replace(/\/+$/, "");
		if (selected === "." && raw !== ".") {
			throw new PhaseFailure("path validation", "Only the exact path '.' may select the repository root.");
		}
		if (selected.length === 0) throw new PhaseFailure("path validation", "Selected paths must not be empty.");
		normalized.push(selected);
	}
	return [...new Set(normalized)];
}

async function resolveRepositoryRoot(pi: ExtensionAPI, cwd: string, signal: AbortSignal | undefined): Promise<string> {
	const result = await runGit(pi, "repository root", cwd, ["rev-parse", "--show-toplevel"], signal, GIT_TIMEOUT_MS);
	const root = stripLineEndings(result.stdout);
	if (!root) throw new PhaseFailure("repository root", "Git returned an empty repository root.");
	return root;
}

async function readHead(
	pi: ExtensionAPI,
	cwd: string,
	signal: AbortSignal | undefined,
	timeout: number,
	phase: string,
): Promise<string | undefined> {
	const result = await runGitAllowFailure(pi, phase, cwd, ["rev-parse", "--verify", "--quiet", "HEAD"], signal, timeout);
	const oid = stripLineEndings(result.stdout);
	if (result.code === 0) {
		if (!isObjectId(oid)) throw new PhaseFailure(phase, "Git returned an invalid HEAD object ID.");
		return oid;
	}
	if (oid.length === 0 && result.stderr.length === 0) return undefined;
	throw new PhaseFailure(phase, commandFailure(result));
}

async function reconcileCommitFailure(
	pi: ExtensionAPI,
	cwd: string,
	previousHead: string | undefined,
	commitError: unknown,
) {
	try {
		const currentHead = await readHead(pi, cwd, AbortSignal.timeout(RECONCILE_TIMEOUT_MS), RECONCILE_TIMEOUT_MS, "commit reconciliation");
		if (currentHead === previousHead) return errorResult(commitError, true);
	} catch {
		// An unreadable ref cannot prove whether the failed process created a commit.
	}
	return textResult([
		"Commit outcome indeterminate—inspect HEAD/status before retrying.",
		"Selected paths may remain staged.",
		`Commit process: ${boundedField(failureMessage(commitError), 1_200)}`,
	].join("\n"), true);
}

async function inspectSuccessfulCommit(pi: ExtensionAPI, cwd: string, signal: AbortSignal | undefined) {
	let oid: string;
	try {
		const result = await runGit(pi, "post-commit OID inspection", cwd, ["rev-parse", "HEAD"], signal, GIT_TIMEOUT_MS);
		oid = stripLineEndings(result.stdout);
		if (!isObjectId(oid)) throw new PhaseFailure("post-commit OID inspection", "Git returned an invalid commit object ID.");
	} catch (error) {
		return successfulResult({}, `Post-commit inspection failed: ${failureMessage(error)}`);
	}

	const inspected: { shortHash?: string; subject?: string; paths?: string[] } = {};
	const warnings: string[] = [];
	try {
		const result = await runGit(pi, "post-commit short hash inspection", cwd, ["rev-parse", "--short", oid], signal, GIT_TIMEOUT_MS);
		inspected.shortHash = stripLineEndings(result.stdout);
	} catch (error) {
		warnings.push(`Short hash unavailable: ${failureMessage(error)}`);
	}
	try {
		const result = await runGit(pi, "post-commit subject inspection", cwd, ["show", "-s", "--format=%s", oid], signal, GIT_TIMEOUT_MS);
		inspected.subject = stripLineEndings(result.stdout);
	} catch (error) {
		warnings.push(`Subject unavailable: ${failureMessage(error)}`);
	}
	try {
		const result = await runGit(pi, "post-commit path inspection", cwd, [
			"diff-tree",
			"--root",
			"--no-commit-id",
			"--name-only",
			"--no-renames",
			"-r",
			"-z",
			oid,
		], signal, GIT_TIMEOUT_MS);
		inspected.paths = result.stdout.split("\0").filter(pathname => pathname.length > 0);
	} catch (error) {
		warnings.push(`Committed paths unavailable: ${failureMessage(error)}`);
	}
	return successfulResult(inspected, warnings.length > 0 ? warnings.join(" ") : undefined);
}

function successfulResult(
	inspected: { shortHash?: string; subject?: string; paths?: string[] },
	warning?: string,
) {
	const lines = ["Commit succeeded."];
	if (warning) lines.push(`Warning: ${boundedField(warning, 800)}`);
	if (inspected.shortHash !== undefined) lines.push(`Hash: ${boundedField(inspected.shortHash, 160)}`);
	if (inspected.subject !== undefined) lines.push(`Subject: ${boundedField(inspected.subject, 400)}`);
	if (inspected.paths !== undefined) {
		lines.push("Paths:");
		for (const pathname of inspected.paths) lines.push(`- ${boundedField(pathname, 400)}`);
	}
	return textResult(lines.join("\n"), false);
}

async function runGit(
	pi: ExtensionAPI,
	phase: string,
	cwd: string,
	args: string[],
	signal: AbortSignal | undefined,
	timeout: number,
): Promise<ExecResult> {
	const result = await runGitAllowFailure(pi, phase, cwd, args, signal, timeout);
	if (result.code !== 0) throw new PhaseFailure(phase, commandFailure(result));
	return result;
}

async function runGitAllowFailure(
	pi: ExtensionAPI,
	phase: string,
	cwd: string,
	args: string[],
	signal: AbortSignal | undefined,
	timeout: number,
): Promise<ExecResult> {
	if (signal?.aborted) throw new AmbiguousProcessFailure(phase, "Operation was cancelled.");
	let result: { stdout: string; stderr: string; code: number; killed?: boolean };
	try {
		result = await pi.exec("git", args, { cwd, timeout, signal });
	} catch (error) {
		throw new AmbiguousProcessFailure(phase, failureMessage(error));
	}
	if (signal?.aborted) throw new AmbiguousProcessFailure(phase, "Operation was cancelled.");
	if (result.killed === true) throw new AmbiguousProcessFailure(phase, "Git execution was killed or timed out.");
	return result;
}

function errorResult(error: unknown, selectedPathsMayBeStaged: boolean) {
	const phase = error instanceof PhaseFailure ? error.phase : "commit workflow";
	const lines = [`Commit failed during ${phase}.`];
	if (selectedPathsMayBeStaged) lines.push("Selected paths may remain staged.");
	lines.push(`Details: ${boundedField(failureMessage(error), 1_200)}`);
	return textResult(lines.join("\n"), true);
}

function textResult(text: string, isError: boolean) {
	return {
		content: [{ type: "text" as const, text: visibleText(text) }],
		isError,
	};
}

function commandFailure(result: ExecResult): string {
	const output = [result.stderr, result.stdout].filter(Boolean).join("\n");
	return output || `Git exited with code ${result.code}.`;
}

function failureMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

function buildCommitPrompt(rawContext: string): string {
	return [
		"The user explicitly invoked /commit. Follow the OMP commit skill/playbook using file-selection, secret-review, and verification evidence already present in this conversation.",
		"For this turn, use no tool other than omp_commit and call omp_commit at most once.",
		"Select only related repo-relative paths. Include both the old and new paths for a rename. Use the exact path '.' only when every current change is intended.",
		"Produce a conventional commit message with a subject of at most 50 characters and body lines wrapped at 72 characters.",
		"If the conversation does not establish the selected paths, completed verification, or absence of a real secret, call no tools and report that the normal commit skill/review is required first.",
		"If that evidence is established, invoke omp_commit exactly once, then give only a concise outcome.",
		`Optional user context (opaque command text): ${JSON.stringify(rawContext)}`,
	].join("\n\n");
}

function boundedField(value: string, maximum: number): string {
	const redacted = redact(value);
	return redacted.length <= maximum ? redacted : `${redacted.slice(0, maximum - 1)}…`;
}

function visibleText(value: string): string {
	const redacted = redact(value);
	return redacted.length <= MAX_VISIBLE_CHARS ? redacted : `${redacted.slice(0, MAX_VISIBLE_CHARS - 1)}…`;
}

function redact(value: string): string {
	return value
		.replace(/-----BEGIN [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----[\s\S]*?(?:-----END [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----|$)/gi, "<redacted-private-key>")
		.replace(/-----END [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----/gi, "<redacted-private-key>")
		.replace(/(?:gh[pousr]_|github_pat_|glpat-|xox[baprs]-|sk-(?:proj-)?)\S{8,}/g, "<redacted-token>");
}

function stripLineEndings(value: string): string {
	return value.replace(/[\r\n]+$/, "");
}

function isObjectId(value: string): boolean {
	return /^[0-9a-f]{40,128}$/i.test(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}
