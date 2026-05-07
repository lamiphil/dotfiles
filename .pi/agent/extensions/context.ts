/**
 * /context
 *
 * Print the current context window, token usage, and cumulative cost for the
 * active session.
 *
 *   /context              Show a compact summary in a notification
 *   /context detail       Same, but with the per-bucket breakdown
 *                         (input / output / cache read / cache write).
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function fmtNum(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 1_000_000) return `${(n / 1000).toFixed(1)}K`;
	return `${(n / 1_000_000).toFixed(2)}M`;
}

function fmtCost(c: number): string {
	if (c === 0) return "$0";
	if (c < 0.01) return `$${c.toFixed(4)}`;
	if (c < 1) return `$${c.toFixed(3)}`;
	return `$${c.toFixed(2)}`;
}

function bar(percent: number, width = 24): string {
	if (!Number.isFinite(percent) || percent < 0) percent = 0;
	if (percent > 100) percent = 100;
	const filled = Math.round((percent / 100) * width);
	return "█".repeat(filled) + "░".repeat(width - filled);
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("context", {
		description: "Show context window, token usage, and cost for this session",
		getArgumentCompletions: (prefix: string) => {
			const items = [{ value: "detail", label: "detail — show per-bucket breakdown" }];
			const filtered = items.filter((i) => i.value.startsWith(prefix));
			return filtered.length > 0 ? filtered : null;
		},
		handler: async (rawArgs, ctx) => {
			const detail = (rawArgs ?? "").trim().toLowerCase() === "detail";

			// Context window + current usage (estimated by pi).
			const usage = ctx.getContextUsage?.();
			const window = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
			const used = usage?.tokens ?? null;
			const pct = usage?.percent ?? null;

			// Cumulative session totals from assistant messages.
			let totalIn = 0,
				totalOut = 0,
				totalCacheRead = 0,
				totalCacheWrite = 0,
				totalCost = 0,
				assistantTurns = 0;

			for (const e of ctx.sessionManager.getBranch()) {
				if (e.type !== "message" || e.message.role !== "assistant") continue;
				const m = e.message as AssistantMessage;
				totalIn += m.usage.input;
				totalOut += m.usage.output;
				totalCacheRead += m.usage.cacheRead ?? 0;
				totalCacheWrite += m.usage.cacheWrite ?? 0;
				totalCost += m.usage.cost.total;
				assistantTurns++;
			}

			const modelId = ctx.model
				? `${ctx.model.provider}/${ctx.model.id}`
				: "no model";

			const lines: string[] = [];
			lines.push(`Model:    ${modelId}`);
			lines.push(`Window:   ${fmtNum(window)} tokens`);
			if (used != null && pct != null) {
				lines.push(
					`Used:     ${fmtNum(used)}  (${pct.toFixed(1)}%)  [${bar(pct)}]`,
				);
				lines.push(`Free:     ${fmtNum(Math.max(0, window - used))} tokens`);
			} else {
				lines.push(`Used:     —  (no assistant message yet)`);
			}
			lines.push("");
			lines.push(`Cost:        ${fmtCost(totalCost)}  over ${assistantTurns} turn${assistantTurns === 1 ? "" : "s"}`);
			lines.push(`Cache read:  ${fmtNum(totalCacheRead)} tokens`);

			if (detail) {
				lines.push("");
				lines.push("Cumulative tokens (all turns):");
				lines.push(`  input        ${fmtNum(totalIn)}`);
				lines.push(`  output       ${fmtNum(totalOut)}`);
				lines.push(`  cache read   ${fmtNum(totalCacheRead)}`);
				lines.push(`  cache write  ${fmtNum(totalCacheWrite)}`);
			}

			ctx.ui.notify(lines.join("\n"), "info");
		},
	});
}
