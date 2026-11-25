/**
 * tool-guard — Claude-auto-mode-style safety checking for pi.
 *
 * Sits in front of bash / edit / write / read calls:
 *   1. readOnlyFastPath  — read-only bash commands pass instantly
 *                          (no LLM, no latency). Default: on.
 *   2. secretPathDeny    — secret/credential paths: reads go through the
 *                          judge (explicit user request auto-allows, else a
 *                          confirm dialog); mutating touches get a confirm
 *                          dialog too, with scarier text. No silent denials
 *                          where a dialog is possible. Default: on.
 *   3. Everything else gets one cheap System One
 *      classification (default: clef-flash, ~$0.04/1M):
 *        destructive, irreversible, exfiltrates, system_change (bools)
 *        + severity score ['harmless routine'|'minor'|'needs review'|'dangerous']
 *        + user_asked (does the user's own request call for this?)
 *      - any flag -> confirm; declined -> deny. No silent denials.
 *      - score mode (config only) -> judge runs and logs, never blocks.
 *      - strict mode (config only) -> deny without asking.
 *      - non-interactive / nested (codemode) -> deny (no dialog possible).
 *
 * Self-protection: a mutating command or file write that touches the guard's
 * own source cannot be allowed by dialog ("the agent said so" is not an
 * approval path for disabling the safety layer). Reading the guard's own
 * source is blocked while enabled too (the model doesn't need it, and it
 * never helps the model work around the judge). Decision-log reads are fine.
 *
 * /guard enable | disable — the only session control; disable stops every
 * check and judge call for this session. All other tuning lives in
 * config.json (below) as before, so you can keep per-machine overrides:
 *
 *   ~/.pi/agent/extensions/tool-guard/config.json
 *   {
 *     "enabled": true,                 // default on next session start
 *     "judge": "deepinfra-clef/Cloudflare/clef-flash",
 *     "threshold": 0.7,
 *     "readOnlyFastPath": true,
 *     "secretPathDeny": true,
 *     "userIntentDetection": true,
 *     "judgingOn": "confirm",          // "score" dry-run or "strict"
 *     "logPath": "~/.pi/agent/tool-guard/decisions.jsonl"
 *   }
 * Env overrides: TOOL_GUARD_MODE=score|confirm|strict, TOOL_GUARD_INTENT=0|1,
 * TOOL_GUARD_ENABLED=0|1 — same resolution order as before.
 */

