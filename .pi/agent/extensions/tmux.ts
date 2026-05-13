/**
 * Tmux pane title integration.
 *
 * Sets the tmux pane title to show pi's state:
 *   π project · model · session-title
 *   π* project · model · session-title   (when working)
 *
 * Clears on exit so your shell prompt isn't affected.
 * Only activates when running inside tmux.
 */

import { execSync } from "node:child_process";
import { basename } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const MARKER = "π";
const MAX_TITLE_LEN = 30;

function isTmux(): boolean {
	return !!process.env.TMUX;
}

function tmuxCmd(cmd: string): void {
	try {
		execSync(`tmux ${cmd}`, { stdio: "ignore", timeout: 2000 });
	} catch {
		// ignore
	}
}

function shortenModel(id: string): string {
	return id.replace(/-\d{8}$/, "").replace(/^claude-/, "");
}

function truncate(str: string, max: number): string {
	return str.length <= max ? str : `${str.slice(0, max - 1)}…`;
}

export default function (pi: ExtensionAPI) {
	if (!isTmux()) return;

	const project = basename(process.cwd());
	let modelName = "";
	let isWorking = false;

	function getSessionTitle(ctx?: { sessionManager: { getBranch(): any[] } }): string | undefined {
		const name = pi.getSessionName();
		if (name) return name;
		if (!ctx) return undefined;
		try {
			for (const entry of ctx.sessionManager.getBranch()) {
				if (entry.type === "message" && entry.message?.role === "user" && Array.isArray(entry.message.content)) {
					const text = entry.message.content.find((c: any) => c.type === "text");
					if (text?.text) {
						const first = text.text.split("\n")[0].trim();
						if (first) return first;
					}
				}
			}
		} catch { /* ignore */ }
		return undefined;
	}

	function updateTitle(ctx?: { sessionManager: { getBranch(): any[] } }): void {
		const icon = isWorking ? `${MARKER}*` : MARKER;
		const model = modelName ? ` · ${modelName}` : "";
		const session = getSessionTitle(ctx);
		const sessionPart = session ? ` · ${truncate(session, MAX_TITLE_LEN)}` : "";
		tmuxCmd(`select-pane -T '${icon} ${project}${model}${sessionPart}'`);
	}

	function clearTitle(): void {
		tmuxCmd("select-pane -T ''");
	}

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.model) modelName = shortenModel(ctx.model.id);
		updateTitle(ctx);
	});

	pi.on("model_select", async (event, ctx) => {
		modelName = shortenModel(event.model.id);
		updateTitle(ctx);
	});

	pi.on("agent_start", async (_event, ctx) => {
		isWorking = true;
		updateTitle(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		isWorking = false;
		updateTitle(ctx);
	});

	pi.on("session_shutdown", async () => {
		clearTitle();
	});
}
