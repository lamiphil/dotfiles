/**
 * /task <description>   (run in a master session)
 *
 * Start a sub-task in a new Rex tab, carrying this session's context:
 *   1. names it "<root tab> - <slug>" (root = current tab without letter/suffix)
 *   2. opens a tab in the same folder right after the root's last task, keeping focus here
 *   3. runs `pi --fork <this session>` there with the same model and thinking level
 *   4. the new pi compacts with the task as focus, then starts on it
 *
 * Task <-> master channel (firstmate-style, no polling, no extra model turns):
 *   ~/.local/state/pi/tasks/<id>/meta.json    task, name, master session id, Rex window
 *   ~/.local/state/pi/tasks/<id>/status.log   "<iso> <state>: <note>" lines, written by the task_status tool
 *   ~/.local/state/pi/tasks/<id>/inbox        JSON lines written by /reply, delivered to the task
 *
 * In a task: the task_status tool records working / needs-decision / blocked / done.
 *   done -> /skill:log runs automatically once the turn settles.
 *   The Rex tab name gets a suffix: 🔄 running, ❓ needs decision, ⛔ blocked, ✅ done, 💤 waiting for you.
 * In the master: new non-"working" status lines are added to the conversation as
 *   messages (no turn is triggered), plus a notification. Replaces /refresh-memory for tasks.
 * Levels: /task <text> asks the master for a quick analysis; it calls delegate_task with a
 *   level (rush / oracle / omnissiah), a title and a brief. The tab then starts with the
 *   model + thinking for that level on the master's provider (same table as agent-modes.ts).
 *   /task --rush|--oracle|--omnissiah <text> skips the analysis.
 * /reply [task] <text>: send text to a task without switching tabs. No args lists tasks.
 * /settle [task]: close a task. In the master it targets one task (optional if only one);
 *   in a task tab it closes that tab. The task first reports done and writes its /log
 *   entry if it has not yet, then records "closed" and closes its Rex tab.
 */

import { appendFileSync, existsSync, mkdirSync, readdirSync, readFileSync, watch, writeFileSync, type FSWatcher } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

const STATE_DIR = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "pi", "tasks");
const TASK_ID = process.env.PI_TASK_ID;

const STOPWORDS = new Set(
	"a an the to of for in on and or with from into at by is are be it this that we i me my our you your please can could should would need needs want let lets make check look see tell help following next about what how why do does go ahead some any all".split(" "),
);

// Placeholder name until the task agent sets a real title (task_status title).
function slugify(task: string): string {
	const tickets = [...new Set(task.match(/\b[A-Z][A-Z0-9]+-\d+\b/g) ?? [])];
	const words = task
		.replace(/\b[A-Z][A-Z0-9]+-\d+\b/g, " ")
		.toLowerCase()
		.replace(/https?:\/\/\S+/g, " ")
		.replace(/[^\p{L}\p{N}\s-]/gu, " ")
		.split(/\s+/)
		.filter((w) => w.length > 1 && !STOPWORDS.has(w));
	return [...tickets, ...words].slice(0, 4).join(" ") || "task";
}

const cleanTitle = (t: string) =>
	t.replace(/[\n\r]+/g, " ").replace(/\s+-\s+/g, " ").replace(/\s+/g, " ").trim().slice(0, 40);

// "a · ✅ perso - sub task" -> "perso"
function rootName(label: string): string {
	return label.replace(/^[\p{Ll}\d] · /u, "").replace(/^(?:🔄|❓|⛔|✅|💤)\s*/u, "").split(" - ")[0].trim();
}

type Level = "rush" | "oracle" | "omnissiah";
const LEVELS = ["rush", "oracle", "omnissiah"] as const;
const LEVEL_ICON: Record<Level, string> = { rush: "🚀", oracle: "🔮", omnissiah: "🤖" };
// Keep in sync with agent-modes.ts PROFILES. claude-code has its own model ids.
const LEVEL_MODELS: Record<string, Record<Level, string>> = {
	"openai-codex": { rush: "gpt-5.6-luna:medium", oracle: "gpt-5.6-terra:medium", omnissiah: "gpt-5.6-sol:high" },
	anthropic: { rush: "claude-haiku-4-5:medium", oracle: "claude-opus-4-7:high", omnissiah: "claude-opus-5-5:high" },
	"claude-code": { rush: "claude-haiku-5-5:medium", oracle: "claude-sonnet-5-5:high", omnissiah: "claude-opus-5-5:high" },
};

