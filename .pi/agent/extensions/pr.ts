/**
 * /pr  [auto]
 *
 * Open a PR via `gh pr create`, with a friendly approve/edit flow.
 *
 *   /pr           Prompts for title (single line), then description (editor),
 *                 then creates the PR.
 *
 *   /pr auto      Auto-generates title + description from the branch's commits
 *                 (vs. the detected base branch), opens both in an editor for
 *                 you to approve or edit, then creates the PR on save.
 *                 Cancel by saving an empty buffer.
 *
 * After creation, the PR URL is printed and copied to the clipboard (best-effort).
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { spawnSync } from "node:child_process";

interface ExecOk {
	stdout: string;
	stderr: string;
	exitCode: number;
}

async function run(
	pi: ExtensionAPI,
	cmd: string,
	args: string[],
	cwd?: string,
): Promise<ExecOk> {
	const r = await pi.exec(cmd, args, { cwd });
	return {
		stdout: (r.stdout ?? "").toString(),
		stderr: (r.stderr ?? "").toString(),
		exitCode: r.code ?? 0,
	};
}

async function detectBase(pi: ExtensionAPI, cwd: string): Promise<string> {
	// Prefer the remote's default branch.
	const sym = await run(pi, "git", ["symbolic-ref", "refs/remotes/origin/HEAD"], cwd);
	if (sym.exitCode === 0) {
		const m = sym.stdout.trim().match(/refs\/remotes\/origin\/(.+)$/);
		if (m) return m[1];
	}
	// Fallbacks
	for (const b of ["main", "master", "develop"]) {
		const r = await run(pi, "git", ["rev-parse", "--verify", `origin/${b}`], cwd);
		if (r.exitCode === 0) return b;
	}
	return "main";
}

async function currentBranch(pi: ExtensionAPI, cwd: string): Promise<string> {
	const r = await run(pi, "git", ["branch", "--show-current"], cwd);
	return r.stdout.trim();
}

// Conventional Commits subject: <type>(<scope>): <description>
//   - type   = chore | feat | fix   (per the user's tight spec)
//   - scope  = optional, lowercase
const CONVENTIONAL_RE = /^(chore|feat|fix)(\([^)]+\))?(!)?:\s+\S/;

function inferTypeFromPaths(paths: string[]): "chore" | "feat" | "fix" {
	const joined = paths.join("\n").toLowerCase();
	// Heuristic: filenames mentioning "fix" / "bug" → fix; otherwise default to chore
	// (we can't reliably infer feat without reading the diff content; the agent
	// can do that via `/commit`. PR auto stays conservative.)
	if (/\bfix\b|\bbug\b|\bhotfix\b/.test(joined)) return "fix";
	return "chore";
}

function inferScopeFromPaths(paths: string[]): string | undefined {
	if (paths.length === 0) return undefined;
	// Pick the most common top-level directory as the scope.
	const freq = new Map<string, number>();
	for (const p of paths) {
		const seg = p.split("/")[0];
		if (!seg || seg.startsWith(".")) continue; // skip dotfiles segments like .pi, .config
		freq.set(seg, (freq.get(seg) ?? 0) + 1);
	}
	let best: { seg: string; n: number } | undefined;
	for (const [seg, n] of freq) {
		if (!best || n > best.n) best = { seg, n };
	}
	return best?.seg.toLowerCase();
}

function toConventionalSubject(
	subject: string,
	fallbackPaths: string[],
): string {
	const trimmed = subject.trim();
	if (CONVENTIONAL_RE.test(trimmed)) return trimmed;

	// Existing dotfiles convention: "SCOPE - Description"
	const scoped = trimmed.match(/^([A-Z][A-Z0-9_]*)\s+-\s+(.+)$/);
	if (scoped) {
		const [, rawScope, rawDesc] = scoped;
		const scope = rawScope.toLowerCase();
		const desc = rawDesc.charAt(0).toLowerCase() + rawDesc.slice(1);
		return `chore(${scope}): ${desc}`;
	}

	const type = inferTypeFromPaths(fallbackPaths);
	const scope = inferScopeFromPaths(fallbackPaths);
	const desc = trimmed.charAt(0).toLowerCase() + trimmed.slice(1);
	return scope ? `${type}(${scope}): ${desc}` : `${type}: ${desc}`;
}

async function generateTitleAndBody(
	pi: ExtensionAPI,
	cwd: string,
	base: string,
): Promise<{ title: string; body: string }> {
	// Title: subject of the most recent commit on this branch.
	const subj = await run(pi, "git", ["log", "-1", "--pretty=%s"], cwd);
	const rawTitle = subj.stdout.trim();

	// File paths changed against the base — used to infer type/scope when the
	// commit subject isn't already conventional.
	const names = await run(
		pi,
		"git",
		["diff", "--name-only", `${base}...HEAD`],
		cwd,
	);
	const paths = names.stdout
		.split("\n")
		.map((s) => s.trim())
		.filter((s) => s.length > 0);

	const title = toConventionalSubject(rawTitle, paths);

	// Body: oneline log of commits ahead of base, plus a brief diffstat.
	const log = await run(
		pi,
		"git",
		["log", `${base}..HEAD`, "--pretty=- %s"],
		cwd,
	);
	const stat = await run(pi, "git", ["diff", "--stat", `${base}...HEAD`], cwd);

	const commits = log.stdout.trim();
	const stats = stat.stdout.trim();

	const body =
		`## Summary\n\n` +
		(commits ? `${commits}\n\n` : `_(no commits ahead of \`${base}\`)_\n\n`) +
		`## Changes\n\n` +
		"```\n" +
		(stats || "(no diff)") +
		"\n```\n";

	return { title: title || `Update from ${await currentBranch(pi, cwd)}`, body };
}

function parseTitleAndBody(text: string): { title: string; body: string } | undefined {
	const trimmed = text.replace(/^\s+|\s+$/g, "");
	if (!trimmed) return undefined;
	const lines = trimmed.split("\n");
	const title = (lines.shift() ?? "").trim();
	if (!title) return undefined;
	// Skip a single blank separator line, but keep the rest verbatim.
	if (lines.length && lines[0].trim() === "") lines.shift();
	return { title, body: lines.join("\n") };
}

async function ghPrCreate(
	pi: ExtensionAPI,
	cwd: string,
	title: string,
	body: string,
): Promise<{ ok: true; url: string } | { ok: false; error: string }> {
	const r = await run(pi, "gh", ["pr", "create", "--title", title, "--body", body], cwd);
	if (r.exitCode !== 0) {
		return { ok: false, error: (r.stderr || r.stdout).trim() };
	}
	const url = r.stdout.trim().split("\n").pop() ?? "";
	return { ok: true, url };
}

function copyToClipboard(text: string): void {
	try {
		spawnSync("pbcopy", [], { input: text });
	} catch {
		// best-effort; silent on failure (Linux without xclip, etc.)
	}
}

async function preflight(pi: ExtensionAPI, ctx: ExtensionCommandContext): Promise<boolean> {
	const repo = await run(pi, "git", ["rev-parse", "--show-toplevel"], ctx.cwd);
	if (repo.exitCode !== 0) {
		ctx.ui.notify("Not inside a git repository.", "error");
		return false;
	}
	const gh = await run(pi, "gh", ["--version"], ctx.cwd);
	if (gh.exitCode !== 0) {
		ctx.ui.notify("`gh` (GitHub CLI) not found in PATH.", "error");
		return false;
	}
	return true;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("pr", {
		description: "Open a GitHub PR (use `/pr auto` to pre-fill from commits)",
		getArgumentCompletions: (prefix: string) => {
			const items = [{ value: "auto", label: "auto — pre-fill from branch commits" }];
			const filtered = items.filter((i) => i.value.startsWith(prefix));
			return filtered.length > 0 ? filtered : null;
		},
		handler: async (args, ctx) => {
			if (!(await preflight(pi, ctx))) return;

			const mode = (args ?? "").trim().toLowerCase();
			const cwd = ctx.cwd;
			const base = await detectBase(pi, cwd);
			const branch = await currentBranch(pi, cwd);

			if (!branch || branch === base) {
				ctx.ui.notify(
					`You are on the base branch (${base}). Switch to a feature branch first.`,
					"warning",
				);
				return;
			}

			let title: string;
			let body: string;

			// Pre-compute changed paths once — used to infer type/scope when the
			// title isn't already in conventional commits format.
			const names = await run(pi, "git", ["diff", "--name-only", `${base}...HEAD`], cwd);
			const paths = names.stdout
				.split("\n")
				.map((s) => s.trim())
				.filter((s) => s.length > 0);

			if (mode === "auto") {
				const gen = await generateTitleAndBody(pi, cwd, base);
				const reviewed = await ctx.ui.editor(
					`Review PR (base: ${base}) — first line is the title in <type>(<scope>): <description> format. Save empty to cancel.`,
					`${gen.title}\n\n${gen.body}`,
				);
				const parsed = parseTitleAndBody(reviewed ?? "");
				if (!parsed) {
					ctx.ui.notify("PR cancelled.", "info");
					return;
				}
				// In case the user edited the title away from conventional format.
				title = toConventionalSubject(parsed.title, paths);
				body = parsed.body;
			} else {
				const t = await ctx.ui.input(
					"PR title  —  format: <type>(<scope>): <description>",
					"feat(auth): add login page",
				);
				const rawTitle = (t ?? "").trim();
				if (!rawTitle) {
					ctx.ui.notify("PR cancelled (no title).", "info");
					return;
				}
				title = toConventionalSubject(rawTitle, paths);
				if (title !== rawTitle) {
					ctx.ui.notify(`Title normalized to:\n  ${title}`, "info");
				}
				const b = await ctx.ui.editor(
					`PR description (base: ${base}). Markdown supported. Save empty to cancel.`,
					"",
				);
				body = (b ?? "").trim();
				if (!body) {
					ctx.ui.notify("PR cancelled (no description).", "info");
					return;
				}
			}

			ctx.ui.notify(`Creating PR against ${base}…`, "info");
			const result = await ghPrCreate(pi, cwd, title, body);
			if (!result.ok) {
				ctx.ui.notify(`gh pr create failed:\n${result.error}`, "error");
				return;
			}
			copyToClipboard(result.url);
			ctx.ui.notify(`✓ PR opened: ${result.url} (copied to clipboard)`, "success");
		},
	});
}
