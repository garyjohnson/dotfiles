// herdr-workspace-name.ts
//
// Auto-name the Herdr workspace tab from the session's task, via an LLM.
//
// - On the session's first user prompt, asks the active model (minimal
//   reasoning) for a 2-4 word label summarizing the underlying task —
//   e.g. "i've got a samsung t9, how do i test its speed" ->
//   "samsung-t9-speed-test" — and renames the Herdr workspace.
// - No heuristic fallback: if the model call fails, the label is left
//   untouched (we never name from raw input text).
// - Resuming/continuing a session names the workspace from the
//   conversation's earliest user message.
// - Clears the label back to the workspace default (cwd basename, "~"
//   for home) when pi exits, and resets it when a session starts with
//   no user messages yet (/new, fresh start).
//
// Only renames its own workspace (HERDR_WORKSPACE_ID), only in TUI mode.
// Assumes one agent session per workspace: in multi-pane workspaces the
// most recent session lifecycle event wins.
//
// Disable with: PI_HERDR_NAME_WORKSPACE=0
// Debug log:   ~/.pi/agent/logs/herdr-workspace-name.log
// @ts-nocheck

import { execFile, execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const DISABLED =
  process.env.PI_HERDR_NAME_WORKSPACE === "0" ||
  ["false", "off", "no"].includes((process.env.PI_HERDR_NAME_WORKSPACE || "").toLowerCase());

const HERDR_ENV = process.env.HERDR_ENV;
const workspaceId = process.env.HERDR_WORKSPACE_ID;
const herdrBin = process.env.HERDR_BIN_PATH || "herdr";
const LOG_FILE = path.join(os.homedir(), ".pi", "agent", "logs", "herdr-workspace-name.log");

function enabled() {
  return !DISABLED && HERDR_ENV === "1" && !!workspaceId;
}

function log(line) {
  try {
    fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
    fs.appendFileSync(LOG_FILE, `${new Date().toISOString()} ${line}\n`);
  } catch {
    // logging is best-effort
  }
}

function userText(message) {
  const content = message?.content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((block) => block?.type === "text")
      .map((block) => block?.text ?? "")
      .join(" ");
  }
  return "";
}

function slugify(text) {
  return String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+/, "")
    .replace(/-+$/, "")
    .slice(0, 32)
    .replace(/-+$/, "");
}

// The label Herdr itself uses for unnamed workspaces: cwd basename, "~" for home.
function defaultLabel() {
  const cwd = process.cwd();
  const home = os.homedir();
  if (cwd === home || cwd === `${home}/`) return "~";
  const parts = cwd.split("/").filter(Boolean);
  return parts[parts.length - 1] || cwd;
}

const LABEL_SYSTEM_PROMPT = [
  "You name terminal workspace tabs for a coding agent workspace manager.",
  "You receive the first user message of a session. Reply with ONLY a 2-4 word label for the underlying task.",
  "Rules:",
  "- lowercase words joined by single hyphens; no quotes, no other punctuation, no explanation",
  "- name the concrete task: the key object/system plus the action or goal",
  "- drop all cruft: greetings, pronouns, filler like \"how do i\", \"i've got\", \"can you\", \"i want\"",
  "Examples:",
  "- \"how do i rename a herdr agent session\" -> herdr-workspace-rename",
  "- \"i've got a samsung t9 portable ssd, how do i benchmark its speed\" -> samsung-t9-speed-test",
  "- \"my rails app throws ActionView::Template::Error on the payments page\" -> fix-payments-template-error",
].join("\n");

