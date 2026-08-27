/*
 * Provider-aware agent modes.
 *
 *   Ctrl+Alt+M — cycle rush → oracle → omnissiah
 *   Ctrl+Alt+P — toggle OpenAI ↔ Anthropic, retaining the current mode
 *   /mode      — inspect or select a mode within the active provider
 */

import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type ProviderProfile = "openai" | "anthropic";
type ModeName = "rush" | "oracle" | "omnissiah";

interface ModeConfig {
	icon: string;
	label: ModeName;
	model: string;
	provider: string;
	thinking: string;
	color: string;
}

interface PersistedState {
	provider: ProviderProfile;
	mode: ModeName;
}

interface ApplyResult {
	ok: boolean;
	reason?: string;
	model?: any;
	thinking?: string;
}

const PROFILES: Record<ProviderProfile, Record<ModeName, ModeConfig>> = {
	openai: {
		rush: {
			icon: "",
			label: "rush",
			model: "gpt-5.6-luna",
			provider: "openai-codex",
			thinking: "medium",
			color: "error",
		},
		oracle: {
			icon: "",
			label: "oracle",
			model: "gpt-5.6-terra",
			provider: "openai-codex",
			thinking: "medium",
			color: "success",
		},
		omnissiah: {
			icon: "",
			label: "omnissiah",
			model: "gpt-5.6-sol",
			provider: "openai-codex",
			thinking: "high",
			color: "thinkingHigh",
		},
	},
	anthropic: {
		rush: {
			icon: "",
			label: "rush",
			model: "claude-haiku-4-5",
			provider: "anthropic",
			thinking: "medium",
			color: "error",
		},
		oracle: {
			icon: "",
			label: "oracle",
			model: "claude-opus-4-7",
			provider: "anthropic",
			thinking: "high",
			color: "success",
		},
		omnissiah: {
			icon: "",
			label: "omnissiah",
			model: "claude-fable-5",
			provider: "anthropic",
			thinking: "max",
			color: "thinkingHigh",
		},
	},
};

const MODE_ORDER: ModeName[] = ["rush", "oracle", "omnissiah"];
const DEFAULT_PROVIDER: ProviderProfile = "openai";
const DEFAULT_MODE: ModeName = "rush";
const STATE_PATH = join(
	process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"),
	"pi",
	"agent-modes.json",
);

const PROVIDER_META: Record<ProviderProfile, { label: string; marker: string }> = {
	openai: { label: "OpenAI", marker: "Ⓞ" },
	anthropic: { label: "Anthropic", marker: "Ⓐ" },
};

let stateWriteQueue: Promise<void> = Promise.resolve();

function isModeName(value: unknown): value is ModeName {
	return typeof value === "string" && MODE_ORDER.includes(value as ModeName);
}

function isProviderProfile(value: unknown): value is ProviderProfile {
	return value === "openai" || value === "anthropic";
}

async function readPersistedState(): Promise<PersistedState | undefined> {
	try {
		const parsed = JSON.parse(await readFile(STATE_PATH, "utf8"));
		if (!isProviderProfile(parsed?.provider) || !isModeName(parsed?.mode)) return undefined;
		return { provider: parsed.provider, mode: parsed.mode };
	} catch {
		return undefined;
	}
}

function persistState(state: PersistedState): Promise<void> {
	stateWriteQueue = stateWriteQueue
		.catch(() => undefined)
		.then(async () => {
			await mkdir(dirname(STATE_PATH), { recursive: true });
			const temporary = `${STATE_PATH}.${process.pid}.tmp`;
			try {
				await writeFile(temporary, `${JSON.stringify(state, null, 2)}\n`, "utf8");
				await rename(temporary, STATE_PATH);
			} catch (error) {
				await unlink(temporary).catch(() => undefined);
				throw error;
			}
		});
	return stateWriteQueue;
}

function nextMode(current: ModeName): ModeName {
	const index = MODE_ORDER.indexOf(current);
	return MODE_ORDER[(index + 1) % MODE_ORDER.length];
}

function otherProvider(current: ProviderProfile): ProviderProfile {
	return current === "openai" ? "anthropic" : "openai";
}

function providerFromModel(model: any): ProviderProfile | undefined {
	const provider = String(model?.provider ?? "").toLowerCase();
	if (provider === "anthropic") return "anthropic";
	if (provider === "openai" || provider === "openai-codex") return "openai";
	return undefined;
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
		// The caller reports the missing target model.
	}
	return [];
}

function findExactModel(ctx: ExtensionContext, config: ModeConfig): any | undefined {
	const registry = getRegistry(ctx);
	try {
		if (typeof registry?.find === "function") {
			const found = registry.find(config.provider, config.model);
			if (found) return found;
		}
	} catch {
		// Fall through to the public model list.
	}
	return listModels(ctx).find(
		(model: any) => model.provider === config.provider && model.id === config.model,
	);
}

