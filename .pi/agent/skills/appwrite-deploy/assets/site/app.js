// Appwrite demo site — browser logic (Appwrite Web SDK, vendored ESM bundle).
import { Client, Account, TablesDB, Storage, Functions, Messaging, ID, Query } from "appwrite";

// config.js sets window.APPWRITE_CONFIG (no secrets — endpoint/project/IDs only).
const cfg = window.APPWRITE_CONFIG || { endpoint: "<set endpoint>", projectId: "<set projectId>", databaseId: "main", tableId: "messages", bucketId: "uploads", topicId: "activity", functionId: "demo-fn" };

const client = new Client().setEndpoint(cfg.endpoint).setProject(cfg.projectId);
const account = new Account(client);
const tables = new TablesDB(client);
const storage = new Storage(client);
const functions = new Functions(client);
const messaging = new Messaging(client);

const $ = (id) => document.getElementById(id);
let currentUser = null;

function row(who, body, extra = "") {
  const d = document.createElement("div");
  d.className = "row";
  d.innerHTML = `<span class="who"></span> <span class="small"></span><pre></pre>`;
  d.querySelector(".who").textContent = who;
  d.querySelector(".small").textContent = extra;
  d.querySelector("pre").textContent = body;
  return d;
}

async function refreshAuth() {
  try {
    currentUser = await account.get();
    $("account-status").textContent = "Signed in as " + currentUser.email;
    $("account-status").style.color = "var(--ok)";
    $("auth-btn").hidden = true; $("logout-btn").hidden = false;
    for (const id of ["sec-functions", "sec-databases", "sec-storage", "sec-messaging"]) $(id).hidden = false;
    loadRows(); loadFiles();
  } catch {
    currentUser = null;
    $("account-status").textContent = "Not signed in.";
    for (const id of ["sec-functions", "sec-databases", "sec-storage", "sec-messaging"]) $(id).hidden = true;
  }
}

$("auth-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const email = $("email").value.trim(), password = $("password").value;
  try {
    try { await account.create(ID.unique(), email, password); } catch (_) { /* exists? fall through */ }
    await account.createEmailPasswordSession(email, password);
    await refreshAuth();
  } catch (err) { $("account-status").textContent = "Auth failed: " + (err.message || err); $("account-status").style.color = "var(--err)"; }
});

$("logout-btn").addEventListener("click", async () => { try { await account.deleteSession("current"); } catch (_) {} await refreshAuth(); });

$("chat-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const prompt = $("prompt").value.trim();
  if (!prompt) return;
  const out = $("chat-output"); out.innerHTML = ""; out.appendChild(row("you", prompt));
  try {
    const exec = await functions.createExecution(cfg.functionId, JSON.stringify({ prompt, userId: currentUser ? currentUser.$id : "" }), false, "/", "POST");
    const raw = exec.responseBody ?? exec.response ?? "";   // 1.9.x = responseBody
    const res = typeof raw === "string" ? JSON.parse(raw || "{}") : (raw || {});
    if (res.ok) { out.appendChild(row("assistant", res.response, res.model)); loadRows(); }
    else out.appendChild(row("error", res.error || JSON.stringify(res), "status " + exec.status));
  } catch (err) { out.appendChild(row("error", err.message || String(err))); }
});

async function loadRows() {
  const el = $("rows"); el.innerHTML = "";
  try {
    const res = await tables.listRows(cfg.databaseId, cfg.tableId, [Query.orderDesc("$createdAt"), Query.limit(10)]);
    if (!res.rows || !res.rows.length) { el.innerHTML = '<div class="row">No rows yet.</div>'; return; }
    for (const r of res.rows) el.appendChild(row(r.userId || "anon", r.prompt + "\n→ " + (r.response || "…"), new Date(r.$createdAt).toLocaleString()));
  } catch (err) { el.appendChild(row("error", err.message || String(err))); }
}
$("refresh-rows").addEventListener("click", loadRows);

$("upload-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const f = $("file").files[0]; if (!f) return;
  try { await storage.createFile(cfg.bucketId, ID.unique(), f); loadFiles(); } catch (err) { $("messaging").innerHTML = '<div class="row">Upload failed: ' + (err.message || err) + '</div>'; }
});
async function loadFiles() {
  const el = $("files"); el.innerHTML = "";
  try {
    const res = await storage.listFiles(cfg.bucketId, [Query.limit(10)]);
    if (!res.files || !res.files.length) { el.innerHTML = '<div class="row">No files yet.</div>'; return; }
    for (const f of res.files) el.appendChild(row(f.name, f.$id, (f.sizeActual || 0) + " bytes"));
  } catch (err) { el.appendChild(row("error", err.message || String(err))); }
}
$("refresh-files").addEventListener("click", loadFiles);

// Messaging messages (drafts) are created server-side by the function and are
// not listable from the client SDK (no listMessages on browser Messaging).
$("list-msgs-btn").addEventListener("click", () => {
  $("messaging").innerHTML = '<div class="row">The function drafts an email to the <b>' + cfg.topicId + '</b> topic per reply. With no SMTP provider, those drafts live in the console under <b>Messaging → Messages</b> (status: draft).</div>';
});

$("app").hidden = false;
if (!cfg.projectId || cfg.projectId.startsWith("<set")) $("account-status").textContent = "Edit site/config.js with your endpoint + projectId."; else refreshAuth();