type Delegation = { task: string; title?: string; brief?: string; level?: Level; why?: string };

const ANALYSIS = (task: string) => `/task request: ${task}

Delegate this to a new task session. Do a quick analysis only: read at most what is strictly needed to judge it (for example the ticket it names). Do not start the work.
Then call delegate_task once with:
- level: rush for small, clear, mechanical work; oracle for normal multi-step work; omnissiah for ambiguous, risky, architectural or hard-debugging work.
- title: 2-5 words naming the actual work, ticket ID first when there is one.
- brief: what the task agent must do, with the key facts, files and constraints you found, and what "done" means.
- why: one short reason for the level.
After the tool call, stop. No summary.`;

type Window = { window_id: string; label?: string; layers?: unknown[] };
type Meta = {
	id: string;
	task: string;
	name: string;
	master: string;
	cwd: string;
	created: string;
	started?: boolean;
	closed?: string;
	rex_session?: string;
	window_id?: string;
	level?: Level;
	brief?: string;
	titled?: boolean;
};
type State = "working" | "needs-decision" | "blocked" | "done";

const EMOJI: Record<string, string> = { running: "🔄", "needs-decision": "❓", blocked: "⛔", done: "✅", idle: "💤" };

function containsBlock(node: unknown, blockId: string): boolean {
	if (!node || typeof node !== "object") return false;
	if ((node as { block_id?: string }).block_id === blockId) return true;
	return Object.values(node).some((v) => containsBlock(v, blockId));
}

const taskDir = (id: string) => join(STATE_DIR, id);
const readMeta = (id: string): Meta | undefined => {
	try {
		return JSON.parse(readFileSync(join(taskDir(id), "meta.json"), "utf8"));
	} catch {
		return undefined;
	}
};
const writeMeta = (meta: Meta) => writeFileSync(join(taskDir(meta.id), "meta.json"), JSON.stringify(meta, null, 2));

// Read lines appended since the last call; the offset is persisted so restarts never replay or drop lines.
function readNew(file: string, offsetFile: string): string[] {
	if (!existsSync(file)) return [];
	const buf = readFileSync(file);
	let offset = 0;
	try {
		offset = Number(readFileSync(offsetFile, "utf8")) || 0;
	} catch {}
	if (offset > buf.length) offset = 0;
	const end = buf.lastIndexOf(0x0a) + 1; // only complete lines
	if (end <= offset) return [];
	writeFileSync(offsetFile, String(end));
	return buf.subarray(offset, end).toString("utf8").split("\n").filter(Boolean);
}

function lastStatus(id: string): string {
	try {
		const lines = readFileSync(join(taskDir(id), "status.log"), "utf8").trim().split("\n");
		return lines[lines.length - 1]?.replace(/^\S+ /, "") ?? "";
	} catch {
		return "";
	}
}

function tasksOf(master: string): Meta[] {
	if (!existsSync(STATE_DIR)) return [];
	return readdirSync(STATE_DIR)
		.map(readMeta)
		.filter((m): m is Meta => !!m && m.master === master && !m.closed)
		.sort((a, b) => a.created.localeCompare(b.created));
}

const taskList = (tasks: Meta[]) =>
	tasks.map((t, i) => `${i + 1}. ${t.name} [${t.id}]  ${lastStatus(t.id) || "no status yet"}`).join("\n");

// "2 rest" / "<id prefix> rest" / "rest" when there is a single task.
function pickTask(tasks: Meta[], raw: string): { target?: Meta; rest: string } {
	const [key = "", ...rest] = raw.split(/\s+/);
	const target = /^\d+$/.test(key) ? tasks[Number(key) - 1] : key ? tasks.find((t) => t.id === key || t.id.startsWith(key)) : undefined;
	if (target) return { target, rest: rest.join(" ") };
	return tasks.length === 1 ? { target: tasks[0], rest: raw } : { rest: raw };
}

