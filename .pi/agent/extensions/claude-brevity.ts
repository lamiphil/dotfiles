/**
 * Claude-specific brevity reinforcement.
 *
 * Claude models tend toward explanatory responses. The rules live only in
 * APPEND_SYSTEM.md <communication_style>; this appends a one-line reminder at
 * the end of the prompt (recency) for Claude providers only.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CLAUDE_BREVITY = `

Reminder: follow <communication_style> strictly, including its examples. Result first, no headings in short replies, no explanation of why unless asked.
`;

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, ctx) => {
		const provider = String(ctx.model?.provider ?? "").toLowerCase();
		if (provider !== "anthropic" && provider !== "claude-code") return;
		return { systemPrompt: event.systemPrompt + CLAUDE_BREVITY };
	});
}
