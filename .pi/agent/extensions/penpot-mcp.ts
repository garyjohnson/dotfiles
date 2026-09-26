/**
 * penpot-mcp — bridge pi to the Penpot MCP server (streamable HTTP transport).
 *
 * pi has no built-in MCP client, so this extension implements the minimal
 * MCP client side (initialize + tools/call over SSE) and registers Penpot's
 * tools as native pi tools.
 *
 * Configure the server URL via the PENPOT_MCP_URL environment variable
 * (set it in ~/.profile-env, which is sourced by .zshrc), for example:
 *
 *   export PENPOT_MCP_URL="https://penpot.app.usefulbits.io/mcp/stream?userToken=YOUR_MCP_KEY"
 *
 * The URL comes from Penpot → Your account → Integrations → MCP Server.
 * Before using the tools, open a design file in Penpot and connect the plugin
 * via File → MCP Server → Connect (MCP operates on the currently focused page).
 *
 * Usage notes:
 *   - Tools are lazily connected on first call (no background resources at load).
 *   - export_shape images are passed back as image content so pi can "see" the design.
 *   - While Penpot tools are active, extra guidance is appended to the system
 *     prompt (see PENPOT_GUIDANCE). It has four parts: layout (use flex, don't
 *     nudge x/y), execution (keep each execute_code short-lived; never
 *     sleep/await inside one), API semantics (verified sharp edges — e.g.
 *     numeric properties are strings, removing a variant container silently
 *     deletes its child shapes, and in-place fills mutations silently no-op),
 *     and an API quick reference of confirmed signatures. Sourced from the
 *     public penpot-mcp guide plus corrections verified against a live plugin.
 *     Delete PENPOT_GUIDANCE if you don't want any of it.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_URL = process.env.PENPOT_MCP_URL ?? "";

/**
 * Per-request timeout for Penpot MCP calls, in milliseconds.
 *
 * The Penpot plugin executes code synchronously against a live document, so a
 * call that does a lot of work legitimately takes a while — building a screen's
 * worth of shapes is seconds, not milliseconds. Too short a timeout turns slow
 * work into a false failure.
 *
 * 5 minutes: generous, because a legitimate build can genuinely take a while
 * and the client has no other way to distinguish "busy" from "dead". The real
 * mitigation is not a short timeout but keeping each execute_code focused and
 * short-lived — see the execution constraints in PENPOT_GUIDANCE.
 *
 * Override with PENPOT_MCP_TIMEOUT_MS.
 */
const REQUEST_TIMEOUT_MS = Number(process.env.PENPOT_MCP_TIMEOUT_MS ?? 300_000);

/**
 * Guidance appended to the system prompt while Penpot tools are active.
 *
 * Four parts, each aimed at a failure actually observed rather than at
 * completeness:
 *
 *   1. Layout — a fixed-size board with its label at a hardcoded x looks fine
 *      for one label width and is wrong for every other width, so a row of chips
 *      misaligns differently in each chip. Use a flex layout so centering is a
 *      property of the container, not an arithmetic guess.
 *   2. Execution — calls run synchronously against a live document, so a big
 *      call can hang the plugin context and take subsequent calls down with it.
 *   3. API semantics — the sharp edges that do NOT throw. A wrong assumption
 *      here returns a plausible value or nothing at all, which is worse than an
 *      exception because there is nothing to notice.
 *   4. Quick reference — confirmed signatures, so a call is written from a
 *      verified shape instead of a guess.
 *
 * Parts 1-3 came from real failures in this project; part 4 and several of the
 * semantics notes were checked against a live plugin while reviewing the public
 * penpot-mcp guide (github.com/mrf0xvn/penpot-mcp-guide), which is otherwise
 * accurate but states two things incorrectly: `text.getRange()` takes no-arg
 * form (it requires start/end), and a component name may contain '/' (it does
 * not — '/' is a path separator).
 *
 * The guide's third debated claim — that fills/strokes/shadows are immutable
 * arrays whose in-place mutation fails — was TESTED and is wrong: the mutation
 * succeeds and persists. Note this was mis-documented here once before, in the
 * opposite direction, on the strength of an unfinished test. Do not restate
 * either claim without re-running the check.
 */
