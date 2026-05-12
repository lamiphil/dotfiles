/**
 * Agent Modes — Amp-style mode switching for pi.
 *
 *   ⚡ rush   — claude-sonnet-4-6, thinking off     (fast, cheap)
 *   ◆ smart  — claude-opus-4-7, thinking medium     (balanced)
 *   🧠 deep   — claude-opus-4-7, thinking high       (max reasoning)
 *
 * Commands:
 *   /mode [rush|smart|deep]   — switch mode (or show current)
 *
 * Keybind:
 *   Ctrl+Alt+M  — cycle through modes
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

interface ModeConfig {
	icon: string;
	label: string;
	model: string;
	provider: string;
	thinking: string;
	color: string;
}

const MODES: Record<string, ModeConfig> = {
	rush: {
		icon: "",
		label: "rush",
		model: "kimi-for-coding",
		provider: "kimi-coding",
		thinking: "off",
		color: "error",
	},
	smart: {
		icon: "",
		label: "smart",
		model: "claude-opus-4-7",
		provider: "anthropic",
		thinking: "medium",
		color: "success",
	},
	deep: {
		icon: "",
		label: "deep",
		model: "claude-opus-4-7",
		provider: "anthropic",
		thinking: "high",
		color: "thinkingHigh",
	},
};

const MODE_ORDER = ["rush", "smart", "deep"];
const DEFAULT_MODE = "rush";

function nextMode(current: string): string {
	const idx = MODE_ORDER.indexOf(current);
	return MODE_ORDER[(idx + 1) % MODE_ORDER.length];
}

function publishStatus(ctx: ExtensionContext, mode: ModeConfig): void {
	const thm = ctx.ui.theme;
	ctx.ui.setStatus("agent-mode", thm.fg(mode.color, `${mode.icon} ${mode.label}`));
}

async function applyMode(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	modeName: string,
): Promise<boolean> {
	const mode = MODES[modeName];
	if (!mode) return false;

	let matched = false;
	try {
		const registry = (ctx as any).modelRegistry;
		if (registry) {
			const models = registry.listModels();
			const target = models.find(
				(m: any) => m.id === mode.model && m.provider === mode.provider,
			);
			if (target) {
				const ok = await pi.setModel(target);
				matched = ok !== false;
			}
		}
	} catch { /* fallthrough */ }

	try {
		pi.setThinkingLevel(mode.thinking as any);
	} catch { /* fallthrough */ }

	publishStatus(ctx, mode);
	return matched;
}

export default function (pi: ExtensionAPI) {
	let currentMode = DEFAULT_MODE;

	pi.on("session_start", async (_event, ctx) => {
		const model = ctx.model;
		const thinking = pi.getThinkingLevel?.() ?? "medium";

		for (const [name, config] of Object.entries(MODES)) {
			if (model?.id === config.model && thinking === config.thinking) {
				currentMode = name;
				break;
			}
		}
		publishStatus(ctx, MODES[currentMode]);
	});

	pi.registerCommand("mode", {
		description: "Switch agent mode (rush / smart / deep)",
		getArgumentCompletions: (prefix: string) => {
			const items = MODE_ORDER.map((name) => ({
				value: name,
				label: `${MODES[name].icon} ${name} — ${MODES[name].model}, think:${MODES[name].thinking}`,
			}));
			return items.filter((i) => i.value.startsWith(prefix));
		},
		handler: async (args, ctx) => {
			const requested = (args ?? "").trim().toLowerCase();

			if (!requested) {
				const mode = MODES[currentMode];
				ctx.ui.notify(
					`Current mode: ${mode.icon} ${mode.label}\n` +
						`  model: ${mode.provider}/${mode.model}\n` +
						`  thinking: ${mode.thinking}\n\n` +
						MODE_ORDER.map((n) => {
							const m = MODES[n];
							const marker = n === currentMode ? "→ " : "  ";
							return `${marker}${m.icon} ${m.label}  (${m.model}, think:${m.thinking})`;
						}).join("\n"),
					"info",
				);
				return;
			}

			if (!MODES[requested]) {
				ctx.ui.notify(`Unknown mode "${requested}". Available: ${MODE_ORDER.join(", ")}`, "error");
				return;
			}

			currentMode = requested;
			const ok = await applyMode(pi, ctx, currentMode);
			const mode = MODES[currentMode];
			ctx.ui.notify(`${mode.icon} ${mode.label}`, "info");
		},
	});

	// Ctrl+Alt+M — cycle modes (NOT ctrl+m which is Enter in terminals)
	pi.registerShortcut("ctrl+alt+m", {
		description: "Cycle agent mode (rush → smart → deep)",
		handler: async (ctx) => {
			currentMode = nextMode(currentMode);
			const ok = await applyMode(pi, ctx, currentMode);
			const mode = MODES[currentMode];
			ctx.ui.notify(`${mode.icon} ${mode.label}`, "info");
		},
	});
}
