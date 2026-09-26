/**
 * nvim-cursor — query a running Neovim instance for its exact cursor
 * position, buffer path, mode, and visual selection via nvim's RPC socket.
 *
 * Discovers nvim sockets in /run/user/<uid>/nvim.* (the default --listen
 * directory).
 *
 * Registers:
 *   "/nvim" command — prints the cursor position to the UI.
 *   "nvim_cursor" tool — model-callable; returns the same info as JSON.
 */

import { execFile } from "node:child_process";
import { readdirSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "@earendil-works/pi-ai";

export interface NvimCursor {
	socket: string;
	buffer: string;
	line: number;
	col: number;
	lineCount: number;
	mode: string; // "n", "v", "V", "i", "R", ...
	visualStart?: string; // "<line>:<col>"
	visualEnd?: string; // ">line>:<col>"
	textBefore: string; // text on the cursor line up to the cursor
	textAfter: string; // text from the cursor to end of line
}

function execNvimExpr(socket: string, expr: string): Promise<string> {
	return new Promise((resolve, reject) => {
		execFile(
			"nvim",
			["--server", socket, "--remote-expr", expr],
			{ timeout: 3000, encoding: "utf8" },
			(err, stdout) => (err ? reject(err) : resolve(stdout.trim())),
		);
	});
}

function findSockets(): string[] {
	const uid = process.getuid?.() ?? 1000;
	const dir = `/run/user/${uid}`;
	try {
		return readdirSync(dir)
			.filter((f) => f.startsWith("nvim."))
			.map((f) => `${dir}/${f}`);
	} catch {
		return [];
	}
}

/**
 * One RPC round-trip per socket. json_encode escapes everything for us;
 * expand("%:p") returns the full path.
 */
const CURSOR_EXPR = [
	"json_encode({",
	'"buffer": expand("%:p"),',
	'"line": line("."),',
	'"col": col("."),',
	'"lineCount": line("$"),',
	'"mode": mode(1),',
	'"visualStart": join([getpos("\<")[1], getpos("\<")[2]], ":"),',
	'"visualEnd": join([getpos("\>")[1], getpos("\>")[2]], ":"),',
	'"textBefore": strpart(getline("."), 0, col(".") - 1),',
	'"textAfter": strpart(getline("."), col(".") - 1)',
	"})",
].join(" ");

export async function getCursor(): Promise<NvimCursor[]> {
	const sockets = findSockets();
	if (sockets.length === 0) return [];

	const results = await Promise.all(
		sockets.map(async (socket) => {
			const raw = await execNvimExpr(socket, CURSOR_EXPR).catch(() => null);
			if (!raw) return null;
			try {
				const parsed = JSON.parse(raw) as Omit<NvimCursor, "socket">;
				if (typeof parsed?.line !== "number") return null;
				if (parsed.mode === "n" && parsed.col === 0) parsed.visualStart = undefined;
				return { ...parsed, socket };
			} catch {
				return null;
			}
		}),
	);

	return results.filter((r): r is NvimCursor => r !== null);
}

function format(cursor: NvimCursor): string {
	const isVisual = cursor.mode === "v" || cursor.mode === "V" || cursor.mode === "\x16";
	if (isVisual && cursor.visualStart && cursor.visualEnd) {
		const s = cursor.visualStart;
		const e = cursor.visualEnd;
		if (s !== e) return `${cursor.buffer} ${s}–${e} (visual ${cursor.mode})`;
	}
	return `${cursor.buffer} ${cursor.line}:${cursor.col} (mode: ${cursor.mode})`;
}

export default function (pi: ExtensionAPI) {
	const cursorTool = {
		name: "nvim_cursor",
		label: "Nvim cursor",
		description:
			"Get the exact cursor position (buffer path, line, column, mode, optional visual selection, and the text on the cursor line) from any running Neovim instance on this machine via its RPC socket. Use this instead of scraping terminal output when you need to know what line the user is looking at.",
		parameters: Type.Object({}),
		async execute() {
			const cursors = await getCursor();
			if (cursors.length === 0) {
				return {
					content: [
						{
							type: "text" as const,
							text: "No running Neovim instance found (no /run/user/<uid>/nvim.* sockets).",
						},
					],
					details: undefined,
				};
			}
			const text = cursors.map(format).join("\n");
			return {
				content: [{ type: "text" as const, text }],
				details: { cursors },
			};
		},
	};

	pi.registerTool(cursorTool);

	pi.registerCommand("nvim", {
		description: "Show the cursor position in any running Neovim instance",
		handler: async (args, ctx) => {
			const cursors = await getCursor();
			if (cursors.length === 0) {
				ctx.ui.notify("No running Neovim instance found.", "warning");
				return;
			}
			ctx.ui.notify(cursors.map(format).join("\n"), "info");
		},
	});
}
