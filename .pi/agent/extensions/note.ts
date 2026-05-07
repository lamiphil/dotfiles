/**
 * /note <text>           Append a timestamped line to today's daily journal
 *                        in the currently active vault.
 *
 * /note                  (no args) → prompt for the line via input box.
 *
 * /note vault            Show the active vault and the list of known vaults.
 * /note vault <name>     Switch the active vault (`personal` | `botpress`).
 *                        Persists across sessions. Updates the powerline
 *                        status segment.
 *
 * /todo a, b, c          Insert one or more todos at the TOP of today's
 *                        `## Todos` section in the active vault. Comma
 *                        separated. Each becomes `- [ ] <text>`.
 *
 * /todo                  (no args) → prompt for the comma list via input box.
 *
 * Daily notes use the existing template:
 *
 *     **YYYY-MM-DD | HH:MM**
 *     <text>
 *
 * Inserted under `## Logs`, before the `### Meetings` / `### Issues` dataview
 * blocks. Today's note is created from the standard template if missing.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

// ── Vault registry ──────────────────────────────────────────────────────────

const HOME = process.env.HOME ?? "";

const VAULTS: Record<string, string> = {
	personal: `${HOME}/workspaces/personal/personal`,
	botpress: `${HOME}/workspaces/botpress/notes`,
};

const DEFAULT_VAULT = "personal";

const STATE_DIR = `${HOME}/.pi/agent/state`;
const STATE_FILE = join(STATE_DIR, "note-vault.txt");

function readActiveVault(): string {
	try {
		if (existsSync(STATE_FILE)) {
			const v = readFileSync(STATE_FILE, "utf8").trim();
			if (v && VAULTS[v]) return v;
		}
	} catch {
		/* fallthrough */
	}
	return DEFAULT_VAULT;
}

function writeActiveVault(name: string): void {
	mkdirSync(STATE_DIR, { recursive: true });
	writeFileSync(STATE_FILE, `${name}\n`, "utf8");
}

// Nerd Font journal-ish glyph (nf-md-notebook).
const VAULT_ICON = "\u{F0E59}";

function publishVaultStatus(ctx: ExtensionContext): void {
	const vault = readActiveVault();
	const thm = ctx.ui.theme;
	ctx.ui.setStatus(
		"note-vault",
		thm.fg("accent", VAULT_ICON) + thm.fg("dim", " vault ") + thm.fg("text", vault),
	);
}

// ── Daily note plumbing ─────────────────────────────────────────────────────

const DAILY_TEMPLATE = (iso: string) => `---
date: ${iso}
tags:
  - journal
---
# ${iso}
## Todos


## Logs

### Meetings
\`\`\`dataview
LIST
FROM "Meetings"
WHERE date = this.file.day
\`\`\`

### Issues
\`\`\`dataview
LIST
FROM "Issues"
WHERE file.mday = this.file.day
\`\`\`
`;

const pad = (n: number) => (n < 10 ? `0${n}` : `${n}`);

function todayParts() {
	const d = new Date();
	const year = `${d.getFullYear()}`;
	const month = pad(d.getMonth() + 1);
	const day = pad(d.getDate());
	const iso = `${year}-${month}-${day}`;
	const monthFolder = `${month} - ${d.toLocaleString("en-US", { month: "long" })}`;
	const hhmm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
	return { iso, year, monthFolder, hhmm };
}

function dailyNotePath(vaultRoot: string): string {
	const { iso, year, monthFolder } = todayParts();
	return join(vaultRoot, "Journal", year, monthFolder, `${iso}.md`);
}

function ensureDailyNote(path: string, iso: string): void {
	if (existsSync(path)) return;
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, DAILY_TEMPLATE(iso), "utf8");
}

/** Insert `newLines` immediately after a heading matching `headingRe`. */
function insertAfterHeading(content: string, headingRe: RegExp, newLines: string[]): string {
	const lines = content.split("\n");
	const idx = lines.findIndex((l) => headingRe.test(l.trim()));
	if (idx === -1) return content;

	// Skip a single blank line that often follows the heading, so todos are
	// inserted as the first "real" content under the heading.
	let insertAt = idx + 1;
	while (insertAt < lines.length && lines[insertAt].trim() === "") insertAt++;

	const before = lines.slice(0, insertAt);
	const after = lines.slice(insertAt);
	return [...before, ...newLines, ...after].join("\n");
}

/** Append `entry` under `## Logs`, before the next `###` / `##` heading. */
function insertUnderLogs(content: string, entry: string): string {
	const lines = content.split("\n");
	const logsIdx = lines.findIndex((l) => l.trim() === "## Logs");
	if (logsIdx === -1) {
		const trimmed = content.replace(/\s+$/, "");
		return `${trimmed}\n\n## Logs\n\n${entry}\n`;
	}

	let endIdx = lines.length;
	for (let i = logsIdx + 1; i < lines.length; i++) {
		const l = lines[i].trim();
		if (l.startsWith("### ") || l.startsWith("## ")) {
			endIdx = i;
			break;
		}
	}

	let insertAt = endIdx;
	while (insertAt > logsIdx + 1 && lines[insertAt - 1].trim() === "") insertAt--;

	const before = lines.slice(0, insertAt);
	const after = lines.slice(insertAt);
	const sepBefore = before.length && before[before.length - 1].trim() !== "" ? [""] : [];
	const sepAfter = after.length && after[0].trim() !== "" ? [""] : [];
	return [...before, ...sepBefore, entry, ...sepAfter, ...after].join("\n");
}

