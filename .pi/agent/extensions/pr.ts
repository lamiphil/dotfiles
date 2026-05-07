/**
 * /pr  [<repo-path>]
 *
 * Open a PR via `gh pr create`, with a friendly approve/edit flow.
 *
 * Auto-generates a conventional-commits title and a `## Changes` body from
 * the branch's commits vs. the detected base branch, opens both in an editor
 * for you to approve or edit, then creates the PR on save. Cancel by saving
 * an empty buffer.
 *
 *   /pr                 Operate on the current repo (or pick one if cwd holds
 *                       multiple).
 *   /pr <path>          Operate on the repo at <path>. Path may be relative to
 *                       pi's cwd or absolute; `~` is expanded.
 *
 * Repo resolution (when no explicit path is given):
 *   1. If pi's cwd is itself a git repo, use it.
 *   2. Else scan immediate subdirectories for git repos.
 *      - exactly one  → use it (and tell the user)
 *      - multiple     → select dialog
 *      - none         → confirm error so the message stays visible
 *
 * After creation, the PR URL is printed and copied to the clipboard (best-effort).
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { readdirSync, statSync } from "node:fs";
import { isAbsolute, join, resolve as resolvePath } from "node:path";

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
	// can do that via `/commit`. We stay conservative here.)
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

// Strip conventional-commits prefix (`feat(scope): `) from a subject.
function stripConventionalPrefix(subject: string): string {
	return subject.replace(/^(chore|feat|fix)(\([^)]+\))?(!)?:\s+/, "");
}

function capitalizeFirst(s: string): string {
	return s.length === 0 ? s : s.charAt(0).toUpperCase() + s.slice(1);
}

// Imperative → 3rd-person singular ("add" → "adds", "fix" → "fixes").
// Covers regular English -s/-es/-ies rules; good enough for commit verbs.
function conjugate3rdPersonSingular(verb: string): string {
	const v = verb.toLowerCase();
	if (v.endsWith("y") && v.length > 1 && !"aeiou".includes(v[v.length - 2])) {
		return v.slice(0, -1) + "ies";
	}
	if (
		v.endsWith("s") ||
		v.endsWith("x") ||
		v.endsWith("z") ||
		v.endsWith("ch") ||
		v.endsWith("sh")
	) {
		return v + "es";
	}
	return v + "s";
}

// Build the lead sentence from the title:
//   "feat(foundation): add dab-deployer SA"
//   → "This PR adds dab-deployer SA."
function titleToLeadSentence(title: string): string {
	const desc = stripConventionalPrefix(title).trim();
	if (!desc) return "This PR introduces the changes below.";
	const [first, ...rest] = desc.split(/\s+/);
	const conjugated = conjugate3rdPersonSingular(first);
	const tail = rest.join(" ");
	const sentence = tail ? `This PR ${conjugated} ${tail}` : `This PR ${conjugated}`;
	return sentence.replace(/[.!?]+$/, "") + ".";
}

// Turn a commit subject into a Summary bullet:
//   "feat(foundation): add dab-deployer SA" → "Add dab-deployer SA"
function commitToBullet(subject: string): string {
	return capitalizeFirst(stripConventionalPrefix(subject).trim());
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

	// Body: lead sentence derived from the title. For single-commit PRs the
	// bullet would just restate the lead, so we emit only the sentence —
	// matching the user's pattern for short PRs (e.g. "Title says all" /
	// one-line bodies). For multi-commit PRs we add a `## Changes` section
	// (h2, matching the PR #3292 reference).
	const log = await run(
		pi,
		"git",
		["log", `${base}..HEAD`, "--reverse", "--no-merges", "--pretty=%s"],
		cwd,
	);
	const subjects = log.stdout
		.split("\n")
		.map((s) => s.trim())
		.filter((s) => s.length > 0);

	const lead = titleToLeadSentence(title || rawTitle);
	const bullets = subjects.map((s) => `- ${commitToBullet(s)}`).join("\n");

	let body: string;
	if (subjects.length === 0) {
		body = `${lead}\n\n_(no commits ahead of \`${base}\`)_\n`;
	} else if (subjects.length === 1) {
		body = `${lead}\n`;
	} else {
		body = `${lead}\n\n## Changes\n${bullets}\n`;
	}

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

function expandTilde(p: string): string {
	if (p === "~") return process.env.HOME ?? p;
	if (p.startsWith("~/")) return join(process.env.HOME ?? "", p.slice(2));
	return p;
}

function resolveAgainst(cwd: string, p: string): string {
	const expanded = expandTilde(p);
	return isAbsolute(expanded) ? expanded : resolvePath(cwd, expanded);
}

async function isGitRepo(pi: ExtensionAPI, path: string): Promise<string | undefined> {
	const r = await run(pi, "git", ["rev-parse", "--show-toplevel"], path);
	return r.exitCode === 0 ? r.stdout.trim() : undefined;
}

/**
 * Find git repos under `dir` up to `maxDepth` levels deep.
 * Each found repo terminates that branch (we never descend into a repo).
 * Hidden directories (dotfiles) are skipped except when `dir` itself is one.
 */
