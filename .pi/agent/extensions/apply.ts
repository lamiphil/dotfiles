import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

type TargetKey = "core" | "powerline" | "vim";

interface Target {
	key: TargetKey;
	label: string;
	script: string;
}

const HOME = process.env.HOME ?? homedir();

const TARGETS: Record<TargetKey, Target> = {
	core: {
		key: "core",
		label: "pi-coding-agent",
		script: join(HOME, "dotfiles", ".pi", "agent", "packages", "pi-coding-agent", "apply.sh"),
	},
	powerline: {
		key: "powerline",
		label: "pi-powerline-footer",
		script: join(HOME, "dotfiles", ".pi", "agent", "packages", "pi-powerline-footer", "apply.sh"),
	},
	vim: {
		key: "vim",
		label: "vim-motions-pi",
		script: join(HOME, "dotfiles", ".pi", "agent", "packages", "vim-motions-pi", "apply.sh"),
	},
};

const APPLY_ORDER: TargetKey[] = ["core", "powerline", "vim"];

function parseTargets(rawArgs: string): { targets?: Target[]; error?: string } {
	const arg = rawArgs.trim().toLowerCase();
	if (!arg || arg === "all") {
		return { targets: APPLY_ORDER.map((key) => TARGETS[key]) };
	}

	if (arg === "pi" || arg === "agent" || arg === "core") {
		return { targets: [TARGETS.core] };
	}
	if (arg === "powerline" || arg === "footer") {
		return { targets: [TARGETS.powerline] };
	}
	if (arg === "vim" || arg === "motions") {
		return { targets: [TARGETS.vim] };
	}

	return {
		error: `Unknown target "${rawArgs.trim()}". Use: all, core, powerline, or vim.`,
	};
}

function formatPath(path: string): string {
	return path.replace(HOME, "~");
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("apply", {
		description: "Apply local pi patch scripts after `pi update`",
		getArgumentCompletions: (prefix: string) => {
			const items = [
				{ value: "all", label: "all — run every local pi patch script" },
				{ value: "core", label: "core — patch pi-coding-agent" },
				{ value: "powerline", label: "powerline — patch pi-powerline-footer" },
				{ value: "vim", label: "vim — patch vim-motions-pi" },
			];
			const filtered = items.filter((item) => item.value.startsWith(prefix.trim().toLowerCase()));
			return filtered.length > 0 ? filtered : null;
		},
		handler: async (rawArgs, ctx) => {
			const parsed = parseTargets(rawArgs ?? "");
			if (parsed.error || !parsed.targets) {
				ctx.ui.notify(parsed.error ?? "No targets selected.", "error");
				return;
			}

			const missing = parsed.targets.filter((target) => !existsSync(target.script));
			if (missing.length > 0) {
				ctx.ui.notify(
					[
						"Missing apply script(s):",
						...missing.map((target) => `- ${target.label}: ${formatPath(target.script)}`),
					].join("\n"),
					"error",
				);
				return;
			}

			ctx.ui.setStatus("apply", ctx.ui.theme.fg("warning", "Applying pi patches…"));

			const ok: string[] = [];
			const skipped: string[] = [];
			const failed: string[] = [];

			try {
				for (const target of parsed.targets) {
					const result = await pi.exec("bash", [target.script], {
						cwd: dirname(target.script),
						timeout: 300000,
					});

					const combinedOutput = `${result.stdout || ""}\n${result.stderr || ""}`.trim();
					const wasSkipped = /\bskipping\b/i.test(combinedOutput);

					if ((result.code ?? 0) === 0) {
						if (wasSkipped) skipped.push(target.label);
						else ok.push(target.label);
						continue;
					}

					const details = `${result.stderr || result.stdout || "script failed"}`.trim();
					failed.push(`${target.label}\n${details}`);
				}
			} finally {
				ctx.ui.setStatus("apply", undefined);
			}

			if (failed.length > 0) {
				const lines: string[] = [];
				if (ok.length > 0) lines.push(`Applied: ${ok.join(", ")}`);
				if (skipped.length > 0) lines.push(`Skipped: ${skipped.join(", ")}`);
				if (lines.length === 0) lines.push("No scripts applied successfully.");
				lines.push("", "Failures:", ...failed);
				ctx.ui.notify(lines.join("\n\n"), "error");
				return;
			}

			const lines: string[] = [];
			if (ok.length > 0) lines.push(`Applied: ${ok.join(", ")}`);
			if (skipped.length > 0) lines.push(`Skipped: ${skipped.join(", ")}`);
			if (ok.length > 0) lines.push("", "Restart pi to pick up patched package code.");
			ctx.ui.notify(lines.join("\n"), "success");
		},
	});
}
