/**
 * /push  [<message>]
 * /push force  [<message>]
 *
 * Stage (force only), commit (when needed), and push the current branch.
 *
 *   /push                  Push the current branch to its upstream.
 *                          - If something is already staged, prompts for a
 *                            commit message (pre-filled with a conventional-
 *                            commits suggestion), commits, then pushes.
 *                          - If nothing is staged and there are local commits
 *                            ahead of upstream, just pushes.
 *                          - If nothing is staged and the branch is up to date
 *                            with upstream, says so and stops.
 *                          - Sets the upstream automatically when the branch
 *                            has none.
 *
 *   /push <message>        Same, but use <message> verbatim as the commit
 *                          message when committing is needed.
 *
 *   /push force            Stage all working-tree changes (`git add -A`),
 *                          commit, then ASK FOR CONFIRMATION before pushing.
 *
 *   /push force <message>  Same, with <message> used verbatim for the commit.
 *
 * `force` only authorises auto-staging. It never authorises `git push --force`,
 * a rebase, or any history rewrite.
 *
 * Repo resolution (always operates on a single repo):
 *   1. If pi's cwd is itself a git repo, use it.
 *   2. Else scan immediate subdirectories for git repos and prompt to pick.
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
			"Push aborted",
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

async function currentBranch(pi: ExtensionAPI, cwd: string): Promise<string> {
	const r = await run(pi, "git", ["rev-parse", "--abbrev-ref", "HEAD"], cwd);
	return r.stdout.trim();
}

async function getUpstream(pi: ExtensionAPI, cwd: string): Promise<string | undefined> {
	const r = await run(
		pi,
		"git",
		["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
		cwd,
	);
	return r.exitCode === 0 ? r.stdout.trim() : undefined;
}

async function commitsAhead(pi: ExtensionAPI, cwd: string, upstream: string): Promise<number> {
	const r = await run(pi, "git", ["rev-list", "--count", `${upstream}..HEAD`], cwd);
	return r.exitCode === 0 ? Number.parseInt(r.stdout.trim(), 10) || 0 : 0;
}

async function hasAnyCommits(pi: ExtensionAPI, cwd: string): Promise<boolean> {
	const r = await run(pi, "git", ["rev-parse", "--verify", "HEAD"], cwd);
	return r.exitCode === 0;
}

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

// ─── Argument parsing ───────────────────────────────────────────────────────

interface ParsedArgs {
	force: boolean;
	message: string;
}

function parseArgs(raw: string): ParsedArgs {
	const trimmed = (raw ?? "").trim();
	if (!trimmed) return { force: false, message: "" };
	// Only treat `force` as the keyword when it's the entire first token
	// (so `force-merge feature` stays a regular message).
	const m = trimmed.match(/^force(?:\s+(.*))?$/i);
	if (m) return { force: true, message: (m[1] ?? "").trim() };
	return { force: false, message: trimmed };
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

async function gitPush(
	pi: ExtensionAPI,
	cwd: string,
	branch: string,
	setUpstream: boolean,
): Promise<{ ok: true; output: string } | { ok: false; error: string }> {
	const args = setUpstream ? ["push", "--set-upstream", "origin", branch] : ["push"];
	const r = await run(pi, "git", args, cwd);
	if (r.exitCode !== 0) return { ok: false, error: (r.stderr || r.stdout).trim() };
	// `git push` writes status to stderr; surface whichever stream has content.
	return { ok: true, output: (r.stderr || r.stdout).trim() };
}

// ─── Prompts ────────────────────────────────────────────────────────────────

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
	// Reject the placeholder verbatim — user clearly didn't fill it in.
	if (trimmed === placeholder) return undefined;
	return trimmed;
}

// ─── Flows ──────────────────────────────────────────────────────────────────

async function defaultFlow(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	cwd: string,
	providedMessage: string,
): Promise<void> {
	const branch = await currentBranch(pi, cwd);
	if (!branch || branch === "HEAD") {
		ctx.ui.notify("Detached HEAD — nothing to push.", "warning");
		return;
	}

	const tree = await workingTree(pi, cwd);
	const upstream = await getUpstream(pi, cwd);
	const ahead = upstream ? await commitsAhead(pi, cwd, upstream) : 0;

	// Case A: something staged → commit, then push.
	if (tree.staged) {
		const message = providedMessage || (await promptForMessage(ctx, pi, cwd));
		if (!message) {
			ctx.ui.notify("Push cancelled (no commit message).", "info");
			return;
		}
		const commit = await gitCommit(pi, cwd, message);
		if (!commit.ok) {
			ctx.ui.notify(`git commit failed:\n${commit.error}`, "error");
			return;
		}
		ctx.ui.notify(`✓ Committed ${commit.sha}: ${commit.subject}`, "info");
		await doPush(pi, ctx, cwd, branch, !upstream);
		return;
	}

	// Case C: nothing staged, no commits ahead, has upstream → nothing to do.
	if (upstream && ahead === 0) {
		ctx.ui.notify(`Nothing to do — working tree clean and up to date with ${upstream}.`, "info");
		return;
	}

	// Case D: no upstream, no commits → can't push anything meaningful.
	if (!upstream && !(await hasAnyCommits(pi, cwd))) {
		ctx.ui.notify("Nothing to push (branch has no commits).", "warning");
		return;
	}

	// Case B/D: nothing staged, commits ahead OR no upstream yet → just push.
	await doPush(pi, ctx, cwd, branch, !upstream);
}

async function forceFlow(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	cwd: string,
	providedMessage: string,
): Promise<void> {
	const branch = await currentBranch(pi, cwd);
	if (!branch || branch === "HEAD") {
		ctx.ui.notify("Detached HEAD — nothing to push.", "warning");
		return;
	}

	const tree = await workingTree(pi, cwd);
	const upstream = await getUpstream(pi, cwd);
	const ahead = upstream ? await commitsAhead(pi, cwd, upstream) : 0;

	// Tree clean and nothing ahead → nothing to do (mirror skill rule).
	if (tree.clean && upstream && ahead === 0) {
		ctx.ui.notify(`Nothing to do — working tree clean and up to date with ${upstream}.`, "info");
		return;
	}

	// Stage everything if there are unstaged changes.
	if (tree.dirty) {
		const add = await run(pi, "git", ["add", "-A"], cwd);
		if (add.exitCode !== 0) {
			ctx.ui.notify(`git add -A failed:\n${(add.stderr || add.stdout).trim()}`, "error");
			return;
		}
	}

	// Commit if there's anything staged after `add -A`.
	const stagedNow = (await workingTree(pi, cwd)).staged;
	if (stagedNow) {
		const message = providedMessage || (await promptForMessage(ctx, pi, cwd));
		if (!message) {
			ctx.ui.notify("Push cancelled (no commit message). Staged changes left in place.", "info");
			return;
		}
		const commit = await gitCommit(pi, cwd, message);
		if (!commit.ok) {
			ctx.ui.notify(`git commit failed:\n${commit.error}`, "error");
			return;
		}
		ctx.ui.notify(`✓ Committed ${commit.sha}: ${commit.subject}`, "info");
	}

	// Confirm BEFORE pushing — this is the whole point of force mode.
	const target = upstream ?? `origin/${branch} (new upstream)`;
	const ok = await ctx.ui.confirm("Push?", `Push ${branch} → ${target}?`);
	if (!ok) {
		ctx.ui.notify(
			`Push skipped. Commit is in place; run /push later to send it to ${target}.`,
			"info",
		);
		return;
	}

	await doPush(pi, ctx, cwd, branch, !upstream);
}

async function doPush(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	cwd: string,
	branch: string,
	setUpstream: boolean,
): Promise<void> {
	ctx.ui.notify(setUpstream ? `Pushing ${branch} (setting upstream)…` : `Pushing ${branch}…`, "info");
	const result = await gitPush(pi, cwd, branch, setUpstream);
	if (!result.ok) {
		ctx.ui.notify(`git push failed:\n${result.error}`, "error");
		return;
	}
	ctx.ui.notify(`✓ Pushed ${branch}\n${result.output}`, "success");
}

// ─── Entry point ────────────────────────────────────────────────────────────

async function preflight(pi: ExtensionAPI, ctx: ExtensionCommandContext): Promise<boolean> {
	const git = await run(pi, "git", ["--version"], ctx.cwd);
	if (git.exitCode !== 0) {
		await ctx.ui.confirm("Push aborted", "`git` not found in PATH.");
		return false;
	}
	return true;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("push", {
		description:
			"Commit (if needed) and push the current branch (use `/push force` to auto-stage and confirm)",
		getArgumentCompletions: (prefix: string) => {
			const tokens = prefix.split(/\s+/);
			if (tokens.length <= 1) {
				const items = [{ value: "force", label: "force — auto-stage all + confirm before pushing" }];
				const filtered = items.filter((i) => i.value.startsWith(tokens[0] ?? ""));
				return filtered.length > 0 ? filtered : null;
			}
			return null;
		},
		handler: async (args, ctx) => {
			if (!(await preflight(pi, ctx))) return;
			const cwd = await resolveRepo(pi, ctx);
			if (!cwd) return;
			const { force, message } = parseArgs(args ?? "");
			if (force) return forceFlow(pi, ctx, cwd, message);
			return defaultFlow(pi, ctx, cwd, message);
		},
	});
}