async function findChildRepos(
	pi: ExtensionAPI,
	dir: string,
	maxDepth = 2,
): Promise<string[]> {
	const hits: string[] = [];

	const walk = async (current: string, depth: number): Promise<void> => {
		if (depth > maxDepth) return;
		let entries: string[];
		try {
			entries = readdirSync(current);
		} catch {
			return;
		}
		for (const name of entries) {
			if (name.startsWith(".")) continue;
			const full = join(current, name);
			try {
				if (!statSync(full).isDirectory()) continue;
			} catch {
				continue;
			}
			const top = await isGitRepo(pi, full);
			if (top && top === full) {
				hits.push(top);
				// Don't descend into a repo — submodules / nested repos rarely
				// host the PR you want.
				continue;
			}
			await walk(full, depth + 1);
		}
	};

	await walk(dir, 1);
	return hits.sort();
}

/** Resolve which repo `/pr` should operate on, given parsed args. */
async function resolveRepo(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	explicitPath: string | undefined,
): Promise<string | undefined> {
	// 1. Explicit path argument.
	if (explicitPath) {
		const abs = resolveAgainst(ctx.cwd, explicitPath);
		const top = await isGitRepo(pi, abs);
		if (!top) {
			await ctx.ui.confirm(
				"PR aborted",
				`The path you supplied is not a git repository:\n  ${abs}`,
			);
			return undefined;
		}
		return top;
	}

	// 2. cwd itself is a repo.
	const cwdTop = await isGitRepo(pi, ctx.cwd);
	if (cwdTop) return cwdTop;

	// 3. Scan immediate subdirectories.
	const children = await findChildRepos(pi, ctx.cwd);
	if (children.length === 0) {
		await ctx.ui.confirm(
			"PR aborted",
			`pi's cwd is not a git repository and no git repos were found in:\n  ${ctx.cwd}\n\n` +
				`Either:\n` +
				`  • cd into a repo and re-run pi, or\n` +
				`  • invoke as: /pr <repo-path>`,
		);
		return undefined;
	}
	if (children.length === 1) {
		ctx.ui.notify(`Using ${children[0].replace(process.env.HOME ?? "", "~")}`, "info");
		return children[0];
	}
	const pretty = children.map((p) => p.replace(process.env.HOME ?? "", "~"));
	const pick = await ctx.ui.select("Which repository?", pretty);
	if (!pick) return undefined;
	const idx = pretty.indexOf(pick);
	return children[idx];
}

/** Parse args. Supports: "", "<path>". Extra tokens are ignored. */
function parseArgs(raw: string): { path: string | undefined } {
	const tokens = raw.trim().split(/\s+/).filter(Boolean);
	return { path: tokens[0] };
}

async function preflight(pi: ExtensionAPI, ctx: ExtensionCommandContext): Promise<boolean> {
	const gh = await run(pi, "gh", ["--version"], ctx.cwd);
	if (gh.exitCode !== 0) {
		await ctx.ui.confirm(
			"PR aborted",
			"`gh` (GitHub CLI) not found in PATH. Install it first: brew install gh",
		);
		return false;
	}
	return true;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("pr", {
		description: "Open a GitHub PR (auto-fills title + description from branch commits)",
		handler: async (args, ctx) => {
			if (!(await preflight(pi, ctx))) return;

			const { path: pathArg } = parseArgs(args ?? "");

			const cwd = await resolveRepo(pi, ctx, pathArg);
			if (!cwd) return;

			const base = await detectBase(pi, cwd);
			const branch = await currentBranch(pi, cwd);

			if (!branch || branch === base) {
				ctx.ui.notify(
					`You are on the base branch (${base}). Switch to a feature branch first.`,
					"warning",
				);
				return;
			}

			// Changed paths against base — used to infer type/scope when the
			// title isn't already in conventional commits format.
			const names = await run(pi, "git", ["diff", "--name-only", `${base}...HEAD`], cwd);
			const paths = names.stdout
				.split("\n")
				.map((s) => s.trim())
				.filter((s) => s.length > 0);

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
			const title = toConventionalSubject(parsed.title, paths);
			const body = parsed.body;

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
