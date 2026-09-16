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
 *   - While Penpot tools are active, extra layout guidance is appended to the system
 *     prompt (see LAYOUT_GUIDANCE) so the agent uses flex layouts instead of nudging
 *     x/y by hand. Delete LAYOUT_GUIDANCE if you don't want that.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_URL = process.env.PENPOT_MCP_URL ?? "";

/**
 * Guidance appended to the system prompt while Penpot tools are active.
 *
 * The failure this prevents: a fixed-size board with its label positioned at a
 * hardcoded x. It looks fine for one label width and is wrong for every other
 * width — so a row of chips has a different misalignment in each chip. Use a
 * flex layout so centering is a property of the container, not an arithmetic
 * guess that has to be redone for every instance.
 */
const LAYOUT_GUIDANCE = `
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

    const res = await fetch(this.url, {
      method: "POST",
      headers,
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: crypto.randomUUID(),
        method,
        params,
      }),
    });

    const sid = res.headers.get("mcp-session-id");
    if (sid) this.sessionId = sid;

    const body = await res.text();
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
    // Register nothing; leave a hint via status if a UI exists.
    return;
  }

  const client = new PenpotMcpClient(url);

  // Only add layout guidance when the Penpot tools are actually available, so
  // unrelated sessions don't carry design instructions around.
  pi.on("before_agent_start", async (event) => {
    if (!penpotToolsActive(event.systemPromptOptions?.selectedTools)) return;
    return { systemPrompt: event.systemPrompt + "\n" + LAYOUT_GUIDANCE };
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
      "shape currently selected) or 'page' (entire current page).",
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
