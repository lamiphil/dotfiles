/**
 * /pr  [<repo-path>]
 *
 * Open a PR via `gh pr create`, with a friendly approve/edit flow.
 *
 * Uses the current LLM to generate a PR title and description from the
 * branch's diff and commits, then opens both in an editor for review.
 * Cancel by saving an empty buffer.
 *
 *   /pr                 Operate on the current repo (or pick one if cwd holds
 *                       multiple).
 *   /pr <path>          Operate on the repo at <path>.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
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
	const sym = await run(pi, "git", ["symbolic-ref", "refs/remotes/origin/HEAD"], cwd);
	if (sym.exitCode === 0) {
		const m = sym.stdout.trim().match(/refs\/remotes\/origin\/(.+)$/);
		if (m) return m[1];
	}
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

const CONVENTIONAL_RE = /^(chore|feat|fix)(\([^)]+\))?(!)?:\s+\S/;

function inferTypeFromPaths(paths: string[]): "chore" | "feat" | "fix" {
	const joined = paths.join("\n").toLowerCase();
	if (/\bfix\b|\bbug\b|\bhotfix\b/.test(joined)) return "fix";
	return "chore";
}

function inferScopeFromPaths(paths: string[]): string | undefined {
	if (paths.length === 0) return undefined;
	const freq = new Map<string, number>();
	for (const p of paths) {
		const seg = p.split("/")[0];
		if (!seg || seg.startsWith(".")) continue;
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

function stripConventionalPrefix(subject: string): string {
	return subject.replace(/^(chore|feat|fix)(\([^)]+\))?(!)?:\s+/, "");
}

function capitalizeFirst(s: string): string {
	return s.length === 0 ? s : s.charAt(0).toUpperCase() + s.slice(1);
}

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

function titleToLeadSentence(title: string): string {
	const desc = stripConventionalPrefix(title).trim();
	if (!desc) return "This PR introduces the changes below.";
	const [first, ...rest] = desc.split(/\s+/);
	const conjugated = conjugate3rdPersonSingular(first);
	const tail = rest.join(" ");
	const sentence = tail ? `This PR ${conjugated} ${tail}` : `This PR ${conjugated}`;
	return sentence.replace(/[.!?]+$/, "") + ".";
}

function commitToBullet(subject: string): string {
	return capitalizeFirst(stripConventionalPrefix(subject).trim());
}

const PR_DESCRIPTION_PROMPT = `You are writing a GitHub PR description. You will be given the PR title, commit subjects, and a diff.

Write a concise PR description following this style:
- Start with a lead sentence: "This PR [verb]s [what]."
- If there are multiple distinct changes, add a bullet list with \`-\` (no heading, no "## Changes")
- If there is important context (why this change was made, migration steps, manual work needed), add a short paragraph after the bullets
- Keep it concise — no filler, no restating the title unnecessarily
- For trivial single-commit PRs, a single sentence is enough
- Use backticks for code references (file names, variable names, commands)
- Do not use markdown headings (no ##)

Output ONLY the PR body text, no title, no markdown fencing.`;

function getCheapestModelForProvider(ctx: ExtensionCommandContext): ExtensionCommandContext["model"] {
	const current = ctx.model;
	if (!current) return undefined;

	const available = ctx.modelRegistry.getAvailable();
	const sameProvider = available.filter((m) => m.provider === current.provider);
	if (sameProvider.length === 0) return current;

	sameProvider.sort((a, b) => a.cost.input - b.cost.input);
	return sameProvider[0];
}

async function callLLM(
	ctx: ExtensionCommandContext,
	prompt: string,
	userContent: string,
): Promise<string | undefined> {
	const model = getCheapestModelForProvider(ctx);
	if (!model) return undefined;

	console.log(`Using model ${model.id} for PR description`);

	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
	if (!auth.ok) return undefined;

	const provider = model.provider;
	const baseUrl = model.baseUrl;

	if (provider === "anthropic" || (baseUrl && baseUrl.includes("anthropic"))) {
		const headers: Record<string, string> = {
			"content-type": "application/json",
			"x-api-key": auth.apiKey ?? "",
			"anthropic-version": "2023-06-01",
			...(auth.headers ?? {}),
		};

		const resp = await fetch(`${baseUrl ?? "https://api.anthropic.com"}/v1/messages`, {
			method: "POST",
			headers,
			body: JSON.stringify({
				model: model.id,
				max_tokens: 1024,
				system: prompt,
				messages: [{ role: "user", content: userContent }],
			}),
		});

		if (!resp.ok) return undefined;
		const data = (await resp.json()) as { content?: Array<{ text?: string }> };
		return data.content?.[0]?.text;
	}

	// OpenAI-compatible
	const headers: Record<string, string> = {
		"content-type": "application/json",
		authorization: `Bearer ${auth.apiKey ?? ""}`,
		...(auth.headers ?? {}),
	};

	const resp = await fetch(`${baseUrl ?? "https://api.openai.com"}/v1/chat/completions`, {
		method: "POST",
		headers,
		body: JSON.stringify({
			model: model.id,
			max_tokens: 1024,
			messages: [
				{ role: "system", content: prompt },
				{ role: "user", content: userContent },
			],
		}),
	});

	if (!resp.ok) return undefined;
	const data = (await resp.json()) as { choices?: Array<{ message?: { content?: string } }> };
	return data.choices?.[0]?.message?.content;
}

async function generateTitleAndBody(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	cwd: string,
	base: string,
): Promise<{ title: string; body: string }> {
	const subj = await run(pi, "git", ["log", "-1", "--pretty=%s"], cwd);
	const rawTitle = subj.stdout.trim();

	const names = await run(pi, "git", ["diff", "--name-only", `${base}...HEAD`], cwd);
	const paths = names.stdout
		.split("\n")
		.map((s) => s.trim())
		.filter((s) => s.length > 0);

	const title = toConventionalSubject(rawTitle, paths);

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

	// Try LLM-generated body
	const diff = await run(pi, "git", ["diff", `${base}...HEAD`], cwd);
	const truncatedDiff = diff.stdout.slice(0, 15000);

	const userContent = [
		`PR Title: ${title}`,
		``,
		`Commits:`,
		...subjects.map((s) => `- ${s}`),
		``,
		`Diff:`,
		"```",
		truncatedDiff,
		"```",
	].join("\n");

	ctx.ui.setStatus("pr", "Generating PR description…");
	const llmBody = await callLLM(ctx, PR_DESCRIPTION_PROMPT, userContent);
	ctx.ui.setStatus("pr", "");

	if (llmBody) {
		return { title, body: llmBody.trim() };
	}

	// Fallback: heuristic
	const lead = titleToLeadSentence(title || rawTitle);
	const bullets = subjects.map((s) => `- ${commitToBullet(s)}`).join("\n");

	let body: string;
	if (subjects.length === 0) {
		body = `${lead}\n\n_(no commits ahead of \`${base}\`)_\n`;
	} else if (subjects.length === 1) {
		body = `${lead}\n`;
	} else {
		body = `${lead}\n\n${bullets}\n`;
	}

	return { title: title || `Update from ${await currentBranch(pi, cwd)}`, body };
}

function parseTitleAndBody(text: string): { title: string; body: string } | undefined {
	const trimmed = text.replace(/^\s+|\s+$/g, "");
	if (!trimmed) return undefined;
	const lines = trimmed.split("\n");
	const title = (lines.shift() ?? "").trim();
	if (!title) return undefined;
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
	} catch {}
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
				continue;
			}
			await walk(full, depth + 1);
		}
	};

	await walk(dir, 1);
	return hits.sort();
}

async function resolveRepo(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	explicitPath: string | undefined,
): Promise<string | undefined> {
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

	const cwdTop = await isGitRepo(pi, ctx.cwd);
	if (cwdTop) return cwdTop;

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
		description: "Open a GitHub PR (LLM-generated title + description from branch diff)",
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

			const names = await run(pi, "git", ["diff", "--name-only", `${base}...HEAD`], cwd);
			const paths = names.stdout
				.split("\n")
				.map((s) => s.trim())
				.filter((s) => s.length > 0);

			const gen = await generateTitleAndBody(pi, ctx, cwd, base);
			const reviewed = await ctx.ui.editor(
				`Review PR (base: ${base}) — first line is the title. Save empty to cancel.`,
				`${gen.title}\n\n${gen.body}`,
			);
			const parsed = parseTitleAndBody(reviewed ?? "");
			if (!parsed) {
				ctx.ui.notify("PR cancelled.", "info");
				return;
			}
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
