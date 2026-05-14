/**
 * Pi ntfy Notification Extension
 *
 * Sends push notifications via ntfy.sh when Pi needs your attention:
 * - When the agent finishes a response and is waiting for input (agent_end)
 * - When subagent control events indicate needs_attention
 * - Optionally on errors
 *
 * Configuration via environment variables:
 *   NTFY_SERVER      - ntfy server URL (default: "https://ntfy.sh")
 *   NTFY_TOPIC        - ntfy topic to publish to (default: "pi-<username>")
 *   NTFY_ACCESS_TOKEN - access token for authentication (required)
 *   NTFY_PRIORITY     - default priority 1-5 (default: "default")
 *   NTFY_NOTIFY       - which events to notify on, comma-separated
 *                        (default: "agent_end,needs_attention,error")
 *                        Options: agent_end, needs_attention, error
 *
 * Based on the Claude Code ntfy-notify.sh hook pattern.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import * as os from "node:os";

// --- Configuration ---

function loadConfig() {
	const server = process.env.NTFY_SERVER || "https://ntfy.sh";
	const username = os.userInfo().username;
	const topic = process.env.NTFY_TOPIC || `pi-${username}`;
	const token = process.env.NTFY_ACCESS_TOKEN || "";
	const priority = process.env.NTFY_PRIORITY || "default";
	const notifyEnv = process.env.NTFY_NOTIFY || "agent_end,needs_attention,error";
	const notifyOn = new Set(notifyEnv.split(",").map((s) => s.trim()));

	return { server, topic, token, priority, notifyOn };
}

// --- ntfy HTTP API ---

interface NtfyOptions {
	server: string;
	topic: string;
	token: string;
	title: string;
	message: string;
	priority?: string;
	tags?: string[];
	click?: string;
	actions?: Array<{ action: string; label: string; url?: string; command?: string }>;
}

/**
 * Strip non-ASCII characters from a string so it's safe for HTTP headers (ByteString).
 * Node.js fetch requires header values to be ByteString (each char <= 255).
 * Emoji like ✅ (U+2705, value 9989) and em dashes — (U+2014, value 8212) cause errors.
 * Tags use ntfy emoji shortcodes (ASCII) and are safe without sanitization.
 */
function asciiOnly(text: string): string {
	return text.replace(/[^\x00-\xff]/g, "").replace(/\s+/g, " ").trim();
}

async function sendNtfy(opts: NtfyOptions): Promise<void> {
	const url = `${opts.server.replace(/\/+$/, "")}/${opts.topic}`;

	const headers: Record<string, string> = {
		"Title": asciiOnly(opts.title),
		"Content-Type": "text/plain; charset=utf-8",
	};

	if (opts.token) {
		headers["Authorization"] = `Bearer ${opts.token}`;
	}

	if (opts.priority && opts.priority !== "default") {
		headers["Priority"] = opts.priority;
	}

	if (opts.tags && opts.tags.length > 0) {
		headers["Tags"] = opts.tags.join(",");
	}

	if (opts.click) {
		headers["Click"] = asciiOnly(opts.click);
	}

	if (opts.actions && opts.actions.length > 0) {
		headers["Actions"] = asciiOnly(
			opts.actions
				.map((a) => {
					if (a.url) return `${a.action}, ${a.label}, ${a.url}`;
					if (a.command) return `${a.action}, ${a.label}, ${a.command}`;
					return `${a.action}, ${a.label}`;
				})
				.join("; "),
		);
	}

	try {
		const response = await fetch(url, {
			method: "POST",
			headers,
			body: opts.message,
			signal: AbortSignal.timeout(5000),
		});

		if (!response.ok) {
			console.error(`[ntfy] HTTP ${response.status}: ${await response.text().catch(() => "unknown error")}`);
		}
	} catch (err: any) {
		// Don't crash pi if ntfy is unreachable — just log
		console.error(`[ntfy] Failed to send notification: ${err.message}`);
	}
}

