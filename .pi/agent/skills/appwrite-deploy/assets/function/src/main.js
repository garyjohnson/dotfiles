// Appwrite function template — Node 16 / CommonJS / classic context API.
// Calls an OpenAI-compatible /v1/chat/completions endpoint, stores the exchange
// in a TablesDB table, and drafts a messaging email.
//
// Runtime contract (verified on Appwrite 1.9.6, node-16.0):
//   export via `module.exports = async (context)`
//   input body  -> context.req.bodyJson  (string -> parsed)
//   exec API key -> context.req.headers['x-appwrite-key']   (NOT an env var)
//   appwrite endpoint -> process.env.APPWRITE_FUNCTION_API_ENDPOINT (internal http; 308->https)
//   project id      -> process.env.APPWRITE_FUNCTION_PROJECT_ID
//   outbound http    -> native `https` (node 16 has no global fetch; follow 3xx)

"use strict";

const https = require("https");
const http = require("http");
const { URL } = require("url");

// --- configure via function variables (Appwrite console / CLI) ---
const OPENAI_BASE_URL = process.env.OPENAI_API_BASE_URL || "https://api.deepinfra.com/v1";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const OPENAI_MODEL = process.env.OPENAI_MODEL || "openai/gpt-oss-20b";

const APPWRITE_ENDPOINT = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
const APPWRITE_PROJECT_ID = process.env.APPWRITE_FUNCTION_PROJECT_ID;
const DATABASE_ID = process.env.DEMO_DATABASE_ID || "main";
const TABLE_ID = process.env.DEMO_TABLE_ID || "messages";
const TOPIC_ID = process.env.DEMO_TOPIC_ID || "activity";

// --- tiny HTTP helper that follows 3xx (node 16: no fetch) ---
function request(urlStr, { method = "GET", headers = {}, body = null, timeoutMs = 25000, _redirects = 0 } = {}) {
  return new Promise((resolve, reject) => {
    let u;
    try { u = new URL(urlStr); } catch (e) { return reject(new Error("bad url: " + urlStr)); }
    const lib = u.protocol === "http:" ? http : https;
    const opts = { method, hostname: u.hostname, port: u.port || (u.protocol === "https:" ? 443 : 80), path: u.pathname + u.search, headers: { ...headers } };
    if (body) opts.headers["Content-Length"] = Buffer.isBuffer(body) ? body.length : Buffer.byteLength(body);
    const req = lib.request(opts, (res) => {
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        const raw = Buffer.concat(chunks).toString("utf8");
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && _redirects < 5) {
          const next = new URL(res.headers.location, urlStr).toString();
          const keepBody = res.statusCode === 307 || res.statusCode === 308;
          resolve(request(next, { method: keepBody ? method : "GET", headers, body: keepBody ? body : null, timeoutMs, _redirects: _redirects + 1 }));
          return;
        }
        let parsed = null;
        try { parsed = raw ? JSON.parse(raw) : null; } catch (_) { /* not json */ }
        resolve({ status: res.statusCode, headers: res.headers, raw, data: parsed });
      });
    });
    req.on("timeout", () => req.destroy(new Error("timeout after " + timeoutMs + "ms")));
    req.on("error", reject);
    req.setTimeout(timeoutMs);
    if (body) req.write(body);
    req.end();
  });
}

function chatCompletion(messages) {
  return request(OPENAI_BASE_URL.replace(/\/$/, "") + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + OPENAI_API_KEY },
    body: JSON.stringify({ model: OPENAI_MODEL, messages, max_tokens: 512 }),
  });
}

let apiKey = null;
function appwrite(path, { method = "GET", payload = null } = {}) {
  const headers = { "X-Appwrite-Project": APPWRITE_PROJECT_ID, "X-Appwrite-Response-Format": "1.9.0", "X-Appwrite-Key": apiKey };
  let body = null;
  if (payload !== null) { headers["Content-Type"] = "application/json"; body = JSON.stringify(payload); }
  return request(APPWRITE_ENDPOINT.replace(/\/$/, "") + path, { method, headers, body });
}

function escapeHtml(s) {
  return String(s || "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

module.exports = async (context) => {
  const log = (...a) => context.log(...a);
  const error = (...a) => context.error(...a);
  apiKey = (context.req.headers && (context.req.headers["x-appwrite-key"] || context.req.headers["X-Appwrite-Key"])) || "";

  let input = context.req.bodyJson || context.req.body;
  if (typeof input === "string") { try { input = JSON.parse(input || "{}"); } catch (_) { input = {}; } }
  if (!input || typeof input !== "object") input = {};
  const prompt = String(input.prompt || "").trim();
  const userId = String(input.userId || "").trim();

  log("exec start; prompt.len=" + prompt.length + " userId=" + (userId || "(none)") + " model=" + OPENAI_MODEL);
  if (!prompt) return context.res.json({ ok: false, error: "missing 'prompt'" }, 400);
  if (!OPENAI_API_KEY) return context.res.json({ ok: false, error: "OPENAI_API_KEY function variable not set" }, 500);

  // 1) OpenAI-compatible call
  let reply = "";
  try {
    const r = await chatCompletion([
      { role: "system", content: "You are a concise, friendly assistant. Reply in under 120 words." },
      { role: "user", content: prompt },
    ]);
    if (r.status >= 300) { error("openai " + r.status + ": " + r.raw.slice(0, 200)); return context.res.json({ ok: false, error: "upstream " + r.status, upstream: r.raw.slice(0, 200) }, 502); }
    reply = (((r.data || {}).choices || [])[0] || {}).message?.content || "";
    log("openai ok; reply.len=" + reply.length);
  } catch (e) { error("openai: " + e.message); return context.res.json({ ok: false, error: "upstream error: " + e.message }, 502); }

  // 2) Store row in TablesDB
  let row = null;
  if (apiKey) {
    try {
      const r = await appwrite("/tablesdb/" + DATABASE_ID + "/tables/" + TABLE_ID + "/rows", {
        method: "POST",
        payload: { rowId: "row-" + Date.now(), data: { userId: userId || "anonymous", prompt, response: reply, role: "assistant" }, permissions: userId ? ["read(\"user:" + userId + "\")"] : ["read(\"users\")"] },
      });
      if (r.status >= 300) error("tablesdb " + r.status + ": " + r.raw.slice(0, 200)); else row = r.data;
      log("stored row " + (row && row.$id));
    } catch (e) { error("tablesdb: " + e.message); }
  }

  // 3) Draft a messaging email (no SMTP provider needed for a draft)
  let message = null;
  if (apiKey && userId) {
    try {
      const r = await appwrite("/messaging/messages/email", {
        method: "POST",
        payload: { messageId: "msg-" + Date.now(), subject: "New reply", content: "<p>Q: <b>" + escapeHtml(prompt) + "</b></p><p>A: " + escapeHtml(reply) + "</p>", users: [userId], topics: [TOPIC_ID], draft: true, html: true },
      });
      if (r.status >= 300) error("messaging " + r.status + ": " + r.raw.slice(0, 200)); else message = r.data;
      log("drafted message " + (message && message.$id));
    } catch (e) { error("messaging: " + e.message); }
  }

  return context.res.json({ ok: true, prompt, response: reply, model: OPENAI_MODEL, row: row ? { $id: row.$id } : null, message: message ? { $id: message.$id, status: message.status } : null });
};