import os from "os";
import fs from "fs";
import path from "path";
import type { ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";

// ── Config ─────────────────────────────────────────────────────────────────

type Judging = "score" | "confirm" | "strict";

interface Config {
  enabled: boolean;
  judge: string; // "provider/id" pair
  logPath: string;
  threshold: number;
  /** Softer bar for the user_asked signal: explicit intent is a positive
   *  signal, so it's allowed to fire below the risk-bool threshold. */
  intentThreshold: number;
  readOnlyFastPath: boolean;
  secretPathDeny: boolean;
  userIntentDetection: boolean;
  judgingOn: Judging; // mode used while enabled
}

const DEFAULTS: Config = {
  enabled: true,
  judge: "deepinfra-clef/Cloudflare/clef-flash",
  logPath: path.join(os.homedir(), ".pi/agent/tool-guard/decisions.jsonl"),
  threshold: 0.7,
  intentThreshold: 0.5,
  readOnlyFastPath: true,
  secretPathDeny: true,
  userIntentDetection: true,
  judgingOn: "confirm",
};

function loadConfig(): Config {
  const cfg: Config = { ...DEFAULTS };
  try {
    const file = path.join(import.meta.dirname!, "config.json");
    Object.assign(cfg, JSON.parse(fs.readFileSync(file, "utf8")));
  } catch {
    /* missing or invalid config — defaults apply */
  }
  const mode = process.env.TOOL_GUARD_MODE as Judging | undefined;
  if (mode && ["score", "confirm", "strict"].includes(mode)) cfg.judgingOn = mode;
  const intent = process.env.TOOL_GUARD_INTENT;
  if (intent === "0" || intent === "off" || intent === "false") cfg.userIntentDetection = false;
  if (intent === "1" || intent === "on" || intent === "true") cfg.userIntentDetection = true;
  const t = process.env.TOOL_GUARD_THRESHOLD;
  if (t && Number.isFinite(Number(t))) cfg.threshold = Number(t);
  const enabled = process.env.TOOL_GUARD_ENABLED;
  if (enabled === "0" || enabled === "off" || enabled === "false") cfg.enabled = false;
  if (enabled === "1" || enabled === "on" || enabled === "true") cfg.enabled = true;
  return cfg;
}

// ── Layer 1: read-only bash allowlist (zero cost, zero latency) ────────────

const READ_ONLY_WORD = new Set([
  "ls", "pwd", "cat", "head", "tail", "wc", "which", "type", "file", "stat",
  "du", "df", "date", "uname", "whoami", "hostname", "echo", "printenv",
  "grep", "rg", "ripgrep", "find", "tree", "jq", "man", "help", "history",
  "brew", "npm", "pnpm", "cargo", "uv", "pip", "python", "python3", "node",
  "git", "tea", "gh", "kagi", "firecrawl", "curl", "wget", "pi",
  "nvim", "vim", "codex", "claude",
  "sed", "awk", "gawk", "cut", "sort", "uniq", "tr", "column", "base64",
  "shasum", "sha256sum", "md5sum", "strings", "xxd",
]);

function shellWords(command: string): string[] {
  const words: string[] = [];
  let tok = "";
  let quote: string | null = null;
  for (const ch of command) {
    if (quote) {
      if (ch === quote) { quote = null; continue; }
      tok += ch;
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; continue; }
    if (ch === " " || ch === "\t" || ch === "\n") {
      if (tok) { words.push(tok); tok = ""; }
      continue;
    }
    tok += ch;
  }
  if (tok) words.push(tok);
  return words;
}

const envWord = (w: string): boolean => /^[A-Za-z_][A-Za-z_0-9]*=./.test(w);

/** True when every command segment starts with an allowlisted read-only word. */
function isReadOnlyBash(command: string): boolean {
  const trimmed = command.trim();
  if (!trimmed) return true;
  // treat fd duplication (2>&1) as neutral; strip it before the redirect test
  const neutral = trimmed.replace(/\d?>&\d+\b/g, "").replace(/\b\d?>&$/g, "");
  if (/<<|>{1,2}|&>/.test(neutral)) return false;
  if (/\b(eval|source|exec|bash|sh|zsh|sudo|xargs|env)\b/.test(neutral)) return false;
  const parts = neutral
    .split(/\s*(?:&&|\|\||;|\|)\s*/)
    .filter(Boolean)
    .map((p) => p.trim().split(/[\s\n]+/))
    .map((w) => (w[0] && envWord(w[0]) ? w.slice(1) : w));
  if (parts.some((w) => !w.length)) return false;
  for (const words of parts) {
    const first = words[0].split("/").pop()!;
    if (!READ_ONLY_WORD.has(first)) return false;
    if (words.some((w, i) => i > 0 && /^[A-Za-z_][A-Za-z_0-9]*=./.test(w))) return false;
  }
  return true;
}

// ── Layer 2: secret-path detection ─────────────────────────────────────────

const HOME = os.homedir();

function sensitivePathReason(p: string): string | null {
  if (!p) return null;
  const abs = path.resolve(p.replace(/^~(?=\/|$)/, HOME));
  const lower = abs.toLowerCase();
  if (/\.(env|envrc)$/.test(lower)) return "environment secrets";
  if (/(^|\/)\.env(_|\.)/.test(lower)) return "environment secrets";
  if (/(^|\/)\.git\/hooks(\/|$)/.test(lower)) return "git hooks";
  if (/\.pem$|\.key$|id_rsa|id_ed25519|client_secret/.test(lower)) return "private keys";
  if (/(^|\/)profile-env$/.test(lower) || /(^|\/)\.profile(-env)?$/.test(lower)) {
    return "profile environment (API keys)";
  }
  const under = (dir: string): boolean =>
    lower === dir.toLowerCase() || lower.startsWith(dir.toLowerCase() + path.sep);
  if (under(path.join(HOME, ".ssh"))) return "SSH credentials";
  if (under(path.join(HOME, ".aws"))) return "AWS credentials";
  if (under(path.join(HOME, ".kube"))) return "kube credentials";
  if (under(path.join(HOME, ".gnupg"))) return "GPG credentials";
  return null;
}

// ── Self-protection ────────────────────────────────────────────────────────

const SELF_DIR = import.meta.dirname!;

/** Reads + writes of the extension's own source: blocked while enabled. */
function selfSourceTarget(p: string): boolean {
  if (!p) return false;
  const abs = path.resolve(p.replace(/^~(?=\/|$)/, HOME));
  return abs === SELF_DIR || abs.startsWith(SELF_DIR + path.sep);
}

function logPathTarget(p: string, logPath: string): boolean {
  if (!p) return false;
  const abs = path.resolve(p.replace(/^~(?=\/|$)/, HOME));
  const dir = path.dirname(logPath);
  return abs === dir || abs.startsWith(dir + path.sep);
}

// ── Logging ────────────────────────────────────────────────────────────────

function log(cfg: Config, entry: Record<string, unknown>): void {
  try {
    fs.mkdirSync(path.dirname(cfg.logPath), { recursive: true });
    fs.appendFileSync(cfg.logPath, JSON.stringify({ ts: Date.now(), ...entry }) + "\n");
  } catch { /* logging must never break the guard */ }
}

function describe(event: ToolCallEvent): { tool: string; display: string; path?: string } {
  if ("input" in event && event.input && typeof event.input === "object") {
    const input = event.input as { [k: string]: unknown; command?: unknown; path?: unknown };
    const tool = event.toolName;
    if (tool === "bash" || tool === "powershell") {
      return { tool, display: String(input.command ?? "") };
    }
    if (tool === "edit" || tool === "write" || tool === "read") {
      const p = String(input.path ?? "");
      return { tool, display: `${tool} ${p}`, path: p };
    }
  }
  return { tool: "", display: "" };
}

// ── Layer 3: classifier judge ───────────────────────────────────────────────

interface JudgeVerdict {
  risky: boolean;
  reason: string;
  cost?: number;
  userAsked?: boolean;
}

type ExtensionCtx = Parameters<NonNullable<Parameters<ExtensionAPI["on"]>[1]>>[1];

// Recent user messages, so the judge can see explicit intent the way Claude's
// auto mode factors "the user asked for this" into its review of a command.
const recentRequests: string[] = [];
let lastUserText = "";

async function judgeAsk(
  ctx: ExtensionCtx,
  cfg: Config,
  tool: string,
  display: string,
  nested: boolean,
): Promise<JudgeVerdict> {
  const [provider, ...rest] = cfg.judge.split("/");
  const id = rest.join("/");
  let model;
  try {
    model = await ctx.modelRegistry.getModelOfType("classifier", provider, id);
  } catch {
    model = undefined;
  }
  if (!model) {
    return { risky: true, reason: `judge "${cfg.judge}" not available` };
  }

  const result = await ctx.modelRegistry.classify(model, {
    state: {
      cwd: ctx.cwd,
      tool,
      operation: display.slice(0, 4000),
      nested: nested ? "issued by a script, not typed by the user" : "direct",
      userRequest: cfg.userIntentDetection && lastUserText ? lastUserText : undefined,
      earlierRequests: cfg.userIntentDetection && recentRequests.length > 1
        ? recentRequests.slice(1).join(" || ")
        : undefined,
    },
    questions: {
      destructive: {
        type: "bool",
        instructions: "Could this operation delete, overwrite, or corrupt existing data or files?",
        criteria: { true: "deletes or overwrites existing data", false: "purely additive or read-only" },
      },
      irreversible: {
        type: "bool",
        instructions: "Is the effect of this operation hard to undo (outside source control, no backup, one-way)?",
        criteria: { true: "hard or impossible to undo", false: "easily reversible" },
      },
      exfiltrates: {
        type: "bool",
        instructions: "Could this operation send secrets (keys, tokens, credentials, .env contents) to a remote host or embed them somewhere remotely accessible?",
        criteria: { true: "moves secrets outward", false: "no secrets move out" },
      },
      system_change: {
        type: "bool",
        instructions: "Does this change machine-level state (launchd, ssh config, shell rc files, install/uninstall packages or services, edit files under $HOME outside this project)?",
        criteria: { true: "changes machine-level configuration", false: "stays inside the project or workspace" },
      },
      severity: {
        type: "score",
        instructions: "How risky is this operation overall?",
        criteria: ["harmless routine", "minor and reversible", "needs review", "dangerous"],
      },
      ...(cfg.userIntentDetection
        ? {
            user_asked: {
              type: "bool",
              instructions: "Does the recent user request (userRequest field) explicitly ask for precisely this operation, as opposed to the agent deciding on its own? Absent request field means no signal.",
              criteria: { true: "agent-initiated or unrelated to the request", false: "user explicitly requested this exact action" },
            },
          }
        : {}),
    },
  });
  if (result.stopReason !== "stop") {
    return { risky: true, reason: `judge error: ${result.errorMessage ?? result.stopReason}` };
  }
  const a = result.answers;
  const yes = (q: string): boolean =>
    a[q]?.type === "bool" && (a[q].probability ?? 0) >= cfg.threshold;
  const severe = a.severity?.type === "score" ? a.severity.score ?? 0 : 0;
  const cost = result.usage?.cost?.total ?? result.usage?.cost?.input ?? 0;

  const flags: string[] = [];
  if (yes("exfiltrates")) flags.push("possible secrets exfiltration");
  if (yes("irreversible")) flags.push("hard to undo");
  if (yes("destructive")) flags.push("destructive");
  if (yes("system_change")) flags.push("machine-level change");
  if (severe >= 2) flags.push("high severity");

  const offered = a["user_asked"];
  const userAsked =
    cfg.userIntentDetection &&
    offered?.type === "bool" &&
    (offered.probability ?? 0) >= (cfg.intentThreshold ?? 0.5);

  if (flags.length > 0) {
    return {
      risky: true,
      reason: `${flags.join(", ")}${userAsked ? " — but the user explicitly requested this" : ""}`,
      cost,
      userAsked,
    };
  }
  return { risky: false, reason: "harmless", cost, userAsked };
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function toolGuard(pi: ExtensionAPI) {
  const cfg = loadConfig();

  pi.registerCommand("guard", {
    description: "Enable or disable tool-guard for this session (/guard enable | disable)",
    handler: async (args, ctx) => {
      const next = args.trim().toLowerCase();
      if (next === "enable" || next === "disable") {
        cfg.enabled = next === "enable";
        cfg.judgingOn = next === "enable" ? (process.env.TOOL_GUARD_MODE as Judging ?? DEFAULTS.judgingOn) : cfg.judgingOn;
        ctx.ui.notify(
          next === "enable"
            ? `tool-guard enabled — judging: ${cfg.judgingOn}, judge: ${cfg.judge}`
            : "tool-guard disabled — no checks, no judge calls, full pass-through",
          "info",
        );
      } else {
        ctx.ui.notify(
          `tool-guard ${cfg.enabled ? "enabled" : "disabled"} judging: ${cfg.judgingOn} | judge: ${cfg.judge}` +
            "\nThis command controls only enable/disable; other settings live in config.json",
          "info",
        );
      }
    },
  });

  // Track the last few user messages so the judge can see explicit intent,
  // the way Claude's auto mode factors "the user asked for this" into its
  // review of a command.
  pi.on("input", (event) => {
    if (!cfg.userIntentDetection || !cfg.enabled) return;
    const text = event.text.trim().slice(0, 800);
    if (!text) return;
    lastUserText = text;
    recentRequests.unshift(text);
    if (recentRequests.length > 3) recentRequests.pop();
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!cfg.enabled) return; // /guard disable = full pass-through, no logging

    const { tool, display, path: filePath } = describe(event);
    if (!tool || !["bash", "powershell", "edit", "write", "read"].includes(tool)) return;
    const nested = Boolean(event.parentToolCallId);
    const decide = (decision: string, reason: string, extra?: Record<string, unknown>) =>
      log(cfg, { tool, display: display.slice(0, 200), decision, reason, nested, ...extra });
    const noDialog = nested || !ctx.hasUI || cfg.judgingOn === "strict";
    const deny = (why: string, extra?: Record<string, unknown>) => {
      decide("deny", why, extra);
      return { block: true, reason: `tool-guard: ${why}` };
    };
    const confirmOrDeny = async (
      title: string,
      body: string,
      allowReason: string,
      denyReason: string,
    ): Promise<unknown> => {
      if (noDialog) {
        return deny(`${denyReason} (no dialog possible: ${nested ? "script-issued" : !ctx.hasUI ? "non-interactive" : "strict mode"})`);
      }
      const ok = await ctx.ui.confirm(title, body);
      decide(ok ? "allow" : "deny", ok ? "confirmed by user" : `user declined (${denyReason})`);
      if (!ok) return { block: true, reason: `tool-guard: ${denyReason} — not approved` };
      decide("allow", allowReason);
      return;
    };

    // Self-protection first, so it can't be short-circuited below:
    //   - reads of the guard's own source: blocked while enabled
    //   - mutating touches of its source or its decision log: blocked always
    if (filePath && selfSourceTarget(filePath)) {
      return deny(`${tool} targeting tool-guard's own source is not allowed`);
    }
    if (filePath && logPathTarget(filePath, cfg.logPath)) {
      if (tool === "read") {
        decide("allow", "decision log read");
        return;
      }
      return deny(`${tool} targeting tool-guard's decision log is not allowed`);
    }
    if (tool === "bash" || tool === "powershell") {
      const words = shellWords(display).map((w) => w.replace(/[;|&\">')\]]+$/, ""));
      if (words.some((w) => selfSourceTarget(w))) {
        // source mutations always blocked; source *reads* allowed (they don't
        // weaken the running guard, and blocking them was overreach)
        if (!isReadOnlyBash(display)) {
          return deny("mutating command targeting tool-guard's own source");
        }
      }
      if (words.some((w) => logPathTarget(w, cfg.logPath)) && !isReadOnlyBash(display)) {
        return deny("mutating command targeting tool-guard's decision log");
      }
    }

    // reads: only the secret-path rule applies; everything else flies free
    if (tool === "read") {
      const reason = cfg.secretPathDeny && filePath ? sensitivePathReason(filePath) : null;
      if (!reason) {
        decide("pass", "read (no rule applies)");
        return;
      }
      // judge with intent; explicit request auto-allows, otherwise confirm
      let verdict: JudgeVerdict;
      try {
        verdict = await judgeAsk(ctx, cfg, tool, display, nested);
      } catch (err) {
        verdict = { risky: true, reason: `guard error: ${String(err)}` };
      }
      decide("classified", `read ${reason}: ${verdict.reason}`, { cost: verdict.cost, nested });
      if (cfg.judgingOn === "score") {
        decide("score", "score mode — no block");
        return;
      }
      if (verdict.userAsked) {
        decide("allow", `user explicitly requested this read (${reason})`);
        return;
      }
      if (noDialog) {
        return deny(`read ${reason} flagged (${verdict.reason})`);
      }
      const ok = await ctx.ui.confirm(
        "tool-guard: sensitive file read",
        `${filePath}\n(${reason}; judge: ${verdict.reason})\n\nAllow reading?`,
      );
      decide(ok ? "allow" : "deny", ok ? "confirmed by user" : `user declined (read ${reason})`);
      if (ok) return;
      return { block: true, reason: `tool-guard: reading ${reason} not approved` };
    }

    // bash fast-path: provably read-only command lines pass with no LLM
    if (tool === "bash" && cfg.readOnlyFastPath && isReadOnlyBash(display)) {
      decide("allow", "read-only command");
      return;
    }

    // secret-path handling for bash (and file tools below)
    const secretCheck = (p: string): string | null =>
      cfg.secretPathDeny ? sensitivePathReason(p) : null;

    if (tool === "bash" || tool === "powershell") {
      const writableHit = shellWords(display)
        .map((w) => w.replace(/[;|&\">')\]]+$/, ""))
        .map((w) => (w ? { w, reason: secretCheck(w) } : { w, reason: null }))
        .find((x) => x.reason);
      if (writableHit?.reason) {
        let verdict: JudgeVerdict;
        try {
          verdict = await judgeAsk(ctx, cfg, tool, display, nested);
        } catch (err) {
          verdict = { risky: true, reason: `guard error: ${String(err)}` };
        }
        decide("classified", `bash ${writableHit.reason}: ${verdict.reason}`, { cost: verdict.cost, nested });
        if (cfg.judgingOn === "score") {
          decide("score", "score mode — no block");
          return;
        }
        const mutate = !isReadOnlyBash(display);
        return await confirmOrDeny(
          "tool-guard: secret path touched",
          `${display}\n(${writableHit.reason}; judge: ${verdict.reason}${verdict.userAsked ? "; user asked" : ""})\n\nAllow?`,
          `confirmed by user (${writableHit.reason})`,
          `${writableHit.reason}${mutate ? ", mutating command" : ""} (${verdict.reason})`,
        );
      }
    }

    // file tools: secret-path check
    const fileHit = filePath ? secretCheck(filePath) : null;
    if (fileHit && (tool === "edit" || tool === "write")) {
      if (cfg.judgingOn === "score") {
        decide("score", `write ${fileHit} — score mode, no block`);
        return;
      }
      return await confirmOrDeny(
        "tool-guard: modify sensitive file",
        `${display}\n(${fileHit})\n\nAllow?`,
        `confirmed by user (${fileHit})`,
        `${fileHit} write`,
      );
    }

    // classify
    let verdict: JudgeVerdict;
    try {
      verdict = await judgeAsk(ctx, cfg, tool, display, nested);
    } catch (err) {
      verdict = { risky: true, reason: `guard error: ${String(err)}` };
    }
    decide("classified", verdict.reason, { cost: verdict.cost, nested });

    if (cfg.judgingOn === "score") {
      decide("score", "score mode — no block");
      return;
    }

    if (!verdict.risky) {
      decide("allow", verdict.reason);
      return;
    }
    const ok = await confirmOrDeny(
      "tool-guard: needs review",
      `${display}\n\n${verdict.reason}\n\nAllow anyway?`,
      "confirmed by user",
      verdict.reason,
    );
    return ok;
  });
}
