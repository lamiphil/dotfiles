/**
 * Concise mode toggle — pi defaults to terse responses (driven by
 * ~/.pi/agent/APPEND_SYSTEM.md). Prefixing a prompt with `?v ` strips the
 * prefix and injects a one-turn system-prompt suffix that overrides the
 * brevity rules for that turn only.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const VERBOSE_PREFIX = "?v ";

const VERBOSE_OVERRIDE = `

## Communication style — verbose mode (this turn only)

The user prefixed their message with \`?v\`. For this turn ONLY, ignore the
"Communication style" brevity rules from APPEND_SYSTEM.md and AGENTS.md.

Expand fully:
- Recap what's about to happen and why.
- Show alternative approaches and their trade-offs when relevant.
- Surface adjacent issues you noticed that the user might want to know about.
- Add a closing "Want me to also…?" with concrete follow-up options when natural.
`;

let verboseTurn = false;

export default function (pi: ExtensionAPI) {
	pi.on("input", async (event) => {
		if (event.text.startsWith(VERBOSE_PREFIX)) {
			verboseTurn = true;
			return { action: "transform", text: event.text.slice(VERBOSE_PREFIX.length) };
		}
		return { action: "continue" };
	});

	pi.on("before_agent_start", async (event) => {
		if (!verboseTurn) return;
		verboseTurn = false; // one-shot
		return { systemPrompt: event.systemPrompt + VERBOSE_OVERRIDE };
	});
}
