/**
 * DeepInfra Clef — decision (classifier) model extension for pi.
 *
 * Registers DeepInfra's Jev/SystemOne-compatible decision endpoint
 * (https://deepinfra.com/Cloudflare/clef, .../clef-flash, .../drex-max,
 * .../drex-v2.0) as a classifier provider so
 * codemode scripts can call it via `models.classify(...)`.
 *
 *   POST https://api.deepinfra.com/v1/decisions
 *   { model, state, questions }
 *
 * Question mappings (pi -> DeepInfra):
 *   bool   -> "noul"   (noul = probability of true)
 *   choice -> "choice"
 *   score  -> "score"
 *
 * Requires the codemode tool to be enabled and DEEPINFRA_API_KEY set.
 *
 * example usage from a codemode script:
 *   const clef = await models.getModelOfType("classifier", "deepinfra-clef", "Cloudflare/clef");
 *   const r = await models.classify(clef, {
 *     state: { message: "The change works, thanks." },
 *     questions: {
 *       approved: { type: "bool", instructions: "Is the review approved?" },
 *       owner: { type: "choice", instructions: "Who owns this?", criteria: { alice: "Frontend", bob: "Backend" } },
 *     },
 *   });
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type {
  ClassifierContext,
  ClassifierOptions,
  ClassifierResult,
  ClassifierModel,
} from "@earendil-works/pi-ai";

const DECISIONS_URL = "https://api.deepinfra.com/v1/decisions";
const API_NAME = "deepinfra-decisions";

/**
 * Model catalog. DeepInfra prices decision models as $X / 1M tokens (input + output
 * at the same rate — drex models do report small output token counts).
 */
const MODELS = [
  {
    id: "Cloudflare/clef",
    name: "Cloudflare Clef (DeepInfra)",
    contextWindow: 65537,
    costPerMillion: 0.24,
  },
  {
    id: "Cloudflare/clef-flash",
    name: "Cloudflare Clef Flash (DeepInfra)",
    contextWindow: 65537,
    costPerMillion: 0.038,
  },
  {
    id: "nace-ai/drex-max",
    name: "Nace Drex Max (DeepInfra)",
    contextWindow: 262144,
    costPerMillion: 0.12,
  },
  {
    id: "nace-ai/drex-v2.0",
    name: "Nace Drex v2.0 (DeepInfra)",
    contextWindow: 131072,
    costPerMillion: 0.06,
  },
] as const;

interface DeepInfraAnswers {
  [key: string]: {
    type: "noul" | "choice" | "score";
    noul?: number;
    choice?: string;
    probabilities?: Record<string, number>;
    confidence?: number;
    score?: number;
    legend?: Record<string, number>;
  };
}

interface DeepInfraResponse {
  model: string;
  answers: DeepInfraAnswers;
  usage?: { input_tokens?: number; output_tokens?: number };
  detail?: unknown;
}

/** Map a pi classifier question into DeepInfra's request shape. */
function toDeepInfraQuestion(q: ClassifierContext["questions"][string]): Record<string, unknown> {
  switch (q.type) {
    case "bool":
      return { type: "noul", instructions: q.instructions, criteria: q.criteria };
    case "choice":
      return { type: "choice", instructions: q.instructions, criteria: q.criteria };
    case "score":
      return { type: "score", instructions: q.instructions, criteria: q.criteria };
  }
}

/** Map DeepInfra's answers back into pi's result shape. */
function toPiAnswers(answers: DeepInfraAnswers): ClassifierResult["answers"] {
  const out: ClassifierResult["answers"] = {};
  for (const [key, a] of Object.entries(answers)) {
    if (a.type === "noul") {
      out[key] = { type: "bool", probability: a.noul ?? 0 };
    } else if (a.type === "choice") {
      out[key] = {
        type: "choice",
        choice: a.choice ?? "",
        probabilities: a.probabilities ?? {},
        confidence: a.confidence ?? 0,
      };
    } else {
      out[key] = { type: "score", score: a.score ?? 0, confidence: a.confidence ?? 1 };
    }
  }
  return out;
}

async function classify(
  model: ClassifierModel<"deepinfra-decisions">,
  context: ClassifierContext,
  options?: ClassifierOptions,
): Promise<ClassifierResult> {
  if (context.images && context.images.length > 0) {
    return {
      api: API_NAME,
      provider: "deepinfra-clef",
      model: model.id,
      answers: {},
      stopReason: "error",
      errorMessage: "Image input is not supported by the deepinfra-clef extension.",
      timestamp: Date.now(),
    };
  }

  const apiKey = process.env.DEEPINFRA_API_KEY;
  if (!apiKey) {
    return {
      api: API_NAME,
      provider: "deepinfra-clef",
      model: model.id,
      answers: {},
      stopReason: "error",
      errorMessage: "DEEPINFRA_API_KEY environment variable is not set.",
      timestamp: Date.now(),
    };
  }

  const questions: Record<string, unknown> = {};
  for (const [key, q] of Object.entries(context.questions)) {
    questions[key] = toDeepInfraQuestion(q);
  }

  const body = JSON.stringify({
    model: model.id,
    state: context.state,
    questions,
  });

  const costPerMillion = MODELS.find((m) => m.id === model.id)?.costPerMillion ?? 0;

  const res = await fetch(DECISIONS_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body,
    signal: options?.signal,
  });

  const data = (await res.json().catch(() => ({}))) as DeepInfraResponse;
  if (!res.ok) {
    return {
      api: API_NAME,
      provider: "deepinfra-clef",
      model: model.id,
      answers: {},
      stopReason: "error",
      errorMessage: `DeepInfra decisions API error ${res.status}: ${JSON.stringify(data.detail ?? data)}`,
      timestamp: Date.now(),
    };
  }

  const inputTokens = data.usage?.input_tokens ?? 0;
  const outputTokens = data.usage?.output_tokens ?? 0;
  const cost = ((inputTokens + outputTokens) / 1_000_000) * costPerMillion;
  const usage = {
    input: inputTokens,
    output: outputTokens,
    cacheRead: 0,
    cacheWrite: 0,
    totalTokens: inputTokens + outputTokens,
    cost: {
      input: (inputTokens / 1_000_000) * costPerMillion,
      output: (outputTokens / 1_000_000) * costPerMillion,
      cacheRead: 0,
      cacheWrite: 0,
      total: cost,
      totalFromProvider: true,
    },
  };

  return {
    api: API_NAME,
    provider: "deepinfra-clef",
    model: data.model ?? model.id,
    answers: toPiAnswers(data.answers ?? {}),
    usage,
    stopReason: "stop",
    timestamp: Date.now(),
  };
}

export default function deepinfraClefExtension(pi: ExtensionAPI) {
  pi.registerProvider("deepinfra-clef", {
    name: "DeepInfra Clef (Decisions)",
    baseUrl: "https://api.deepinfra.com/v1",
    apiKey: "$DEEPINFRA_API_KEY",
    classifiers: {
      [API_NAME]: { classify },
    },
    models: MODELS.map((m) => ({
      type: "classifier" as const,
      id: m.id,
      name: m.name,
      api: API_NAME,
      input: ["text" as const],
      contextWindow: m.contextWindow,
      cost: {
        input: m.costPerMillion,
        output: m.costPerMillion,
        cacheRead: 0,
        cacheWrite: 0,
      },
    })),
  });
}
