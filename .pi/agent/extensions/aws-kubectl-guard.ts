/**
 * AWS profile + kubectl context guard.
 *
 * Blocks write operations against the wrong AWS profile / k8s cluster.
 *
 *   AWS writes allowed only on profile:    personal
 *   AWS profiles read-only:                cloud-staging, cloud-production (+ any other)
 *   kubectl writes allowed only on contexts: foundation-personal-phil, homelab
 *
 * Detection (per command):
 *   AWS profile        →  AWS_PROFILE=… , --profile=… , else $AWS_PROFILE inherited
 *   kubectl context    →  --context=…   , else cached `kubectl config current-context`
 *
 * Detection of read-vs-write is allowlist based:
 *   AWS read verbs:     describe-* / list-* / get-* / head-* / search-* / view-* /
 *                       lookup-* / select / scan / query / batch-get-* / simulate-* /
 *                       validate-* / estimate-* / preview-* / test-*
 *   kubectl read verbs: get / describe / logs / top / explain / version /
 *                       cluster-info / api-resources / api-versions / auth /
 *                       diff / kustomize / config view|current-context|get-* / completion
 *
 * Anything not on these lists is treated as a write, the user is prompted, and pi
 * blocks the command if the user declines.
 *
 * Also exposes status segments:  ctx.ui.setStatus("aws", …),  ctx.ui.setStatus("kube", …)
 */

import { isToolCallEventType, type ExtensionAPI } from "@mariozechner/pi-coding-agent";

const AWS_WRITE_PROFILES = new Set<string>(["personal"]);
const KUBE_WRITE_CONTEXTS = new Set<string>(["foundation-personal-phil", "homelab"]);

const AWS_READ_VERB_RE =
	/^(describe-|list-|get-|head-|show-|search-|view-|lookup-|batch-get-|simulate-|validate-|estimate-|preview-|test-|generate-presigned-|generate-data-key-without-plaintext|select$|scan$|query$|help$)/;

const KUBE_READ_VERBS = new Set<string>([
	"get",
	"describe",
	"logs",
	"top",
	"explain",
	"version",
	"cluster-info",
	"api-resources",
	"api-versions",
	"auth", // `auth can-i` is read-only; reauth flows aren't dangerous
	"diff",
	"kustomize",
	"completion",
	"options",
	"help",
]);