function matchingMode(model: any, thinking: string): { provider: ProviderProfile; mode: ModeName } | undefined {
	for (const provider of Object.keys(PROFILES) as ProviderProfile[]) {
		for (const mode of MODE_ORDER) {
			const config = PROFILES[provider][mode];
			if (
				model?.provider === config.provider &&
				model?.id === config.model &&
				thinking === config.thinking
			) {
				return { provider, mode };
			}
		}
	}
	return undefined;
}

function describeModel(model: any | undefined, thinking: string): string {
	if (!model) return `none (thinking: ${thinking})`;
	return `${model.provider}/${model.id} (thinking: ${thinking})`;
}

function publishStatus(
	ctx: ExtensionContext,
	provider: ProviderProfile,
	mode: ModeName,
	custom: boolean,
): void {
	const theme = ctx.ui.theme;
	const marker = PROVIDER_META[provider].marker;
	if (custom) {
		ctx.ui.setStatus("agent-mode", theme.fg("dim", `? custom ${marker}`));
		return;
	}
	const config = PROFILES[provider][mode];
	ctx.ui.setStatus(
		"agent-mode",
		theme.fg(config.color, `${config.icon} ${config.label} ${marker}`),
	);
}

async function applySelection(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	provider: ProviderProfile,
	mode: ModeName,
	currentModel: any,
	currentThinking: string,
	setSwitching: (value: boolean) => void,
): Promise<ApplyResult> {
	if (!ctx.isIdle()) {
		return { ok: false, reason: "Pi is busy; wait for the current run to settle" };
	}

	const config = PROFILES[provider][mode];
	const target = findExactModel(ctx, config);
	if (!target) {
		return {
			ok: false,
			reason: `Required model is unavailable: ${config.provider}/${config.model}`,
		};
	}

	let modelChanged = false;
	setSwitching(true);
	try {
		const switched = await pi.setModel(target);
		if (switched === false) {
			return {
				ok: false,
				reason: `No configured authentication for ${config.provider}/${config.model}`,
			};
		}
		modelChanged = true;
		pi.setThinkingLevel(config.thinking as any);
		const appliedThinking = String(pi.getThinkingLevel?.() ?? config.thinking);
		if (appliedThinking !== config.thinking) {
			throw new Error(`thinking level was clamped to ${appliedThinking}`);
		}
		return { ok: true, model: target, thinking: appliedThinking };
	} catch (error) {
		if (modelChanged && currentModel) {
			try {
				await pi.setModel(currentModel);
				pi.setThinkingLevel(currentThinking as any);
			} catch (rollbackError) {
				return {
					ok: false,
					reason: `Switch failed and rollback also failed: ${String(rollbackError)}`,
				};
			}
		}
		return { ok: false, reason: `Switch failed: ${String(error)}` };
	} finally {
		setSwitching(false);
	}
}