const PROTOCOL = (meta: Meta) => `You are a task session forked from a master session. Your task: ${meta.brief ?? meta.task}
Report to the master with the task_status tool, briefly (one line each):
- ${meta.titled ? "Your tab is already named. Set a title only if the task changes. Otherwise, once you understand" : "First, once you understand"} the task (after reading any ticket, file or link it names), call task_status working with a title: 2-5 words naming the actual work, ticket ID first when there is one, e.g. "TPA-142 rotate SQL creds". It becomes the tab name. Set title again only if the task changes.
- working: <phase>, only when you start a distinct phase.
- needs-decision: <question>, when the user must choose. Then stop and wait.
- blocked: <what is stuck>, when you cannot continue. Then stop and wait.
- done: <one-line outcome>, when the task is complete. A /log entry is written automatically afterwards; never run /log yourself.
Messages starting with "Message from the master session:" come from the user through the master.`;

export default function (pi: ExtensionAPI) {
	let ctxRef: ExtensionContext | undefined;
	const watchers: FSWatcher[] = [];
	const closeWatchers = () => watchers.splice(0).forEach((w) => w.close());

	const rex = async (...rexArgs: string[]) => {
		const bin = process.env.REX_BIN_DIR;
		if (!bin) throw new Error("not in a Rex pane");
		const r = await pi.exec(join(bin, "rex"), rexArgs);
		if (r.code !== 0) throw new Error(`rex ${rexArgs[0]}: ${r.stderr.trim() || r.stdout.trim()}`);
		return r.stdout;
	};
	const sessionView = async (sessionId: string) =>
		JSON.parse(await rex("api", "call", "session.view", JSON.stringify({ session_id: sessionId })));

	pi.on("session_shutdown", async () => closeWatchers());

	// ───────────────────────────── master side ─────────────────────────────

	async function spawnTask(ctx: ExtensionContext, d: Delegation): Promise<string> {
		const { REX_BIN_DIR, REX_SESSION, REX_BLOCK } = process.env;
		if (!REX_BIN_DIR || !REX_SESSION || !REX_BLOCK) throw new Error("/task needs a Rex pane");
		const sessionFile = ctx.sessionManager.getSessionFile();
		if (!sessionFile) throw new Error("/task needs a saved session to fork");

		const windows: Window[] = (await sessionView(REX_SESSION)).windows ?? [];
		const current = windows.find((w) => containsBlock(w.layers, REX_BLOCK));
		if (!current) throw new Error("current Rex tab not found");

		const root = rootName(current.label ?? "") || "task";
		let title = d.title ? cleanTitle(d.title) : "";
		if (title.toLowerCase().startsWith(root.toLowerCase())) title = title.slice(root.length).trim();
		const slug = slugify(title || d.task);
		const name = `${root} - ${title || slug}`;
		// Insert after the root tab's last task (or the root itself).
		const start = windows.findIndex((w) => rootName(w.label ?? "") === root);
		let anchor = windows[start >= 0 ? start : windows.indexOf(current)];
		for (const w of windows.slice(windows.indexOf(anchor) + 1)) {
			if (rootName(w.label ?? "") !== root) break;
			anchor = w;
		}

		// Level -> model on the master's provider; unknown provider or no level keeps the master's model.
		const own = ctx.model ? `${ctx.model.provider}/${ctx.model.id}:${pi.getThinkingLevel()}` : "";
		const mapped = d.level && ctx.model ? LEVEL_MODELS[ctx.model.provider]?.[d.level] : undefined;
		const model = mapped ? `${ctx.model!.provider}/${mapped}` : own;

		const id = `${slug.replace(/\s+/g, "-")}-${Date.now().toString(36).slice(-4)}`;
		mkdirSync(taskDir(id), { recursive: true });
		const meta: Meta = {
			id,
			task: d.task,
			name,
			master: ctx.sessionManager.getSessionId(),
			cwd: ctx.cwd,
			created: new Date().toISOString(),
			rex_session: REX_SESSION,
			level: d.level,
			brief: d.brief,
			titled: !!title,
		};
		writeMeta(meta);

		const created = JSON.parse(
			await rex(
				"window", "new", "-s", REX_SESSION, name, "-c", ctx.cwd, "--focus=false", "--shell", "none", "--json", "--",
				"/opt/homebrew/bin/fish", "-c",
				'set -lx PI_TASK_ID $argv[1]; if test -n "$argv[4]"; exec pi --fork $argv[2] --name $argv[3] --model $argv[4]; else; exec pi --fork $argv[2] --name $argv[3]; end',
				id, sessionFile, name, model,
			),
		);
		writeMeta({ ...(readMeta(id) ?? meta), window_id: created.window_id });
		await rex("window", "move", "-s", REX_SESSION, created.window_id, "--after", anchor.window_id);
		const lvl = d.level ? `${LEVEL_ICON[d.level]} ${d.level}` : "same level";
		return `Started "${name}" (${lvl}, ${model.split("/").pop()})${d.why ? `: ${d.why}` : ""}`;
	}

	// Filled by delegate_task, spawned once the master's turn settles so the fork sees a complete session.
	let pendingDelegation: Delegation | undefined;
	let analysing: string | undefined;

	pi.registerCommand("task", {
		description: "Delegate a sub-task to a new Rex tab; the master picks its level. /task [--rush|--oracle|--omnissiah] <text>",
		handler: async (args, ctx) => {
			let task = (args ?? "").trim();
			const forced = task.match(/^--(rush|oracle|omnissiah)\s+/)?.[1] as Level | undefined;
			if (forced) task = task.slice(forced.length + 3).trim();
			if (!task) return ctx.ui.notify("Usage: /task [--rush|--oracle|--omnissiah] <description>", "warning");
			if (!process.env.REX_SESSION || !process.env.REX_BLOCK) return ctx.ui.notify("/task needs a Rex pane.", "error");
			if (!ctx.sessionManager.getSessionFile()) return ctx.ui.notify("/task needs a saved session to fork.", "error");

			if (forced) {
				try {
					ctx.ui.notify(await spawnTask(ctx, { task, level: forced }), "info");
				} catch (err) {
					ctx.ui.notify(`/task failed: ${(err as Error).message}`, "error");
				}
				return;
			}
			analysing = task;
			if (ctx.isIdle()) pi.sendUserMessage(ANALYSIS(task));
			else pi.sendUserMessage(ANALYSIS(task), { deliverAs: "followUp" });
		},
	});

	pi.registerTool({
		name: "delegate_task",
		label: "Delegate task",
		description: "Only after a /task request: start the analysed task in a new tab at the chosen level. Call once, then stop.",
		parameters: Type.Object({
			level: StringEnum(LEVELS),
			title: Type.String({ description: "2-5 words, ticket ID first if any" }),
			brief: Type.String({ description: "Instructions for the task agent: goal, key facts, files, constraints, definition of done" }),
			why: Type.String({ description: "One short reason for the level" }),
		}),
		async execute(_id, params) {
			if (!analysing) throw new Error("delegate_task is only valid right after a /task request");
			pendingDelegation = { task: analysing, ...params };
			analysing = undefined;
			return {
				content: [{ type: "text", text: `Queued ${LEVEL_ICON[params.level]} ${params.level}: ${params.title}. The tab opens when this turn ends. Stop now.` }],
				details: {},
			};
		},
	});

	pi.on("agent_settled", async (_event, ctx) => {
		analysing = undefined; // a /task turn that never called delegate_task is dropped
		const d = pendingDelegation;
		if (!d) return;
		pendingDelegation = undefined;
		try {
			const msg = await spawnTask(ctx, d);
			pi.sendMessage({ customType: "task-status", content: msg, display: true }, { triggerTurn: false });
		} catch (err) {
			ctx.ui.notify(`/task failed: ${(err as Error).message}`, "error");
		}
	});

	pi.registerCommand("reply", {
		description: "Send a message to one of this session's /task tabs: /reply [n|id] <text>",
		handler: async (args, ctx) => {
			const tasks = tasksOf(ctx.sessionManager.getSessionId());
			if (!tasks.length) return ctx.ui.notify("No open /task tabs belong to this session.", "warning");
			const raw = (args ?? "").trim();
			if (!raw) return ctx.ui.notify(`Usage: /reply [n|id] <text>\n${taskList(tasks)}`, "info");
			const { target, rest: text } = pickTask(tasks, raw);
			if (!target || !text) return ctx.ui.notify(`Which task?\n${taskList(tasks)}`, "warning");
			appendFileSync(join(taskDir(target.id), "inbox"), `${JSON.stringify({ at: new Date().toISOString(), text })}\n`);
			ctx.ui.notify(`→ ${target.name}`, "info");
		},
	});

	pi.registerCommand("settle", {
		description: "Close a /task: log it if needed, then close its Rex tab. /settle [n|id] in the master, /settle in a task tab",
		handler: async (args, ctx) => {
			const raw = (args ?? "").trim();
			if (TASK_ID && !raw) return finish();

			const tasks = tasksOf(ctx.sessionManager.getSessionId());
			if (!tasks.length) return ctx.ui.notify("No open /task tabs belong to this session.", "warning");
			const { target } = pickTask(tasks, raw);
			if (!target) return ctx.ui.notify(`Which task?\n${taskList(tasks)}`, "warning");

			let alive = false;
			try {
				const windows: Window[] = (await sessionView(target.rex_session ?? "")).windows ?? [];
				alive = windows.some((w) => w.window_id === target.window_id);
			} catch {}
			if (!alive) {
				writeMeta({ ...target, closed: new Date().toISOString() });
				return ctx.ui.notify(`${target.name}: tab already gone, marked closed.`, "info");
			}
			// The task wraps up itself (done + /log) and closes its own tab.
			appendFileSync(join(taskDir(target.id), "inbox"), `${JSON.stringify({ at: new Date().toISOString(), type: "done" })}\n`);
			ctx.ui.notify(`Closing ${target.name}…`, "info");
		},
	});

	function drainStatus(id: string, master: string) {
		const meta = readMeta(id);
		if (!meta || meta.master !== master) return;
		const dir = taskDir(id);
		for (const line of readNew(join(dir, "status.log"), join(dir, "master.offset"))) {
			const body = line.replace(/^\S+ /, "");
			if (body.startsWith("working:")) continue;
			if (body.startsWith("closed:")) {
				pi.sendMessage(
					{ customType: "task-status", content: `✅ ${meta.name} settled`, display: true },
					{ triggerTurn: false },
				);
				continue;
			}
			pi.sendMessage(
				{ customType: "task-status", content: `[task "${meta.name}" (${id})] ${body}`, display: true },
				{ triggerTurn: false },
			);
		}
	}

	function watchAsMaster(master: string) {
		mkdirSync(STATE_DIR, { recursive: true });
		for (const t of tasksOf(master)) drainStatus(t.id, master); // lines written while this session was closed
		watchers.push(
			watch(STATE_DIR, { recursive: true }, (_event, file) => {
				const m = file?.toString().match(/^([^/]+)\/status\.log$/);
				if (m) drainStatus(m[1], master);
			}),
		);
	}

	// ───────────────────────────── task side ─────────────────────────────

	let lastState: State | undefined;
	let pendingLog = false;
	let logging = false;
	let closeWhenSettled = false;
	let shownEmoji = "";

	async function closeSelf() {
		if (!TASK_ID) return;
		const meta = readMeta(TASK_ID);
		if (!meta) return;
		writeMeta({ ...meta, closed: new Date().toISOString() });
		appendFileSync(join(taskDir(TASK_ID), "status.log"), `${new Date().toISOString()} closed: tab closed\n`);
		const session = meta.rex_session ?? process.env.REX_SESSION;
		if (session && meta.window_id) await rex("window", "close", "-s", session, meta.window_id).catch(() => {});
	}

	// Report done + /log if not done yet, then close the tab once the agent settles.
	function finish() {
		if (!TASK_ID) return;
		const idle = ctxRef?.isIdle() ?? true;
		if (lastStatus(TASK_ID).startsWith("done:") && !pendingLog) {
			if (idle) return void closeSelf();
			closeWhenSettled = true;
			return;
		}
		closeWhenSettled = true;
		const msg = "The user closed this task. Call task_status with state done and a one-line outcome, then stop.";
		if (idle) pi.sendUserMessage(msg);
		else pi.sendUserMessage(msg, { deliverAs: "followUp" });
	}

	async function setTab(emoji: string) {
		if (!TASK_ID || emoji === shownEmoji) return;
		const meta = readMeta(TASK_ID);
		const session = meta?.rex_session ?? process.env.REX_SESSION;
		if (!meta || !session) return;
		shownEmoji = emoji;
		try {
			const windows: Window[] = (await sessionView(session)).windows ?? [];
			const win =
				windows.find((w) => w.window_id === meta.window_id) ??
				windows.find((w) => process.env.REX_BLOCK && containsBlock(w.layers, process.env.REX_BLOCK));
			if (!win) return;
			const prefix = (win.label ?? "").match(/^[\p{Ll}\d] · /u)?.[0] ?? ""; // keep Rex's tab letter
			await rex("api", "call", "session.set_window_label", JSON.stringify({ session_id: session, window_id: win.window_id, label: `${prefix}${emoji} ${meta.name}` }));
		} catch {
			shownEmoji = "";
		}
	}

	if (TASK_ID) {
		pi.registerTool({
			name: "task_status",
			label: "Task status",
			description:
				"Report this task's state to the master session: working (new phase), needs-decision (question for the user), blocked (cannot continue), done (one-line outcome).",
			parameters: Type.Object({
				state: StringEnum(["working", "needs-decision", "blocked", "done"] as const),
				note: Type.String({ description: "One short line" }),
				title: Type.Optional(Type.String({ description: "2-5 word task name for the tab, ticket ID first if any" })),
			}),
			async execute(_id, params) {
				const title = params.title && cleanTitle(params.title);
				const meta = readMeta(TASK_ID);
				if (title && meta) {
					const root = rootName(meta.name);
					const bare = title.toLowerCase().startsWith(root.toLowerCase()) ? title.slice(root.length).trim() || title : title;
					const name = `${root} - ${bare}`;
					if (name !== meta.name) {
						writeMeta({ ...meta, name });
						pi.setSessionName(name);
						shownEmoji = "";
						void setTab(EMOJI.running);
					}
				}
				const note = params.note.replace(/\s+/g, " ").trim();
				appendFileSync(join(taskDir(TASK_ID), "status.log"), `${new Date().toISOString()} ${params.state}: ${note}\n`);
				lastState = params.state;
				if (params.state === "done" && !logging) pendingLog = true;
				return { content: [{ type: "text", text: `Recorded ${params.state}.` }], details: {} };
			},
		});

		pi.on("before_agent_start", async (event) => {
			const meta = readMeta(TASK_ID);
			if (meta) event.systemPromptOptions.sections.task_protocol = PROTOCOL(meta);
		});

		pi.on("agent_start", async () => {
			if (!logging) lastState = undefined;
			void setTab(EMOJI.running);
		});

		pi.on("agent_settled", async () => {
			if (pendingLog) {
				pendingLog = false;
				logging = true;
				pi.sendUserMessage("/skill:log Write the log entry for what this task accomplished.", { expandPromptTemplates: true });
				return;
			}
			logging = false;
			if (closeWhenSettled) return void closeSelf();
			const s = lastState === "done" || lastState === "blocked" || lastState === "needs-decision" ? lastState : "idle";
			void setTab(EMOJI[s]);
		});
	}

	function drainInbox(id: string) {
		const dir = taskDir(id);
		for (const line of readNew(join(dir, "inbox"), join(dir, "inbox.offset"))) {
			let rec: { text?: string; type?: string };
			try {
				rec = JSON.parse(line);
			} catch {
				continue;
			}
			if (rec.type === "done") {
				finish();
				continue;
			}
			const text = rec.text;
			if (!text) continue;
			const msg = `Message from the master session: ${text}`;
			if (ctxRef?.isIdle()) pi.sendUserMessage(msg);
			else pi.sendUserMessage(msg, { deliverAs: "followUp" });
		}
	}

	// ───────────────────────────── startup ─────────────────────────────

	pi.on("session_start", async (_event, ctx) => {
		ctxRef = ctx;
		closeWatchers();
		watchAsMaster(ctx.sessionManager.getSessionId());
		if (!TASK_ID) return;

		const meta = readMeta(TASK_ID);
		if (!meta) return;
		const dir = taskDir(TASK_ID);
		watchers.push(
			watch(dir, (_e, file) => {
				if (file?.toString() === "inbox") drainInbox(TASK_ID);
			}),
		);

		if (meta.started) return drainInbox(TASK_ID); // /reload or resume: don't restart the task
		writeMeta({ ...meta, started: true });
		const start = () => pi.sendUserMessage(`Go ahead: ${meta.brief ?? meta.task}`);
		ctx.compact({
			customInstructions: `Keep only what is needed for this next task: ${meta.brief ?? meta.task}`,
			onComplete: start,
			onError: (error) => {
				ctx.ui.notify(`Compaction skipped: ${error.message}`, "warning");
				start();
			},
		});
	});
}