function trimQuotes(s: string): string {
	return s.replace(/^['"]|['"]$/g, "");
}

function detectAwsProfile(cmd: string): string | undefined {
	const inline = cmd.match(/AWS_PROFILE=(\S+)/);
	if (inline) return trimQuotes(inline[1]);
	const flag = cmd.match(/--profile[= ](\S+)/);
	if (flag) return trimQuotes(flag[1]);
	return process.env.AWS_PROFILE;
}

function detectKubeContext(cmd: string, cached: string | undefined): string | undefined {
	const flag = cmd.match(/--context[= ](\S+)/);
	if (flag) return trimQuotes(flag[1]);
	return cached;
}

// Match `aws` invoked at start of command, after `;`, `&&`, `|`, env assignments, or `sudo`
const AWS_INVOKED_RE = /(?:^|[;&|]|\s)(?:[A-Z_][A-Z0-9_]*=\S+\s+)*(?:sudo\s+)?aws\s+(\S+)\s+(\S+)/;
const KUBE_INVOKED_RE = /(?:^|[;&|]|\s)(?:[A-Z_][A-Z0-9_]*=\S+\s+)*(?:sudo\s+)?(kubectl|k|helm)\s+(\S+)/;

interface AwsHit {
	service: string;
	verb: string;
}
interface KubeHit {
	tool: string;
	verb: string;
	rest: string;
}

function findAwsCommand(cmd: string): AwsHit | undefined {
	const m = cmd.match(AWS_INVOKED_RE);
	if (!m) return undefined;
	return { service: m[1], verb: m[2] };
}

function findKubeCommand(cmd: string): KubeHit | undefined {
	const m = cmd.match(KUBE_INVOKED_RE);
	if (!m) return undefined;
	const idx = m.index ?? 0;
	const rest = cmd.slice(idx + m[0].length);
	return { tool: m[1], verb: m[2], rest };
}

function isAwsReadOnly(verb: string): boolean {
	return AWS_READ_VERB_RE.test(verb);
}

function isKubeReadOnly(hit: KubeHit): boolean {
	if (KUBE_READ_VERBS.has(hit.verb)) return true;
	// `kubectl config *` only mutates the local kubeconfig, never the cluster
	if (hit.verb === "config") return true;
	return false;
}

function shortPath(): string {
	const home = process.env.HOME ?? "";
	const cwd = process.cwd();
	return home && cwd.startsWith(home) ? `~${cwd.slice(home.length)}` : cwd;
}

export default function (pi: ExtensionAPI) {
	let kubeContext: string | undefined;
	let awsProfile: string | undefined = process.env.AWS_PROFILE;

	const refreshKube = async () => {
		const r = await pi
			.exec("kubectl", ["config", "current-context"], { timeout: 3000 })
			.catch(() => undefined);
		kubeContext = r?.stdout.trim() || undefined;
	};

	const refreshAws = () => {
		awsProfile = process.env.AWS_PROFILE;
	};

	const updateStatuses = (ctx: any) => {
		const thm = ctx.ui.theme;
		const okAws = awsProfile ? AWS_WRITE_PROFILES.has(awsProfile) : false;
		const okKube = kubeContext ? KUBE_WRITE_CONTEXTS.has(kubeContext) : false;

		const awsLabel = awsProfile ?? "—";
		const kubeLabel = kubeContext ?? "—";

		// Nerd Font icons:
		//   AWS           (nf-fa-aws)         → OneDark Pro yellow (warning)
		//   Kubernetes  󱃾  (nf-md-kubernetes)  → OneDark Pro blue   (accent)
		// Color is fixed regardless of safety state. Writes against the wrong
		// profile/cluster are still gated by `tool_call` further down.
		void okAws;
		void okKube;
		ctx.ui.setStatus(
			"aws",
			thm.fg("warning", "☁") + thm.fg("dim", " aws ") + thm.fg("warning", awsLabel),
		);
		// #61afef = rgb(97,175,239) — hardcoded blue since accent is now orange.
		const kubeBlue = (s: string) => `\x1b[38;2;97;175;239m${s}\x1b[0m`;
		ctx.ui.setStatus(
			"kube",
			kubeBlue("󱃾") + thm.fg("dim", " k8s ") + kubeBlue(kubeLabel),
		);
	};

	pi.on("session_start", async (_event, ctx) => {
		await refreshKube();
		refreshAws();
		updateStatuses(ctx);
	});

	pi.on("turn_end", async (_event, ctx) => {
		// Re-detect after each turn in case the user/agent switched profile/context
		const oldKube = kubeContext;
		const oldAws = awsProfile;
		await refreshKube();
		refreshAws();
		if (oldKube !== kubeContext || oldAws !== awsProfile) updateStatuses(ctx);
	});

	pi.registerCommand("ctx-refresh", {
		description: "Refresh AWS profile / kubectl context indicators",
		handler: async (_args, ctx) => {
			await refreshKube();
			refreshAws();
			updateStatuses(ctx);
			ctx.ui.notify(
				`AWS: ${awsProfile ?? "(unset)"}    k8s: ${kubeContext ?? "(unknown)"}`,
				"info",
			);
		},
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return;
		const cmd = event.input.command ?? "";

		// AWS guard --------------------------------------------------------
		const aws = findAwsCommand(cmd);
		if (aws && !isAwsReadOnly(aws.verb)) {
			const profile = detectAwsProfile(cmd);
			if (!profile || !AWS_WRITE_PROFILES.has(profile)) {
				const ok = await ctx.ui.confirm(
					"AWS write blocked",
					`Profile "${profile ?? "(unset)"}" is read-only.\n` +
						`  command:  aws ${aws.service} ${aws.verb} …\n` +
						`  cwd:      ${shortPath()}\n\n` +
						`Writes are only allowed on: ${[...AWS_WRITE_PROFILES].join(", ")}.\n` +
						`Allow anyway?`,
				);
				if (!ok) {
					return {
						block: true,
						reason: `AWS profile "${profile ?? "(unset)"}" is read-only (write profiles: ${[
							...AWS_WRITE_PROFILES,
						].join(", ")}).`,
					};
				}
			}
		}

		// kubectl / helm guard --------------------------------------------
		const kube = findKubeCommand(cmd);
		if (kube && !isKubeReadOnly(kube)) {
			const context = detectKubeContext(cmd, kubeContext);
			if (!context || !KUBE_WRITE_CONTEXTS.has(context)) {
				const ok = await ctx.ui.confirm(
					"kubectl write blocked",
					`Context "${context ?? "(unknown)"}" is read-only.\n` +
						`  command:  ${kube.tool} ${kube.verb} …\n\n` +
						`Writes are only allowed on: ${[...KUBE_WRITE_CONTEXTS].join(", ")}.\n` +
						`Allow anyway?`,
				);
				if (!ok) {
					return {
						block: true,
						reason: `kubectl context "${context ?? "(unknown)"}" is read-only (write contexts: ${[
							...KUBE_WRITE_CONTEXTS,
						].join(", ")}).`,
					};
				}
			}
		}

		// Refresh cached state after switch commands
		if (/kubectl\s+config\s+use-context|\bkubectx\b/.test(cmd)) {
			setTimeout(() => {
				refreshKube().then(() => updateStatuses(ctx));
			}, 250);
		}
		if (/aws-switch-profile|aws\s+sso\s+login/.test(cmd)) {
			setTimeout(() => {
				refreshAws();
				updateStatuses(ctx);
			}, 250);
		}
	});
}
