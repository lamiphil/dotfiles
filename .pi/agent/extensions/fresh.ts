/**
 * /fresh [name]
 *
 * Show a session picker, clone the selected session, and optionally name it.
 * Saves the 3-step /resume → /clone → /name flow.
 *
 *   /fresh                Pick a session, clone it, start working
 *   /fresh my-feature     Pick a session, clone it, name it "my-feature"
 */

import { SessionManager, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("fresh", {
		description: "Clone a previous session and start fresh (like /resume + /clone + /name)",
		handler: async (args, ctx) => {
			const name = (args ?? "").trim() || undefined;

			// List all sessions for this project
			const sessions = await SessionManager.list(ctx.cwd);
			if (sessions.length === 0) {
				ctx.ui.notify("No sessions found.", "warning");
				return;
			}

			// Build display labels: name or first message, with date
			const labels = sessions.map((s) => {
				const label = s.name || s.id;
				const date = s.modified.toLocaleDateString("en-US", {
					month: "short",
					day: "numeric",
					hour: "2-digit",
					minute: "2-digit",
				});
				return `${label}  (${date})`;
			});

			const pick = await ctx.ui.select("Clone which session?", labels);
			if (!pick) {
				ctx.ui.notify("Cancelled.", "info");
				return;
			}

			const idx = labels.indexOf(pick);
			const selected = sessions[idx];

			// Switch to the selected session, then fork (clone) at its leaf
			await ctx.switchSession(selected.path, {
				withSession: async (rctx) => {
					const leafId = rctx.sessionManager.getLeafId();
					if (!leafId) {
						rctx.ui.notify("Session has no entries to clone.", "error");
						return;
					}

					const result = await rctx.fork(leafId, { position: "at" });
					if (result.cancelled) {
						rctx.ui.notify("Clone cancelled.", "info");
						return;
					}

					if (name) {
						pi.setSessionName(name);
					}

					rctx.ui.notify(
						name ? `Cloned → ${name}` : "Cloned session. Use /name to rename.",
						"success",
					);
				},
			});
		},
	});
}
