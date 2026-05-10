/**
 * /commit [<message>]
 *
 * Deterministic commit command with the same repo-picker UX as /push.
 *
 *   /commit            Auto-stage dirty changes when nothing is staged,
 *                      prompt for a conventional-commits message, commit.
 *   /commit <message>  Same, but use <message> verbatim.
 *
 * If something is already staged, only the staged set is committed.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { readdirSync, statSync } from "node:fs";
import { join } from "node:path";

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

// ─── Repo resolution ────────────────────────────────────────────────────────

async function isGitRepo(pi: ExtensionAPI, path: string): Promise<string | undefined> {
	const r = await run(pi, "git", ["rev-parse", "--show-toplevel"], path);
	return r.exitCode === 0 ? r.stdout.trim() : undefined;
}

async function findChildRepos(pi: ExtensionAPI, dir: string, maxDepth = 2): Promise<string[]> {
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
): Promise<string | undefined> {
	const cwdTop = await isGitRepo(pi, ctx.cwd);
	if (cwdTop) return cwdTop;

	const children = await findChildRepos(pi, ctx.cwd);
	if (children.length === 0) {
		await ctx.ui.confirm(
			"Commit aborted",
			`pi's cwd is not a git repository and no git repos were found in:\n  ${ctx.cwd}`,
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
	return children[pretty.indexOf(pick)];
}

// ─── Git inspection ─────────────────────────────────────────────────────────

interface WorkingTree {
	staged: boolean;
	dirty: boolean;
	clean: boolean;
}

async function workingTree(pi: ExtensionAPI, cwd: string): Promise<WorkingTree> {
	const r = await run(pi, "git", ["status", "--porcelain"], cwd);
	const lines = r.stdout.split("\n").filter((l) => l.length > 0);
	if (lines.length === 0) return { staged: false, dirty: false, clean: true };
	const staged = lines.some((l) => l.length >= 1 && l[0] !== " " && l[0] !== "?");
	return { staged, dirty: true, clean: false };
}

async function stagedPaths(pi: ExtensionAPI, cwd: string): Promise<string[]> {
	const r = await run(pi, "git", ["diff", "--cached", "--name-only"], cwd);
	return r.stdout.split("\n").map((s) => s.trim()).filter((s) => s.length > 0);
}

// ─── Commit message suggestions ─────────────────────────────────────────────

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

function suggestSubjectPrefix(paths: string[]): string {
	const type = inferTypeFromPaths(paths);
	const scope = inferScopeFromPaths(paths);
	return scope ? `${type}(${scope}): ` : `${type}: `;
}

async function promptForMessage(
	ctx: ExtensionCommandContext,
	pi: ExtensionAPI,
	cwd: string,
): Promise<string | undefined> {
	const paths = await stagedPaths(pi, cwd);
	const placeholder = `${suggestSubjectPrefix(paths)}<description>`;
	const entered = await ctx.ui.input(
		"Commit message  —  format: <type>(<scope>): <description>",
		placeholder,
	);
	const trimmed = (entered ?? "").trim();
	if (!trimmed) return undefined;
	if (trimmed === placeholder) return undefined;
	return trimmed;
}

// ─── Git operations ─────────────────────────────────────────────────────────

async function gitCommit(
	pi: ExtensionAPI,
	cwd: string,
	message: string,
): Promise<{ ok: true; subject: string; sha: string } | { ok: false; error: string }> {
	const r = await run(pi, "git", ["commit", "-m", message], cwd);
	if (r.exitCode !== 0) return { ok: false, error: (r.stderr || r.stdout).trim() };
	const log = await run(pi, "git", ["log", "-1", "--pretty=%h %s"], cwd);
	const [sha, ...rest] = log.stdout.trim().split(" ");
	return { ok: true, sha, subject: rest.join(" ") };
}

async function commitFlow(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	cwd: string,
	providedMessage: string,
): Promise<void> {
	let tree = await workingTree(pi, cwd);
	if (tree.clean) {
		ctx.ui.notify("Nothing to commit — working tree clean.", "info");
		return;
	}

	// Match the old /commit behavior: if the user staged something, respect it;
	// otherwise auto-stage all dirty changes for the common case.
	if (!tree.staged) {
		const add = await run(pi, "git", ["add", "-A"], cwd);
		if (add.exitCode !== 0) {
			ctx.ui.notify(`git add -A failed:\n${(add.stderr || add.stdout).trim()}`, "error");
			return;
		}
		tree = await workingTree(pi, cwd);
	}

	if (!tree.staged) {
		ctx.ui.notify("Nothing staged to commit.", "info");
		return;
	}

	const message = providedMessage.trim() || (await promptForMessage(ctx, pi, cwd));
	if (!message) {
		ctx.ui.notify("Commit cancelled (no commit message). Staged changes left in place.", "info");
		return;
	}

	const commit = await gitCommit(pi, cwd, message);
	if (!commit.ok) {
		ctx.ui.notify(`git commit failed:\n${commit.error}`, "error");
		return;
	}
	ctx.ui.notify(`✓ Committed ${commit.sha}: ${commit.subject}`, "success");
}

async function preflight(pi: ExtensionAPI, ctx: ExtensionCommandContext): Promise<boolean> {
	const git = await run(pi, "git", ["--version"], ctx.cwd);
	if (git.exitCode !== 0) {
		await ctx.ui.confirm("Commit aborted", "`git` not found in PATH.");
		return false;
	}
	return true;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("commit", {
		description: "Stage (if needed) and commit with the same repo picker UX as /push",
		handler: async (args, ctx) => {
			if (!(await preflight(pi, ctx))) return;
			const cwd = await resolveRepo(pi, ctx);
			if (!cwd) return;
			return commitFlow(pi, ctx, cwd, args ?? "");
		},
	});
}
