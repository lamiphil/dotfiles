/**
 * Splash screen extension — shows a centered ASCII art logo with gradient
 * colors, a welcome message, and a random quote on session start.
 * Dismisses on any keypress. Responsive to terminal size.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { Component } from "@earendil-works/pi-tui";
import { truncateToWidth } from "@earendil-works/pi-tui";

// ── Pi ASCII art (dome shape) ───────────────────────────────────────────────
const PI_ART = [
	"          ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●..          ",
	"       .●.●.●●●●●●●●●●●●●●●●●●●●●●.::.·.:              ",
	"      .●..●●●.●●●●●●●●●●●●●●●●●●●:.●                   ",
	"     .●..●●●●●●●●●●●●●●●●●●●●●●●...:::.::.::           ",
	"    .●●●..:..●●●●●●●●●●●●●●●●●●●●●●●●●●:::.::.::.     ",
	"   ●●.●●●●●●..●●●.●●●●●●●●●●●●.●●●.:::.:::.:          ",
	"   .●●●..:..●●●●●●.●●●●●●●●●●●..●●:.::.:::.::.:.      ",
	"  .●●●●.●●●●●●●●.●●●●●●●●●●●●●::::::::::::::::::.::   ",
	"  ●●●●●.●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●:::::::.::    ",
	"  ●:.●●..●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●::::.::.:      ",
	" ●.●●●●.●●●●●●●●..::::::::::::::::::::::::::::::::::::  ",
	"  ●●●●.●●●●●●.:.::::::::::::::::::::::::::::::.::::      ",
	"  .:.::●●●●●●●●:::::::::::::::::::::::::::::::::::       ",
	"    .::::::::::::::::::::::::::::::::::::::::::::::        ",
	"      .:.::::::::::::::::::::::::::::::::::::::.           ",
	"         ..:::::::::::::::::::::::::::::::::..             ",
	"             ..::::::::::::::::::::::::::..                ",
	"                  ....::::::::::....                       ",
];

const QUOTES = [
	'"The best way to predict the future is to invent it." — Alan Kay',
	'"Programs must be written for people to read." — Abelson & Sussman',
	'"Simplicity is prerequisite for reliability." — Edsger Dijkstra',
	'"First, solve the problem. Then, write the code." — John Johnson',
	'"Any sufficiently advanced technology is indistinguishable from magic." — Arthur C. Clarke',
	'"Talk is cheap. Show me the code." — Linus Torvalds',
	'"The Omnissiah knows all, comprehends all." — Adeptus Mechanicus',
	'"Make it work, make it right, make it fast." — Kent Beck',
	'"Code is like humor. When you have to explain it, it\'s bad." — Cory House',
	'"Controlling complexity is the essence of computer programming." — Brian Kernighan',
];

// ── Gradient helpers ────────────────────────────────────────────────────────
function hslToRgb(h: number, s: number, l: number): [number, number, number] {
	const c = (1 - Math.abs(2 * l - 1)) * s;
	const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
	const m = l - c / 2;
	let r = 0, g = 0, b = 0;
	if (h < 60) { r = c; g = x; }
	else if (h < 120) { r = x; g = c; }
	else if (h < 180) { g = c; b = x; }
	else if (h < 240) { g = x; b = c; }
	else if (h < 300) { r = x; b = c; }
	else { r = c; b = x; }
	return [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)];
}

function gradientLine(line: string, row: number, totalRows: number): string {
	const t = row / Math.max(1, totalRows - 1);
	return line.split("").map((ch, col) => {
		if (ch === " ") return ch;
		const hue = 180 - t * 50 + (col * 0.3);
		const sat = ch === "●" ? 0.8 : ch === ":" ? 0.4 : 0.6;
		const lit = ch === "●" ? 0.55 : ch === "." ? 0.35 : 0.45;
		const [r, g, b] = hslToRgb(hue % 360, sat, lit);
		return `\x1b[38;2;${r};${g};${b}m${ch}\x1b[0m`;
	}).join("");
}

function scaleArt(art: string[], maxWidth: number, maxHeight: number): string[] {
	let scaled = art;

	// Vertical: skip every other line if art is too tall
	if (scaled.length > maxHeight) {
		const result: string[] = [];
		const step = scaled.length / maxHeight;
		for (let i = 0; i < maxHeight; i++) {
			result.push(scaled[Math.floor(i * step)]);
		}
		scaled = result;
	}

	// Horizontal: trim each line symmetrically if too wide
	if (Math.max(...scaled.map(l => l.length)) > maxWidth) {
		scaled = scaled.map(line => {
			if (line.length <= maxWidth) return line;
			const excess = line.length - maxWidth;
			const trimLeft = Math.floor(excess / 2);
			return line.slice(trimLeft, trimLeft + maxWidth);
		});
	}

	return scaled;
}

function wrapText(text: string, maxWidth: number): string[] {
	if (text.length <= maxWidth) return [text];
	const words = text.split(" ");
	const lines: string[] = [];
	let current = "";
	for (const word of words) {
		if (current.length + word.length + 1 > maxWidth && current.length > 0) {
			lines.push(current);
			current = word;
		} else {
			current = current ? current + " " + word : word;
		}
	}
	if (current) lines.push(current);
	return lines;
}

const dim = (s: string) => `\x1b[38;2;100;100;100m${s}\x1b[0m`;
const accent = (s: string) => `\x1b[38;2;86;182;194m${s}\x1b[0m`;
const bold = (s: string) => `\x1b[1m${s}\x1b[22m`;

export default function (pi: ExtensionAPI) {
	let shown = false;

	pi.on("session_start", async (event, ctx) => {
		if (!ctx.hasUI || shown || event.reason !== "startup") return;
		shown = true;

		const quote = QUOTES[Math.floor(Math.random() * QUOTES.length)];

		let overlayHandle: { hide(): void } | undefined;
		let unsubInput: (() => void) | undefined;

		// Listen for any keypress at the raw input level to dismiss
		unsubInput = ctx.ui.onTerminalInput(() => {
			unsubInput?.();
			overlayHandle?.hide();
		});

		void ctx.ui.custom<void>(
			(tui, _theme, _keybindings, done) => {
				const component: Component & { dispose?(): void } = {
					render(width: number): string[] {
						const height = tui.terminal.rows;
						const lines: string[] = [];

						// ── Tiny terminal: minimal splash ──
						if (width < 50 || height < 15) {
							const topPad = Math.max(0, Math.floor(height / 2) - 2);
							for (let i = 0; i < topPad; i++) lines.push("");
							const center = (s: string, w: number) => {
								const pad = Math.max(0, Math.floor((w - s.length) / 2));
								return " ".repeat(pad) + s;
							};
							lines.push(center("Welcome to Pi", width));
							lines.push("");
							lines.push(center("Press any key...", width));
							while (lines.length < height - 1) lines.push("");
							return lines;
						}

						// ── Layout mode: side-by-side (wide) or stacked (narrow) ──
						const artMaxW = Math.min(55, Math.floor(width * 0.55));
						const artMaxH = Math.min(PI_ART.length, Math.floor(height * 0.6));
						const art = scaleArt(PI_ART, artMaxW, artMaxH);
						const artWidth = Math.max(...art.map(l => l.length));

						const sideBySide = width >= 90;
						const rightColWidth = sideBySide ? Math.min(45, width - artWidth - 8) : Math.min(width - 4, 60);

						// Prepare right-column content
						const title = accent(bold("Welcome to Pi"));
						const hint = dim("Ctrl+P") + "  " + dim("commands");
						const quoteLines = wrapText(quote, rightColWidth).map(l => dim(l));

						if (sideBySide) {
							// ── Side-by-side layout ──
							const leftPad = Math.max(2, Math.floor((width - artWidth - 4 - rightColWidth) / 2));
							const contentHeight = Math.max(art.length, 8);
							const topPad = Math.max(1, Math.floor((height - contentHeight) / 2));

							for (let i = 0; i < topPad; i++) lines.push("");

							const midStart = Math.floor(art.length * 0.3);
							const rightContent: string[] = [];
							rightContent[midStart] = title;
							rightContent[midStart + 2] = hint;
							for (let q = 0; q < quoteLines.length; q++) {
								rightContent[midStart + 4 + q] = quoteLines[q];
							}

							for (let i = 0; i < art.length; i++) {
								const artLine = gradientLine(art[i], i, art.length);
								const right = rightContent[i] || "";
								const gap = "    ";
								lines.push(truncateToWidth(" ".repeat(leftPad) + artLine + gap + right, width));
							}
						} else {
							// ── Stacked layout (narrow terminal) ──
							const totalContent = art.length + 4 + quoteLines.length;
							const topPad = Math.max(1, Math.floor((height - totalContent) / 2));

							for (let i = 0; i < topPad; i++) lines.push("");

							// Centered art
							for (let i = 0; i < art.length; i++) {
								const artLine = gradientLine(art[i], i, art.length);
								const raw = art[i];
								const pad = Math.max(0, Math.floor((width - raw.length) / 2));
								lines.push(truncateToWidth(" ".repeat(pad) + artLine, width));
							}

							// Text below art, centered
							lines.push("");
							const centerPad = (len: number) => " ".repeat(Math.max(0, Math.floor((width - len) / 2)));
							lines.push(centerPad(14) + title);
							lines.push("");
							lines.push(centerPad(18) + hint);
							lines.push("");
							for (const ql of quoteLines) {
								lines.push(truncateToWidth(centerPad(quote.length > rightColWidth ? rightColWidth : quote.length) + ql, width));
							}
						}

						// Bottom padding
						while (lines.length < height - 1) lines.push("");
						return lines;
					},
					invalidate() {},
				};

				return component;
			},
			{
				overlay: true,
				overlayOptions: {
					anchor: "top-left" as const,
					width: "100%" as const,
					height: "100%" as const,
				},
				onHandle(handle) {
					overlayHandle = handle;
				},
			},
		);
	});
}
