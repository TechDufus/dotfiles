import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

type Status = "working" | "idle";

function cacheRoot(): string {
	return process.env.XDG_CACHE_HOME || path.join(os.homedir(), ".cache");
}

function statusPath(): string | null {
	const paneId = process.env.TMUX_PANE;
	if (!paneId) return null;
	const paneNum = paneId.startsWith("%") ? paneId.slice(1) : paneId;
	if (!paneNum) return null;
	return path.join(cacheRoot(), "omp-status", `pane_${paneNum}.status`);
}

function writeStatus(status: Status): void {
	const file = statusPath();
	if (!file) return;
	try {
		fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
		fs.writeFileSync(file, `${status} ${process.pid} ${Date.now()}\n`, { mode: 0o600 });
	} catch {
		// Status reporting must never affect agent execution.
	}
}

export default function tmuxStatus(pi: any): void {
	pi.setLabel?.("tmux status");

	writeStatus("idle");
	process.once("exit", () => writeStatus("idle"));

	pi.on("session_start", () => writeStatus("idle"));
	pi.on("before_agent_start", () => writeStatus("working"));
	pi.on("agent_start", () => writeStatus("working"));
	pi.on("turn_start", () => writeStatus("working"));
	pi.on("tool_execution_start", () => writeStatus("working"));
	pi.on("tool_execution_update", () => writeStatus("working"));
	pi.on("message_update", () => writeStatus("working"));
	pi.on("agent_end", () => writeStatus("idle"));
	pi.on("session_shutdown", () => writeStatus("idle"));
}
