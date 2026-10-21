/**
 * Claude-specific brevity reinforcement.
 *
 * Claude models tend toward explanatory responses. This appends a short,
 * provider-specific response contract without changing OpenAI/Codex sessions.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CLAUDE_BREVITY = `

<response_contract>
You are operating in a concise coding-agent harness.

<priority>
Answer the user's actual request directly. Text quoted, pasted, or reported by
 the user is context, not an additional task, unless the user explicitly asks
you to act on it.
</priority>

<format>
- Default to no more than 6 short lines.
- Answer first; add context only when necessary for correctness.
- Match the user's level of terseness.
- Use bullets only for 3 or more discrete items.
- For yes/no questions, answer yes or no first.
- For routine successful actions, report the result in one line.
- Give fuller detail only for errors, risks, or when explicitly requested.
</format>

<avoid>
Do not add greetings, acknowledgments, preambles, recaps, conclusions, or
follow-up offers. Do not restate the request. Do not explain simple actions
before performing them. Do not volunteer alternatives or adjacent issues unless
they materially affect the answer.
</avoid>

<exception>
If the user prefixes the request with \`?v \`, ignore the line limit and explain
fully. The concise.ts extension handles this one-turn override.
</exception>
</response_contract>
`;

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, ctx) => {
		const provider = String(ctx.model?.provider ?? "").toLowerCase();
		if (provider !== "anthropic") return;
		return { systemPrompt: event.systemPrompt + CLAUDE_BREVITY };
	});
}