const PENPOT_GUIDANCE = `
Penpot layout guidance:
- Reach for a flex layout instead of positioning children by hand. If a
  container arranges children in a row or column, it should have a flex
  layout. Use penpotUtils.addFlexLayout(container, dir) when the container
  already has children, so their visual order is preserved.
- Center with justifyContent/alignItems ("center"), not by nudging x/y. A
  hardcoded x only centers the one label width you had in mind; every other
  label ends up off-center by a different amount.
- Papering over layout with padding is the same bug. Symmetric padding plus
  justifyContent "center" is fine; padding used to fake a center is not.
- Set horizontalSizing/verticalSizing deliberately: "fix" to keep a size,
  "auto" to fit content, "fill" to fill the parent.

Penpot execution constraints (these have caused real, repeated failures):
- **Keep each execute_code focused and short-lived.** This is the primary rule;
  everything below follows from it. Do one thing per call — create one screen,
  rebuild one component, or read one part of the tree. Do not build several
  screens, restyle a whole page, or mix a destructive rebuild with inspection in
  a single call. Interrupted work is the failure mode: a call that dies partway
  leaves a half-built tree that is worse than either the before or after state.
- **Large execute_code calls can time out or hang.** The work runs
  synchronously against a live document, so a call that touches a lot of the
  tree may not finish in time — and an abandoned request can leave the plugin
  unresponsive to the calls that follow it. Keep each call small rather than
  relying on a deadline to save you.
- **One object, one operation per call.** Prefer several flat reads over one
  nested read: deeply nested \`findShape\` lookups and IIFEs inside large
  \`.map()\` chains time out as readily as a large build does. The tree walk
  costs more than the shapes created.
- **NEVER sleep or await inside execute_code.** \`await new Promise(r =>
  setTimeout(r, n))\` does not yield — it HANGS the plugin context, and every
  subsequent call then times out too, until the user restarts the plugin.
  There is no way to wait for layout from inside a call. Do not try.
- **Layout is applied asynchronously, so positions read in the same call are
  stale.** A child just added to a flex container reports \`parentY: 0\` until
  Penpot's next layout pass. Building shapes and then inspecting/exporting
  their geometry in the SAME call will show everything stacked at the origin
  and look broken when it is not.
- Therefore: **build in one call, then read or export in a SEPARATE later
  call.** Never build-then-verify in one call. Treat a confusing all-zero or
  empty render as "layout has not settled yet", not as a structural bug —
  re-read the geometry in a fresh call before changing any code.
- \`penpot_export_shape\` can likewise capture a pre-layout frame. If an export
  looks empty or collapsed, re-export in a new call before concluding the
  design is wrong. Do not respond to a stale render by rebuilding the page —
  that is how a correct design gets churned for no reason.
- **Do not look at exports yourself — delegate visual checks to the
  \`penpot-visual-check\` subagent.** Every image you pull into this
  conversation counts against the model API's 30-images-per-request cap, and the
  count is cumulative for the rest of the session. Exceed it and the turn fails
  outright with \`Too many images in request: N > 30\` — an error from the model
  provider, not from Penpot, so nothing about the design is wrong, and the
  accumulated images cannot be dropped mid-conversation: the only recovery is a
  fresh session. The subagent does the export, looks at the image, and returns a
  text verdict, so the pixels never enter this conversation and the cap never
  becomes reachable. Call it with a task naming the shape to inspect and the
  question to answer, e.g. "Export the primary button on the settings screen and
  report whether the label is centered and the hierarchy reads clearly."
- **Prefer a numeric geometry read over any pixel check.** Positions, sizes and
  \`parentX\`/\`parentY\` answer "is this centered / aligned / overlapping?"
  exactly, cost no image, and do not depend on layout having settled. Reach for a
  visual check only when the question is genuinely about appearance — does it
  read clearly, is the contrast right, does the hierarchy land — and even then
  send it to the subagent rather than exporting here. Export the one shape you
  need, at \`selection\` or a specific shapeId, never the whole page or a batch
  of screens "to check everything".
- Different runs can disagree: the identical build code may render correctly
  once and appear un-laid-out the next time. The geometry in a follow-up read
  is the source of truth, not a screenshot from the build call.
- Prefer \`penpotUtils.addFlexLayout(container, dir)\` over
  \`container.addFlexLayout()\` on boards created via \`penpot.createBoard()\`
  — the util is the path known to lay out reliably.

Penpot API semantics (verified against the live plugin; each of these caused a
real, silent failure — a wrong assumption here does NOT throw, it just quietly
does the wrong thing or nothing at all):
- **Shape numeric-ish properties are STRINGS, not numbers.** \`shape.fontSize\`,
  \`fontWeight\` and friends return strings (\`"17"\`, not \`17\`). A strict
  numeric compare silently matches NOTHING: on a real file,
  \`findShapes(s => s.fontSize === 17)\` returned 0 shapes while
  \`s.fontSize === '17'\` returned 18. The danger is that the "fix" loop then
  reports success having changed nothing. Always coerce — \`String(s.fontSize)\`
  or \`Number(...)\` — on BOTH sides of a comparison, and after a batch edit
  re-read the distribution to confirm the change actually landed rather than
  trusting the loop's own count.
- **\`variantContainer.remove()\` deletes every child shape and its component.**
  Verified: removing a variant container left \`kidsSurvived: [false, false]\`.
  The children of a variant container are its main component instances, not a
  view of them — \`remove()\` is a cascade, not a group teardown. This silently
  deleted two nav items out of a live screen. To dissolve a variant group, detach
  the instances first (\`instance.detach()\`) or ungroup; never \`remove()\` the
  container while the instances still matter. Take a note of every child id
  before any structural delete and re-check those ids in a following call.
- **\`createComponent\` and \`createVariantContainer\` OVERWRITE shape names.**
  Variantisation reset main-instance names to \`"Component"\` and the inner
  container to \`"Nav"\`, losing \`"Nav / Listings"\` vs \`"Nav / Inventory"\`.
  Re-assign meaningful names immediately after creating components/variants, and
  re-verify them in a later call — the rename happens asynchronously to your
  assignment.
- **Never use \`/\` in a component name — it is a path separator, not a
  character.** \`createComponent\` treats it as one: naming a component
  \`"Nav Item / Default"\` yielded a component actually named \`"Default"\`, and
  the common idiom \`component.name = "Button/Primary"\` produces \`"Primary"\`.
  Use a space or hyphen (\`"Nav Item Default"\`).
- **\`createVariantContainer\` may add a spurious second property axis**
  (\`"Property 2"\`) alongside the one you asked for. I could not reproduce this
  deterministically on clean scratch boards (both a plain and a pre-named pair
  produced a single clean \`State\` axis), so treat the trigger as unknown rather
  than assuming a cause. It matters because **the variant API has no way to
  remove a property** — only \`addProperty\`/\`renameProperty\` exist — so a junk
  axis cannot be deleted, only renamed. Inspect \`container.variants.properties\`
  immediately after creating a variant group and, if it is not exactly what you
  intended, rebuild the group rather than trying to repair it in place.
- **\`setVariantProperty(pos, value)\` counts positions over the CURRENT property
  list**, so \`pos\` shifts if a property was added. It threw
  \`Value not valid: 1. Code: :pos\` for me in a state where the property list had
  just changed. Re-read \`variants.properties\` and index off that rather than
  hardcoding a position from an earlier read.
- **\`tokenCatalog.addTheme\` takes ONE object, not two arguments.**
  \`addTheme(group, name)\` fails with an opaque \`Value not valid. Code: :error\`;
  the working call is \`addTheme({ group, name })\`. The same opaque \`:error\`
  also means a partially-applied call was rolled back cleanly — after any such
  error, re-read the collection to confirm nothing was left half-created before
  retrying.
- **\`shape.tokens\` is the reliable way to audit what is bound.** It maps a
  property name (\`fill\`, \`strokeColor\`, \`borderRadiusTopLeft\`, \`rowGap\`, …)
  to a token name, so a file-wide count of \`Object.keys(s.tokens).length > 0\`
  tells you instantly whether tokens were ever applied. On the file this was
  learned from, that count was **0 of 459 shapes** — a populated token catalog
  with nothing wired to it is a common and invisible failure.
- **Binding a token to a value that already matches it is lossless.** Mapping
  each hardcoded hex to the token with the identical resolved value changed
  zero pixels while making the design themeable. Prefer this over "normalizing"
  colours: when a hardcoded value does NOT match any token, stop and report it
  rather than silently remapping to the nearest one.
- **Do not assume the \`penpot-visual-check\` subagent can reach Penpot.** The
  Penpot MCP tools do not reliably load in a subagent context — a delegated
  visual check came back \`penpot-mcp tools unavailable (extension did not load)\`.
  If the subagent reports the tools missing, either do a single targeted export
  yourself (numeric reads first, at most one image) or ask the user; do not
  retry the subagent repeatedly.
- **In-place mutation of \`fills\`/\`strokes\`/\`shadows\` WORKS — the
  widely-repeated "these arrays are immutable, so \`shape.fills[0].fillColor =
  '#00FF00'\` fails" claim is wrong on both counts.** Verified on a live plugin:
  that exact assignment does not throw, and the change PERSISTS across separate
  calls (checked for \`fillColor\`, \`fillOpacity\` and \`strokeColor\`, all
  survived). An earlier draft of this guidance said the opposite and was itself
  incorrect — do not repeat the "silently no-ops" framing.
  Reassigning the whole array (\`shape.fills = [{ fillColor, fillOpacity }]\`) is
  still the tidier habit and what the Penpot docs model, so prefer it for
  AUTHORING. But do not rewrite a working index-based edit loop on the belief
  that mutations are discarded: they are not, and the parallel claim that you
  get "a quiet success for a write that never landed" is unfounded.
- **\`text.getRange()\` with no arguments throws** (\`Value not valid. Code:
  :getRange-start\`). The working form is \`text.getRange(0, text.characters.length)\`.
  Note you can usually skip ranges entirely for reads: \`fontSize\`,
  \`fontWeight\`, \`fontFamily\` and \`lineHeight\` are readable directly on the
  text shape.

Penpot API quick reference (verified surface area; every call here was checked
against a live plugin — use these rather than guessing a signature):
- **Shapes**: \`penpot.createBoard()\`, \`createRectangle()\`, \`createText(str)\`,
  \`createEllipse()\`, \`createShapeFromSvg(svg)\`. Position with absolute \`x\`/\`y\`
  (or \`penpotUtils.setParentXY\`), size with \`resize(w, h)\` — \`width\`/\`height\`
  are read-only.
- **Flex**: \`board.addFlexLayout()\` → \`dir\` (row/column/row-reverse/
  column-reverse), \`alignItems\`, \`justifyContent\`, \`rowGap\`/\`columnGap\`,
  \`top/right/bottom/leftPadding\`, \`horizontalSizing\`/\`verticalSizing\`
  (fix/auto/fill), \`wrap\`. Per-child: \`child.layoutChild\` with
  \`horizontalSizing\`/\`verticalSizing\`/\`alignSelf\`/margins/\`absolute\`.
- **Grid**: \`board.addGridLayout()\` → \`addColumn(type, value)\`,
  \`addRow(type, value)\` where type is \`"flex" | "fixed" | "percent"\`; plus
  gaps, padding, \`alignItems\`/\`justifyItems\`. Place a child with
  \`grid.appendChild(shape, row, column)\` (1-based).
- **Style**: \`shape.fills = [{ fillColor, fillOpacity }]\` (\`[]\` for none);
  \`shape.strokes = [{ strokeColor, strokeOpacity, strokeWidth, strokeStyle,
  strokeAlignment }]\`; \`shape.shadows = [{ style: "drop-shadow"|"inner-shadow",
  offsetX, offsetY, blur, spread, color: { color, opacity } }]\`. Gradients via
  \`fillColorGradient\` with \`type: "linear"|"radial"\` and \`stops\`.
- **Text**: the common readable/writable properties exist directly on the text
  shape (\`characters\`, \`fontSize\`, \`fontWeight\`, \`fontFamily\`, \`lineHeight\`,
  \`letterSpacing\`, \`align\`, \`textTransform\`, \`textDecoration\`,
  \`growType\`). Use \`getRange(start, end)\` only when styling PART of a string.
  Colour strings must be hex with caps.
- **Tokens**: \`penpot.library.local.tokens\` → \`addSet({ name })\`,
  \`addTheme({ group, name })\` (ONE object), \`set.addToken({ type, name, value })\`,
  \`set.toggleActive()\`. Apply with \`shape.applyToken(token, [props])\`; audit with
  \`shape.tokens\`; look up with \`penpotUtils.findTokenByName(name)\` and
  \`tokenOverview()\`. Token types include color, dimension, spacing, typography,
  shadow, opacity, borderRadius, borderWidth, fontSizes, fontWeights,
  fontFamilies, letterSpacing, textCase, textDecoration.
- **Components**: \`createComponent(shapes)\` → \`.instance()\`, \`.mainInstance()\`,
  \`.detach()\`. Variants exist and are the sharp edge — see the warnings above
  before touching \`createVariantContainer\` or \`createVariantFromComponents\`.
- **Code generation**: \`penpot.generateStyle(shapes, { type: "css",
  withChildren: true })\` and \`penpot.generateMarkup(shapes, { type: "html" })\`
  both return strings; \`generateFontFaces(shapes)\` is async. This is the
  Design→Code path.
- **Images**: \`await penpot.uploadMediaUrl(name, url)\` or
  \`await penpot.uploadMediaData(name, bytes, mime)\`, then
  \`shape.fills = [{ fillOpacity: 1, fillImage: img }]\`.
- **Traversal**: \`penpotUtils.getPages()\`, \`getPageByName(name)\`,
  \`shapeStructure(shape, maxDepth)\`, \`findShape(predicate)\`,
  \`findShapes(predicate, root)\`, \`findShapeById(id)\`,
  \`isContainedIn(shape, container)\`, \`analyzeDescendants(root, fn)\`.
- \`storage\` persists across \`execute_code\` calls in a session — use it to carry
  shape ids and intermediate results between calls (essential given the
  build-then-verify-in-a-separate-call rule above).
- \`execute_code\` receives nothing unless you \`return\`. \`console.log\` is not
  delivered back to you.
`;