// ── Handlers ────────────────────────────────────────────────────────────────

async function appendNote(ctx: ExtensionContext, text: string): Promise<void> {
	const vault = readActiveVault();
	const vaultRoot = VAULTS[vault];
	const { iso, hhmm } = todayParts();
	const path = dailyNotePath(vaultRoot);
	try {
		ensureDailyNote(path, iso);
		const current = readFileSync(path, "utf8");
		const entry = `**${iso} | ${hhmm}**\n${text}`;
		const updated = insertUnderLogs(current, entry);
		writeFileSync(path, updated, "utf8");
		ctx.ui.notify(`Logged to ${vault}/${iso}.md`, "success");
	} catch (err) {
		ctx.ui.notify(`Failed to write daily note: ${(err as Error).message}`, "error");
	}
}

async function prependTodos(ctx: ExtensionContext, items: string[]): Promise<void> {
	const vault = readActiveVault();
	const vaultRoot = VAULTS[vault];
	const { iso } = todayParts();
	const path = dailyNotePath(vaultRoot);
	try {
		ensureDailyNote(path, iso);
		const current = readFileSync(path, "utf8");
		const newLines = items.map((it) => `- [ ] ${it}`);
		const updated = insertAfterHeading(current, /^## Todos\s*$/, newLines);
		if (updated === current) {
			ctx.ui.notify(`Could not find "## Todos" heading in today's note.`, "error");
			return;
		}
		writeFileSync(path, updated, "utf8");
		ctx.ui.notify(
			`Added ${items.length} todo${items.length === 1 ? "" : "s"} to ${vault}/${iso}.md`,
			"success",
		);
	} catch (err) {
		ctx.ui.notify(`Failed to update todos: ${(err as Error).message}`, "error");
	}
}

function vaultListPretty(active: string): string {
	return Object.entries(VAULTS)
		.map(([name, root]) =>
			name === active
				? `  • ${name}  ← active   (${root.replace(HOME, "~")})`
				: `    ${name}            (${root.replace(HOME, "~")})`,
		)
		.join("\n");
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		publishVaultStatus(ctx);
	});

	pi.registerCommand("note", {
		description:
			"Append a timestamped line to today's daily note (use `/note vault <name>` to switch)",
		getArgumentCompletions: (prefix: string) => {
			const tokens = prefix.split(/\s+/);
			// Suggest the `vault` keyword at the first token.
			if (tokens.length <= 1) {
				const items = [{ value: "vault", label: "vault — switch / show active vault" }];
				const filtered = items.filter((i) => i.value.startsWith(tokens[0] ?? ""));
				return filtered.length > 0 ? filtered : null;
			}
			// Suggest vault names after `vault `.
			if (tokens[0] === "vault" && tokens.length === 2) {
				const items = Object.keys(VAULTS).map((name) => ({ value: name, label: name }));
				const filtered = items.filter((i) => i.value.startsWith(tokens[1] ?? ""));
				return filtered.length > 0 ? filtered : null;
			}
			return null;
		},
		handler: async (rawArgs, ctx) => {
			const args = (rawArgs ?? "").trim();
			const tokens = args.length ? args.split(/\s+/) : [];

			// `/note vault [name]`
			if (tokens[0] === "vault") {
				const name = tokens[1];
				if (!name) {
					const active = readActiveVault();
					ctx.ui.notify(`Active vault: ${active}\n\n${vaultListPretty(active)}`, "info");
					return;
				}
				if (!VAULTS[name]) {
					ctx.ui.notify(
						`Unknown vault "${name}". Known: ${Object.keys(VAULTS).join(", ")}`,
						"error",
					);
					return;
				}
				if (!existsSync(VAULTS[name])) {
					ctx.ui.notify(
						`Vault path does not exist: ${VAULTS[name]}\nSwitched anyway.`,
						"warning",
					);
				}
				writeActiveVault(name);
				publishVaultStatus(ctx);
				ctx.ui.notify(`Vault → ${name}  (${VAULTS[name].replace(HOME, "~")})`, "success");
				return;
			}

			// `/note <text>` or `/note`
			let text = args;
			if (!text) {
				const input = await ctx.ui.input(
					"Note",
					"Line to append (timestamp added automatically)",
				);
				text = (input ?? "").trim();
				if (!text) {
					ctx.ui.notify("Cancelled — no text provided", "info");
					return;
				}
			}

			await appendNote(ctx, text);
		},
	});

	pi.registerCommand("todo", {
		description: "Prepend comma-separated todos to today's `## Todos` list (active vault)",
		handler: async (rawArgs, ctx) => {
			let raw = (rawArgs ?? "").trim();
			if (!raw) {
				const input = await ctx.ui.input(
					"Todos",
					"Comma-separated, e.g. fix DNS, deploy portfolio, review PR",
				);
				raw = (input ?? "").trim();
				if (!raw) {
					ctx.ui.notify("Cancelled — no todos provided", "info");
					return;
				}
			}
			const items = raw
				.split(",")
				.map((s) => s.trim())
				.filter((s) => s.length > 0);
			if (items.length === 0) {
				ctx.ui.notify("No non-empty entries after splitting on `,`.", "warning");
				return;
			}
			await prependTodos(ctx, items);
		},
	});
}
