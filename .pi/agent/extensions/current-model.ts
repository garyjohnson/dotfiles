/**
 * Current Model Extension
 *
 * Exposes a `current_model` tool that allows the LLM to view the
 * currently active LLM model's name, provider, context window,
 * and session token usage and costs.
 *
 * Place in ~/.pi/agent/extensions/ for user-scoped discovery.
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function currentModelExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "current_model",
    label: "Current Model",
    description:
      "Returns the name, provider, context window, and session token usage/costs " +
      "of the currently active LLM model. Use this tool when you need to identify " +
      "which model you are running as, check your context window, or review session costs.",
    promptSnippet: "View the current model name, provider, and session usage",
    promptGuidelines: [
      "Use current_model when you need to know which model you are running as, your context window size, your provider, or how many tokens/costs the session has accumulated.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      const model = ctx.model;

      if (!model) {
        return {
          content: [
            {
              type: "text",
              text: "No model is currently selected.",
            },
          ],
          details: {},
        };
      }

      // Aggregate session usage from assistant messages on the current branch
      let inputTokens = 0;
      let outputTokens = 0;
      let cacheReadTokens = 0;
      let cacheWriteTokens = 0;
      let totalCost = 0;
      let turnCount = 0;

      for (const e of ctx.sessionManager.getBranch()) {
        if (e.type === "message" && e.message.role === "assistant") {
          const m = e.message as AssistantMessage;
          inputTokens += m.usage.input;
          outputTokens += m.usage.output;
          cacheReadTokens += m.usage.cacheRead;
          cacheWriteTokens += m.usage.cacheWrite;
          totalCost += m.usage.cost.total;
          turnCount++;
        }
      }

      const contextUsage = ctx.getContextUsage();
      const fmt = (n: number) => (n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`);

      const info = {
        id: model.id,
        name: model.name,
        provider: model.provider,
        contextWindow: model.contextWindow,
        maxTokens: model.maxTokens,
        session: {
          turns: turnCount,
          inputTokens,
          outputTokens,
          cacheReadTokens,
          cacheWriteTokens,
          totalCost,
          contextUsage: contextUsage
            ? { tokens: contextUsage.tokens, percent: contextUsage.percent }
            : null,
        },
      };

      const lines = [
        `Current model: ${model.provider}/${model.id}`,
        `Name: ${model.name}`,
        `Context window: ${model.contextWindow?.toLocaleString() ?? "unknown"} tokens`,
        `Max output tokens: ${model.maxTokens?.toLocaleString() ?? "unknown"}`,
        ``,
        `Session usage (${turnCount} turns):`,
        `  Input tokens: ${fmt(inputTokens)}`,
        `  Output tokens: ${fmt(outputTokens)}`,
        `  Cache read: ${fmt(cacheReadTokens)}`,
        `  Cache write: ${fmt(cacheWriteTokens)}`,
        `  Total cost: $${totalCost.toFixed(4)}`,
      ];

      if (contextUsage) {
        lines.push(
          `  Context: ${fmt(contextUsage.tokens)} tokens (${contextUsage.percent !== null ? Math.round(contextUsage.percent) + "%" : "?"} of window)`,
        );
      }

      return {
        content: [{ type: "text", text: lines.join("\n") }],
        details: info,
      };
    },
  });
}