export default function agentModes(pi: ExtensionAPI): void {
	let currentProvider: ProviderProfile = DEFAULT_PROVIDER;
	let currentMode: ModeName = DEFAULT_MODE;
	let liveModel: any | undefined;
	let liveThinking = "medium";
	let custom = false;
	let switching = false;

	const saveState = (ctx: ExtensionContext): void => {
		void persistState({ provider: currentProvider, mode: currentMode }).catch((error) => {
			ctx.ui.notify(`Could not persist agent mode state: ${String(error)}`, "warning");
		});
	};

	const reconcileExternalState = (ctx: ExtensionContext): void => {
		if (switching) return;
		const match = matchingMode(liveModel, liveThinking);
		if (match) {
			currentProvider = match.provider;
			currentMode = match.mode;
			custom = false;
		} else {
			currentProvider = providerFromModel(liveModel) ?? currentProvider;
			custom = true;
		}
		publishStatus(ctx, currentProvider, currentMode, custom);
		saveState(ctx);
	};

	const applyAndCommit = async (
		ctx: ExtensionContext,
		provider: ProviderProfile,
		mode: ModeName,
	): Promise<ApplyResult> => {
		const previousProvider = currentProvider;
		const previousMode = currentMode;
		const previousCustom = custom;
		const result = await applySelection(
			pi,
			ctx,
			provider,
			mode,
			liveModel,
			liveThinking,
			(value) => {
				switching = value;
			},
		);
		if (!result.ok) {
			currentProvider = previousProvider;
			currentMode = previousMode;
			custom = previousCustom;
			liveModel = ctx.model;
			liveThinking = String(pi.getThinkingLevel?.() ?? liveThinking);
			publishStatus(ctx, currentProvider, currentMode, custom);
			return result;
		}

		currentProvider = provider;
		currentMode = mode;
		custom = false;
		liveModel = result.model;
		liveThinking = result.thinking ?? PROFILES[provider][mode].thinking;
		publishStatus(ctx, currentProvider, currentMode, custom);
		await persistState({ provider: currentProvider, mode: currentMode }).catch((error) => {
			ctx.ui.notify(`Mode switched, but state persistence failed: ${String(error)}`, "warning");
		});
		return result;
	};

	pi.on("session_start", async (_event, ctx) => {
		const persisted = await readPersistedState();
		currentProvider = persisted?.provider ?? DEFAULT_PROVIDER;
		currentMode = persisted?.mode ?? DEFAULT_MODE;
		liveModel = ctx.model;
		liveThinking = String(pi.getThinkingLevel?.() ?? "medium");

		const match = matchingMode(liveModel, liveThinking);
		if (match) {
			currentProvider = match.provider;
			currentMode = match.mode;
			custom = false;
		} else {
			currentProvider = providerFromModel(liveModel) ?? currentProvider;
			custom = true;
		}
		publishStatus(ctx, currentProvider, currentMode, custom);
		saveState(ctx);
	});

	pi.on("model_select", async (event, ctx) => {
		liveModel = event.model;
		reconcileExternalState(ctx);
	});

	pi.on("thinking_level_select", async (event, ctx) => {
		liveThinking = String(event.level);
		reconcileExternalState(ctx);
	});

	pi.registerCommand("mode", {
		description: "Switch agent mode (rush / oracle / omnissiah)",
		getArgumentCompletions: (prefix: string) => {
			const items = MODE_ORDER.map((mode) => {
				const config = PROFILES[currentProvider][mode];
				return {
					value: mode,
					label: `${config.icon} ${mode} — ${config.model}, think:${config.thinking}`,
				};
			});
			return items.filter((item) => item.value.startsWith(prefix));
		},
		handler: async (args, ctx) => {
			const rawRequested = (args ?? "").trim().toLowerCase();
			const requested = rawRequested === "deep"
				? "omnissiah"
				: rawRequested === "smart"
					? "oracle"
					: rawRequested;

			if (!requested) {
				const meta = PROVIDER_META[currentProvider];
				ctx.ui.notify(
					`${meta.label} ${meta.marker}${custom ? ` — custom (retained mode: ${currentMode})` : ""}\n` +
						`Using: ${describeModel(liveModel, liveThinking)}\n\n` +
						MODE_ORDER.map((mode) => {
							const config = PROFILES[currentProvider][mode];
							const marker = !custom && mode === currentMode ? "→ " : "  ";
							return `${marker}${config.icon} ${mode}  (${config.provider}/${config.model}, think:${config.thinking})`;
						}).join("\n"),
					"info",
				);
				return;
			}

			if (!isModeName(requested)) {
				ctx.ui.notify(`Unknown mode "${requested}". Available: ${MODE_ORDER.join(", ")}`, "error");
				return;
			}

			const result = await applyAndCommit(ctx, currentProvider, requested);
			if (!result.ok) {
				ctx.ui.notify(
					`Mode switch failed: ${result.reason}\nStill using: ${describeModel(liveModel, liveThinking)}`,
					"error",
				);
				return;
			}

			const config = PROFILES[currentProvider][currentMode];
			ctx.ui.notify(
				`${config.icon} ${config.label} ${PROVIDER_META[currentProvider].marker}\nUsing: ${describeModel(liveModel, liveThinking)}`,
				"info",
			);
		},
	});

	pi.registerShortcut("ctrl+alt+m", {
		description: "Cycle agent mode (rush → oracle → omnissiah)",
		handler: async (ctx) => {
			const targetMode = nextMode(currentMode);
			const result = await applyAndCommit(ctx, currentProvider, targetMode);
			if (!result.ok) {
				ctx.ui.notify(
					`Mode switch failed: ${result.reason}\nStill using: ${describeModel(liveModel, liveThinking)}`,
					"error",
				);
				return;
			}
			const config = PROFILES[currentProvider][currentMode];
			ctx.ui.notify(
				`${config.icon} ${config.label} ${PROVIDER_META[currentProvider].marker}\nUsing: ${describeModel(liveModel, liveThinking)}`,
				"info",
			);
		},
	});

	pi.registerShortcut("ctrl+alt+p", {
		description: "Toggle provider (OpenAI ↔ Anthropic)",
		handler: async (ctx) => {
			const targetProvider = otherProvider(currentProvider);
			const result = await applyAndCommit(ctx, targetProvider, currentMode);
			if (!result.ok) {
				ctx.ui.notify(
					`Provider switch failed: ${result.reason}\nStill using: ${describeModel(liveModel, liveThinking)}`,
					"error",
				);
				return;
			}
			const config = PROFILES[currentProvider][currentMode];
			ctx.ui.notify(
				`${PROVIDER_META[currentProvider].label} ${PROVIDER_META[currentProvider].marker}\n` +
					`${config.icon} ${config.label} — ${describeModel(liveModel, liveThinking)}`,
				"info",
			);
		},
	});
}