/** True when the Penpot tool set is active in this session. */
function penpotToolsActive(tools: string[] | undefined): boolean {
  return !!tools?.includes("penpot_execute_code");
}

/** Minimal MCP JSON-RPC client over streamable HTTP (SSE). */
class PenpotMcpClient {
  private sessionId: string | null = null;
  private url: string;

  constructor(url: string) {
    this.url = url;
  }

  /** Parse an SSE body (may contain multiple `data:` lines). */
  private parseSse(body: string): any[] {
    const out: any[] = [];
    for (const line of body.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      const payload = trimmed.slice(5).trim();
      if (!payload || payload === "[DONE]") continue;
      try {
        out.push(JSON.parse(payload));
      } catch {
        // ignore non-JSON data lines
      }
    }
    return out;
  }

  /** Send one JSON-RPC request and return the decoded `result`/construct an error. */
  private async rpc<T = any>(method: string, params: Record<string, unknown> = {}): Promise<T> {
    const headers: Record<string, string> = {
      "content-type": "application/json",
      accept: "application/json, text/event-stream",
    };
    if (this.sessionId) headers["mcp-session-id"] = this.sessionId;

    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), REQUEST_TIMEOUT_MS);

    let res: Response;
    try {
      res = await fetch(this.url, {
        method: "POST",
        headers,
        body: JSON.stringify({
          jsonrpc: "2.0",
          id: crypto.randomUUID(),
          method,
          params,
        }),
        signal: ac.signal,
      });
    } catch (err: any) {
      const aborted = err?.name === "AbortError";
      const msg = aborted
        ? `Penpot MCP: no response within ${REQUEST_TIMEOUT_MS}ms for ${method}. ` +
          `The Penpot plugin may be disconnected, or a large call may have hung it — ` +
          `check the plugin is connected in Penpot, and restart it if calls keep timing out.`
        : `Penpot MCP: request failed for ${method}: ${err?.message ?? String(err)}`;
      clearTimeout(timer);
      throw new Error(msg);
    }

    const sid = res.headers.get("mcp-session-id");
    if (sid) this.sessionId = sid;

    // The stream can also stall after headers arrive, so keep the timer alive
    // across the body read rather than clearing it with the fetch.
    let body: string;
    try {
      body = await res.text();
    } catch (err: any) {
      throw new Error(
        `Penpot MCP: response body stalled or failed for ${method}: ${err?.message ?? String(err)}`,
      );
    } finally {
      clearTimeout(timer);
    }
    const messages = this.parseSse(body);
    const msg = messages.find((m) => m.id !== undefined) ?? messages[0];

    if (!msg) {
      throw new Error(`Penpot MCP: empty response (HTTP ${res.status}) for ${method}`);
    }
    if (msg.error) {
      throw new Error(`Penpot MCP error from ${method}: ${msg.error.message ?? JSON.stringify(msg.error)}`);
    }
    return msg.result as T;
  }

  async connect() {
    const result = await this.rpc<any>("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "pi", version: "0.1.0" },
    });
    if (result?.protocolVersion) {
      // Send the required initialized notification (fire-and-forget).
      this.rpc("notifications/initialized", {}).catch(() => {});
    }
    return result;
  }

  async callTool(name: string, args: Record<string, unknown>) {
    await this.ensureConnected();
    return this.rpc<any>("tools/call", { name, arguments: args });
  }

  private connected = false;
  private async ensureConnected() {
    if (this.connected) return;
    await this.connect();
    this.connected = true;
  }
}

type ContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; data: string; mimeType: string }
  | { type: "resource"; resource: Record<string, unknown> };

/** Convert MCP `content` blocks into pi tool-result content blocks. */
function contentToPi(content: ContentBlock[]): any[] {
  const out: any[] = [];
  for (const block of content ?? []) {
    if (block.type === "text") {
      out.push({ type: "text", text: block.text });
    } else if (block.type === "image") {
      out.push({ type: "image", data: block.data, mimeType: block.mimeType });
    } else if (block.type === "resource") {
      // Flatten resource blocks (e.g. embedded text) for readability.
      const r = block.resource as any;
      if (r?.text) out.push({ type: "text", text: r.text });
      else out.push({ type: "text", text: JSON.stringify(r) });
    }
  }
  return out;
}

export default function penpotMcp(pi: ExtensionAPI) {
  const url = DEFAULT_URL;
  if (!url) {
    // Register nothing, but say so loudly. A silent return here is how a
    // subagent ends up failing with an opaque "Tool penpot_export_shape not
    // found": the extension loaded fine, it just had no URL to talk to, and
    // nothing distinguished that from the tools never existing. The env var is
    // read at module load, so a child process that did not inherit it lands
    // here even though the parent session works.
    console.error(
      "[penpot-mcp] PENPOT_MCP_URL is not set — no Penpot tools registered. " +
        "Set it in ~/.profile-env (export PENPOT_MCP_URL=\"https://…/mcp/stream?userToken=…\") " +
        "and make sure it is exported to any child/subagent process.",
    );
    return;
  }

  const client = new PenpotMcpClient(url);

  // Only add layout guidance when the Penpot tools are actually available, so
  // unrelated sessions don't carry design instructions around.
  pi.on("before_agent_start", async (event) => {
    if (!penpotToolsActive(event.systemPromptOptions?.selectedTools)) return;
    return { systemPrompt: event.systemPrompt + "\n" + PENPOT_GUIDANCE };
  });

  async function callTool(name: string, args: Record<string, unknown>) {
    let result: any;
    try {
      result = await client.callTool(name, args);
    } catch (err: any) {
      return {
        content: [{ type: "text", text: `Penpot MCP error: ${err?.message ?? String(err)}` }],
        details: { isError: true },
      };
    }
    if (result?.isError) {
      return {
        content: [{ type: "text", text: `Penpot tool ${name} reported an error.` }],
        details: { isError: true },
      };
    }
    const content = contentToPi(result?.content);
    return {
      content: content.length ? content : [{ type: "text", text: JSON.stringify(result ?? null) }],
      details: {},
    };
  }

  // --- high_level_overview ---
  pi.registerTool({
    name: "penpot_high_level_overview",
    label: "Penpot overview",
    description:
      "Returns basic high-level instructions on the usage of Penpot tools and the Penpot API. " +
      "Call this FIRST before using other Penpot tools if you have not already read the overview.",
    parameters: Type.Object({}),
    async execute(_id, _params, _signal, _onUpdate, _ctx) {
      return callTool("high_level_overview", {});
    },
  });

  // --- penpot_api_info ---
  pi.registerTool({
    name: "penpot_api_info",
    label: "Penpot API info",
    description:
      "Retrieves Penpot API documentation for types and their members. Read the " +
      "high_level_overview first. Pass `type` (required) and optionally `member`.",
    parameters: Type.Object({
      type: Type.String({
        minLength: 1,
        description: "The Penpot API type whose documentation you want.",
      }),
      member: Type.Optional(Type.String({ description: "A specific member of the type." })),
    }),
    async execute(_id, params, _signal, _onUpdate, _ctx) {
      const args: Record<string, unknown> = { type: params.type };
      if (params.member) args.member = params.member;
      return callTool("penpot_api_info", args);
    },
  });

  // --- execute_code ---
  pi.registerTool({
    name: "penpot_execute_code",
    label: "Penpot execute code",
    description:
      "Executes JavaScript code in the Penpot plugin context. You have access to `penpot` " +
      "(the Penpot API), `penpotUtils`, and `storage` (a persistent object for storing " +
      "intermediate results across calls). The code runs as the body of a function; return " +
      "whatever you want back (arbitrary JS objects are fine). Read high_level_overview first.",
    parameters: Type.Object({
      code: Type.String({
        minLength: 1,
        description: "The JavaScript code to execute in the Penpot plugin context.",
      }),
    }),
    async execute(_id, params, _signal, _onUpdate, _ctx) {
      return callTool("execute_code", { code: params.code });
    },
  });

  // --- export_shape ---
  pi.registerTool({
    name: "penpot_export_shape",
    label: "Penpot export shape",
    description:
      "Exports a shape (or a shape's image fill) from the Penpot design to a PNG or SVG image " +
      "so you can see what it looks like. `shapeId` special identifiers: 'selection' (first " +
      "shape currently selected) or 'page' (entire current page). Prefer delegating to the " +
      "`penpot-visual-check` subagent for visual checks: each export adds an image to the " +
      "conversation, the model API allows at most 30 images per request, and the count is " +
      "cumulative — exceed it and the turn fails with 'Too many images in request' (a provider " +
      "limit, not a Penpot error) with no recovery short of a fresh session. Use this tool " +
      "directly only when the parent genuinely must see the image; otherwise a numeric geometry " +
      "read or the subagent's text verdict answers the question without spending an image.",
    parameters: Type.Object({
      shapeId: Type.String({
        minLength: 1,
        description: "Shape ID, 'selection', or 'page'.",
      }),
      format: Type.Optional(
        Type.Union([Type.Literal("png"), Type.Literal("svg")], {
          default: "png",
          description: "Output format (default 'png').",
        }),
      ),
      mode: Type.Optional(
        Type.Union([Type.Literal("shape"), Type.Literal("fill")], {
          default: "shape",
          description: "Export mode (default 'shape').",
        }),
      ),
    }),
    async execute(_id, params, _signal, _onUpdate, _ctx) {
      const args: Record<string, unknown> = { shapeId: params.shapeId };
      if (params.format) args.format = params.format;
      if (params.mode) args.mode = params.mode;
      return callTool("export_shape", args);
    },
  });
}
