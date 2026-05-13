/**
 * Agent Modes — Amp-style mode switching for pi.
 *
 *   ⚡ rush   — Kimi, thinking off                 (fast, cheap)
 *   ◆ oracle — Claude 4.6, thinking medium      (balanced)
 *   🧠 omnissiah — Claude 4.7, thinking xhigh   (max reasoning)
 *
 * Commands:
 *   /mode [rush|oracle|omnissiah]   — switch mode (or show current)
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
	fallbackThinking?: string;
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
	oracle: {
		icon: "",
		label: "oracle",
		model: "claude-sonnet-4-6",
		provider: "anthropic",
		thinking: "medium",
		fallbackThinking: "medium",
		color: "success",
	},
	omnissiah: {
		icon: "",
		label: "omnissiah",
		model: "claude-opus-4-7",
		provider: "anthropic",
		thinking: "xhigh",
		fallbackThinking: "high",
		color: "thinkingHigh",
	},
};

const MODE_ORDER = ["rush", "oracle", "omnissiah"];
const DEFAULT_MODE = "rush";

function nextMode(current: string): string {
	const idx = MODE_ORDER.indexOf(current);
	return MODE_ORDER[(idx + 1) % MODE_ORDER.length];
}

function publishStatus(ctx: ExtensionContext, mode: ModeConfig): void {
	const thm = ctx.ui.theme;
	ctx.ui.setStatus("agent-mode", thm.fg(mode.color, `${mode.icon} ${mode.label}`));
}

function getRegistry(ctx: ExtensionContext): any | undefined {
	return (ctx as any).modelRegistry;
}

function listModels(ctx: ExtensionContext): any[] {
	const registry = getRegistry(ctx);
	if (!registry) return [];
	try {
		if (typeof registry.listModels === "function") return registry.listModels();
		if (typeof registry.getAvailable === "function") return registry.getAvailable();
	} catch {
		// ignore
	}
	return [];
}

function findTargetModel(ctx: ExtensionContext, mode: ModeConfig): { model?: any; fuzzy: boolean } {
	const models = listModels(ctx);
	if (models.length === 0) return { model: undefined, fuzzy: false };

	const exact = models.find((m: any) => m.id === mode.model && m.provider === mode.provider);
	if (exact) return { model: exact, fuzzy: false };

	const wantedProvider = mode.provider.toLowerCase();
	const wantedModel = mode.model.toLowerCase();
	const providerHint = wantedProvider.split(/[-_/]/)[0];
	const modelHints = wantedModel.split(/[-_/]/).filter(Boolean);

	const scored = models
		.map((m: any) => {
			const provider = String(m.provider ?? "").toLowerCase();
			const id = String(m.id ?? "").toLowerCase();
			let score = 0;

			if (provider === wantedProvider) score += 10;
			else if (provider.includes(providerHint) || wantedProvider.includes(provider)) score += 5;

			if (id === wantedModel) score += 10;
			if (id.includes(wantedModel) || wantedModel.includes(id)) score += 8;
			if (modelHints.some((hint) => hint.length >= 3 && id.includes(hint))) score += 4;

			return { model: m, score };
		})
		.filter((entry) => entry.score > 0)
		.sort((a, b) => b.score - a.score);

	return { model: scored[0]?.model, fuzzy: !!scored[0] };
}

function fallbackScore(model: any, mode: ModeConfig): number {
	const provider = String(model.provider ?? "").toLowerCase();
	const id = String(model.id ?? "").toLowerCase();
	const isReasoning = Boolean(model.reasoning);
	let score = 0;

	if (mode.label === "rush") {
		if (provider.includes("kimi")) score += 50;
		if (provider.includes("openai") || provider.includes("codex")) score += 35;
		if (provider.includes("google") || provider.includes("gemini")) score += 25;
		if (provider.includes("anthropic")) score += 15;
		if (id.includes("kimi")) score += 20;
		if (id.includes("gpt-5") || id.includes("gpt-4.1") || id.includes("codex")) score += 15;
		if (id.includes("flash") || id.includes("mini") || id.includes("haiku")) score += 12;
		if (!isReasoning) score += 10;
		if (id.includes("opus")) score -= 20;
		if (id.includes("sonnet")) score -= 8;
	}

	if (mode.label === "oracle") {
		if (provider.includes("anthropic")) score += 55;
		if (provider.includes("openai") || provider.includes("codex")) score += 35;
		if (provider.includes("google") || provider.includes("gemini")) score += 22;
		if (provider.includes("kimi")) score += 12;
		if (id.includes("sonnet") && id.includes("4") && id.includes("6")) score += 40;
		if (id.includes("sonnet")) score += 22;
		if (id.includes("claude")) score += 12;
		if (id.includes("gpt-5.4")) score += 32;
		if (id.includes("gpt-5")) score += 18;
		if (id.includes("opus")) score += 8;
		if (id.includes("flash") || id.includes("mini") || id.includes("haiku")) score -= 10;
		if (isReasoning) score += 6;
	}

	if (mode.label === "omnissiah") {
		if (provider.includes("anthropic")) score += 60;
		if (provider.includes("openai") || provider.includes("codex")) score += 38;
		if (provider.includes("google") || provider.includes("gemini")) score += 24;
		if (provider.includes("kimi")) score += 10;
		if (id.includes("opus") && id.includes("4") && id.includes("7")) score += 45;
		if (id.includes("opus")) score += 24;
		if (id.includes("claude")) score += 12;
		if (id.includes("gpt-5.5")) score += 34;
		if (id.includes("gpt-5")) score += 20;
		if (id.includes("sonnet")) score += 6;
		if (id.includes("flash") || id.includes("mini") || id.includes("haiku")) score -= 18;
		if (isReasoning) score += 15;
	}

	return score;
}

function findFallbackModel(ctx: ExtensionContext, mode: ModeConfig, exclude?: any): any | undefined {
	const models = listModels(ctx)
		.filter((m: any) => !exclude || !(m.provider === exclude.provider && m.id === exclude.id))
		.map((m: any) => ({ model: m, score: fallbackScore(m, mode) }))
		.filter((entry) => entry.score > 0)
		.sort((a, b) => b.score - a.score);

	return models[0]?.model;
}

function describeModel(model: any | undefined, thinking: string): string {
	if (!model) return `none (thinking: ${thinking})`;
	return `${model.provider}/${model.id} (thinking: ${thinking})`;
}

async function applyMode(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	modeName: string,
): Promise<{ ok: boolean; reason?: string; triedModel?: string; appliedModel?: any; appliedThinking?: string }> {
	const mode = MODES[modeName];
	if (!mode) return { ok: false, reason: `Unknown mode: ${modeName}` };

	const target = findTargetModel(ctx, mode);
	const attempted = target.model;
	const fallback = findFallbackModel(ctx, mode, attempted);

	if (!attempted && !fallback) {
		return { ok: false, reason: `No suitable model found for mode ${mode.label}` };
	}

	const candidates = [attempted, fallback].filter(Boolean);
	for (const candidate of candidates) {
		let modelSwitched = false;
		try {
			const ok = await pi.setModel(candidate);
			modelSwitched = ok !== false;
		} catch {
			modelSwitched = false;
		}

		if (!modelSwitched) continue;

		const exactMatch = attempted && candidate.provider === attempted.provider && candidate.id === attempted.id;
		const appliedThinking = exactMatch ? mode.thinking : (mode.fallbackThinking ?? mode.thinking);
		try {
			pi.setThinkingLevel(appliedThinking as any);
		} catch {
			// ignore
		}

		publishStatus(ctx, mode);
		const suffix = exactMatch ? (target.fuzzy ? " (fuzzy)" : "") : " (fallback)";
		return {
			ok: true,
			triedModel: `${candidate.provider}/${candidate.id}${suffix}`,
			appliedModel: candidate,
			appliedThinking,
		};
	}

	return {
		ok: false,
		reason: attempted
			? `Unable to switch to ${attempted.provider}/${attempted.id}${fallback ? ` or fallback ${fallback.provider}/${fallback.id}` : ""}`
			: fallback
				? `Unable to switch to fallback ${fallback.provider}/${fallback.id}`
				: `No usable model found for mode ${mode.label}`,
	};
}

export default function (pi: ExtensionAPI) {
	let currentMode = DEFAULT_MODE;
	let liveModel: any | undefined;
	let liveThinking = "medium";

	pi.on("session_start", async (_event, ctx) => {
		liveModel = ctx.model;
		liveThinking = String(pi.getThinkingLevel?.() ?? "medium");

		for (const [name, config] of Object.entries(MODES)) {
			if (liveModel?.id === config.model && liveThinking === config.thinking) {
				currentMode = name;
				break;
			}
		}
		publishStatus(ctx, MODES[currentMode]);
	});

	pi.on("model_select", async (event) => {
		liveModel = event.model;
	});

	pi.on("thinking_level_select", async (event) => {
		liveThinking = String(event.level);
	});

	pi.registerCommand("mode", {
		description: "Switch agent mode (rush / oracle / omnissiah)",
		getArgumentCompletions: (prefix: string) => {
			const items = MODE_ORDER.map((name) => ({
				value: name,
				label: `${MODES[name].icon} ${name} — ${MODES[name].model}, think:${MODES[name].thinking}`,
			}));
			return items.filter((i) => i.value.startsWith(prefix));
		},
		handler: async (args, ctx) => {
			const rawRequested = (args ?? "").trim().toLowerCase();
			const requested = rawRequested === "deep"
				? "omnissiah"
				: rawRequested === "smart"
					? "oracle"
					: rawRequested;

			if (!requested) {
				const mode = MODES[currentMode];
				ctx.ui.notify(
					`Current mode label: ${mode.icon} ${mode.label}\n` +
						`  target: ${mode.provider}/${mode.model}\n` +
						`  target thinking: ${mode.thinking}\n` +
						`  using: ${describeModel(liveModel, liveThinking)}\n\n` +
						MODE_ORDER.map((n) => {
							const m = MODES[n];
							const marker = n === currentMode ? "→ " : "  ";
							return `${marker}${m.icon} ${m.label}  (${m.provider}/${m.model}, think:${m.thinking})`;
						}).join("\n"),
					"info",
				);
				return;
			}

			if (!MODES[requested]) {
				ctx.ui.notify(`Unknown mode "${requested}". Available: ${MODE_ORDER.join(", ")}`, "error");
				return;
			}

			const result = await applyMode(pi, ctx, requested);
			if (!result.ok) {
				ctx.ui.notify(
					`Mode switch failed: ${result.reason}\nCurrent using: ${describeModel(liveModel, liveThinking)}`,
					"error",
				);
				return;
			}

			currentMode = requested;
			if (result.appliedModel) liveModel = result.appliedModel;
			if (result.appliedThinking) liveThinking = result.appliedThinking;
			const mode = MODES[currentMode];
			ctx.ui.notify(
				`${mode.icon} ${mode.label}\nTrying: ${result.triedModel ?? `${mode.provider}/${mode.model}`}\nUsing: ${describeModel(liveModel, liveThinking)}`,
				"info",
			);
		},
	});

	pi.registerShortcut("ctrl+alt+m", {
		description: "Cycle agent mode (rush → oracle → omnissiah)",
		handler: async (ctx) => {
			const next = nextMode(currentMode);
			const result = await applyMode(pi, ctx, next);
			if (!result.ok) {
				ctx.ui.notify(
					`Mode switch failed: ${result.reason}\nCurrent using: ${describeModel(liveModel, liveThinking)}`,
					"error",
				);
				return;
			}

			currentMode = next;
			if (result.appliedModel) liveModel = result.appliedModel;
			if (result.appliedThinking) liveThinking = result.appliedThinking;
			const mode = MODES[currentMode];
			ctx.ui.notify(
				`${mode.icon} ${mode.label}\nTrying: ${result.triedModel ?? `${mode.provider}/${mode.model}`}\nUsing: ${describeModel(liveModel, liveThinking)}`,
				"info",
			);
		},
	});
}