async function modelLabel(ctx, text) {
  const model = ctx?.model;
  const registry = ctx?.modelRegistry;
  if (!model || typeof registry?.streamSimple !== "function") {
    log("model unavailable (no active model or registry.streamSimple)");
    return undefined;
  }

  const timeout = new Promise((_, reject) => {
    const timer = setTimeout(() => reject(new Error("naming model call timed out")), 30000);
    if (typeof timer.unref === "function") timer.unref();
  });

  const stream = registry.streamSimple(
    model,
    {
      systemPrompt: LABEL_SYSTEM_PROMPT,
      messages: [{ role: "user", content: text.slice(0, 800) }],
    },
    { reasoning: "minimal" }
  );

  const message = await Promise.race([stream.result(), timeout]);

  if (message?.stopReason === "error" || message?.stopReason === "aborted") {
    log(`model call stopReason=${message?.stopReason}`);
    return undefined;
  }
  const out = Array.isArray(message?.content)
    ? message.content.filter((block) => block?.type === "text").map((block) => block?.text ?? "").join(" ")
    : "";
  const label = slugify(out);
  if (!label) {
    log(`model returned no usable label (raw: ${JSON.stringify(out).slice(0, 160)})`);
    return undefined;
  }
  return label;
}

let exiting = false;

function renameWorkspace(label, reason) {
  if (exiting) return;
  execFile(herdrBin, ["workspace", "rename", workspaceId, label], { timeout: 10000 }, (error) => {
    if (error) log(`rename to "${label}" failed: ${error.message}`);
    else log(`renamed to "${label}" (${reason})`);
  });
}

function clearLabel(reason, sync = false) {
  const label = defaultLabel();
  const run = () => {
    try {
      execFileSync(herdrBin, ["workspace", "rename", workspaceId, label], { timeout: 5000, stdio: "ignore" });
      log(`reset to "${label}" (${reason})`);
    } catch (error) {
      log(`reset failed: ${error.message}`);
    }
  };
  if (sync) {
    // Synchronous so the rename completes before the pi process exits.
    exiting = true;
    run();
  } else {
    execFile(herdrBin, ["workspace", "rename", workspaceId, label], { timeout: 10000 }, (error) => {
      if (error) log(`reset to "${label}" failed: ${error.message}`);
      else log(`reset to "${label}" (${reason})`);
    });
  }
}

export default function (pi) {
  if (!enabled()) {
    return;
  }

  let namedThisSession = false;

  async function nameFrom(ctx, text, reason) {
    if (!text?.trim()) return;
    let label;
    try {
      label = await modelLabel(ctx, text);
    } catch (error) {
      log(`model call failed: ${error?.message ?? error}`);
    }
    if (!label) return; // never fall back to raw input text
    renameWorkspace(label, reason);
  }

  pi.on("session_start", async (event, ctx) => {
    // TUI only: headless modes have no pane the user can see renamed.
    if (ctx?.mode !== "tui") return;

    const reason = event?.reason;
    if (reason === "reload") return; // keep in-memory state across hot reloads
    namedThisSession = false;
    exiting = false;

    // Resume/fork/continue: name from the conversation's earliest user
    // message. Otherwise (fresh start, /new) reset the label to default.
    let first;
    try {
      const entries = ctx?.sessionManager?.getEntries?.() ?? [];
      first = entries
        .filter((entry) => entry?.type === "message" && entry?.message?.role === "user")
        .sort((a, b) => (a?.message?.timestamp ?? 0) - (b?.message?.timestamp ?? 0))[0];
    } catch {
      first = undefined;
    }
    const text = first ? userText(first.message) : "";
    if (text.trim()) {
      namedThisSession = true;
      void nameFrom(ctx, text, `session_start:${reason}`);
    } else {
      clearLabel(`session_start:${reason}`);
    }
  });

  pi.on("message_end", async (event, ctx) => {
    if (ctx?.mode !== "tui" || namedThisSession) return;
    if (event?.message?.role !== "user") return;

    const text = userText(event.message);
    if (!text.trim()) return;
    namedThisSession = true;
    void nameFrom(ctx, text, "first-prompt");
  });

  pi.on("session_shutdown", async (event, ctx) => {
    if (ctx?.mode !== "tui") return;
    // Clear on exit (Ctrl+C, Ctrl+D, SIGHUP, SIGTERM all arrive as "quit").
    // Runtime replacement (new/resume/fork/reload) is handled by the fresh
    // session_start in the replacement runtime.
    if (event?.reason !== "quit") return;
    clearLabel("quit", true);
  });
}