// --- Helpers ---

function truncate(text: string, maxLen: number): string {
	if (text.length <= maxLen) return text;
	return text.slice(0, maxLen - 1) + "…";
}

function extractLastAssistantText(messages: any[]): string {
	// Walk messages from the end to find the last assistant text
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content ?? []) {
				if (part.type === "text" && part.text?.trim()) {
					return part.text.trim();
				}
			}
		}
	}
	return "";
}

// --- Extension ---

const SUBAGENT_CONTROL_MESSAGE_TYPE = "subagent_control_notice";

export default function ntfyNotify(pi: ExtensionAPI) {
	const config = loadConfig();

	if (!config.token) {
		console.warn("[ntfy] NTFY_ACCESS_TOKEN not set — ntfy notifications disabled");
		return;
	}

	// Track the last notification time to avoid spamming
	// (e.g., rapid agent_end events from subagent completions)
	const COOLDOWN_MS = 2000; // 2 second cooldown between notifications
	let lastNotifyTime = 0;

	async function notify(title: string, message: string, options?: Partial<NtfyOptions>) {
		const now = Date.now();
		if (now - lastNotifyTime < COOLDOWN_MS) return;
		lastNotifyTime = now;

		await sendNtfy({
			server: config.server,
			topic: config.topic,
			token: config.token,
			title,
			message,
			priority: options?.priority ?? config.priority,
			tags: options?.tags,
			click: options?.click,
			actions: options?.actions,
		});
	}

	// --- agent_end: Notify when Pi finishes processing and awaits input ---
	if (config.notifyOn.has("agent_end")) {
		pi.on("agent_end", async (event, ctx) => {
			const messages = event.messages ?? [];

			// Extract a short summary from the last assistant message
			const lastText = extractLastAssistantText(messages);
			const preview = lastText ? truncate(lastText.split("\n")[0], 100) : "Ready for input";

			// Priority 2 for normal completions (low), higher for errors
			const hasError = messages.some(
				(m: any) => m.role === "assistant" && m.stopReason === "error",
			);

			await notify(
				hasError ? "Pi - Error" : "Pi - Ready",
				preview,
				{
					priority: hasError ? "high" : "low",
					tags: hasError ? ["warning"] : ["white_check_mark"],
				},
			);
		});
	}

	// --- message: Listen for subagent control notices (needs_attention) ---
	if (config.notifyOn.has("needs_attention")) {
		pi.on("message_end", async (event, _ctx) => {
			const msg = event.message;
			if (msg.role !== "user" || msg.customType !== SUBAGENT_CONTROL_MESSAGE_TYPE) return;

			const details = msg.details as any;
			const controlEvent = details?.event;
			if (!controlEvent || controlEvent.type !== "needs_attention") return;

			const agent = controlEvent.agent || "unknown";
			const reason = controlEvent.reason || "idle";
			const message = controlEvent.message || "Subagent needs attention";

			await notify(
				`Pi - ${agent} needs attention`,
				truncate(message, 200),
				{
					priority: "high",
					tags: ["rotating_light"],
				},
			);
		});
	}

	// --- Error notifications ---
	if (config.notifyOn.has("error")) {
		pi.on("message_end", async (event, _ctx) => {
			const msg = event.message;
			if (msg.role !== "assistant" || msg.stopReason !== "error") return;

			// Skip if agent_end already handles this
			if (config.notifyOn.has("agent_end")) return;

			const errorText = Array.isArray(msg.content)
				? msg.content
						.filter((p: any) => p.type === "text")
						.map((p: any) => p.text)
						.join("\n")
				: "";
			const preview = truncate(errorText.split("\n")[0], 100) || "Agent error";

			await notify(
				"Pi - Error",
				preview,
				{
					priority: "high",
					tags: ["warning"],
				},
			);
		});
	}
}