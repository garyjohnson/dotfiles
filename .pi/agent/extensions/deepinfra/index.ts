/**
 * DeepInfra Extension
 *
 * Shows account balance and usage/cost breakdown from your DeepInfra account.
 * Relies on the DEEPINFRA_API_KEY environment variable.
 *
 * Provides:
 *   /deepinfra         — Show balance and usage summary
 *   deepinfra_usage    — LLM tool for querying balance and usage breakdown
 *
 * API endpoints used:
 *   GET /v1/me?checklist=true  — Account info + balance (dollars)
 *   GET /payment/config         — Spending limit (dollars)
 *   GET /payment/usage          — Monthly cost breakdown by model (costs in cents)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { matchesKey, type Component, Text } from "@earendil-works/pi-tui";

const DEEPINFRA_BASE = "https://api.deepinfra.com";

// ── API response types ──────────────────────────────────────────────────────

interface AccountChecklist {
  stripe_balance: number | null;
  recent: number | null;
  limit: number | null;
  suspend_reason: string | null;
  email: boolean;
  billing_address: boolean;
  payment_method: boolean;
  suspended: boolean;
  overdue_invoices: number;
  last_checked: number;
  topup: boolean;
  topup_amount: number;
  topup_threshold: number;
  topup_failed: boolean;
}

interface AccountInfo {
  uid: string;
  email: string;
  display_name: string;
  name: string;
  is_team_account: boolean;
  team_display_name: string | null;
  checklist: AccountChecklist | null;
}

interface BillingConfig {
  limit: number;
}

interface UsageItem {
  model: {
    provider: string;
    model_name: string;
    task: string;
    plan_id: string | null;
    private: boolean;
  };
  units: number;
  rate: number;
  cost: number;
  pricing_type: string;
  discount: { name: string; description: string } | null;
}

interface UsageMonth {
  period: string;
  total_cost: number;
  invoice_id: string;
  items: UsageItem[];
}

// ── API helpers ─────────────────────────────────────────────────────────────

async function deepInfraFetch<T>(path: string, apiKey: string, signal?: AbortSignal): Promise<T> {
  const url = `${DEEPINFRA_BASE}${path}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${apiKey}` },
    signal,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`DeepInfra API error ${res.status}: ${text || res.statusText}`);
  }
  return res.json() as Promise<T>;
}

function getApiKey(): string {
  const key = process.env.DEEPINFRA_API_KEY;
  if (!key) {
    throw new Error("DEEPINFRA_API_KEY environment variable is not set. Set it in ~/.profile-env or your shell.");
  }
  return key;
}

// ── Formatting helpers ──────────────────────────────────────────────────────

function fmtDollars(dollars: number | null): string {
  if (dollars == null) return "—";
  if (dollars < 0) return `-$${Math.abs(dollars).toFixed(2)}`;
  if (dollars < 100) return `$${dollars.toFixed(2)}`;
  return `$${dollars.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtCents(cents: number): string {
  return fmtDollars(cents / 100);
}

function fmtPeriod(period: string): string {
  const parts = period.split(".");
  if (parts.length === 2) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const monthIdx = parseInt(parts[1], 10) - 1;
    if (monthIdx >= 0 && monthIdx < 12) {
      return `${months[monthIdx]} ${parts[0]}`;
    }
  }
  return period;
}

// ── Aggregate items by model ────────────────────────────────────────────────

interface ModelSummary {
  model: string;
  totalCostCents: number;
}

function aggregateByModel(items: UsageItem[]): ModelSummary[] {
  const map = new Map<string, number>();
  for (const item of items) {
    const existing = map.get(item.model.model_name) ?? 0;
    map.set(item.model.model_name, existing + item.cost);
  }
  const summaries: ModelSummary[] = [...map.entries()].map(([model, totalCostCents]) => ({
    model,
    totalCostCents,
  }));
  summaries.sort((a, b) => b.totalCostCents - a.totalCostCents);
  return summaries;
}

// ── Build summary ───────────────────────────────────────────────────────────

interface DashboardData {
  account: AccountInfo;
  config: BillingConfig;
  usage: UsageMonth[];
}

function buildSummary(data: DashboardData): string {
  const { account, config, usage } = data;
  const lines: string[] = [];

  // Balance
  const stripeBalance = account.checklist?.stripe_balance;
  const recent = account.checklist?.recent;
  if (stripeBalance != null) {
    const credit = Math.abs(stripeBalance);
    if (recent != null && recent > 0) {
      const available = credit - recent;
      lines.push(`Balance: ${fmtDollars(available)} available (${fmtDollars(credit)} credit − ${fmtDollars(recent)} pending)`);
    } else {
      lines.push(`Balance: ${fmtDollars(credit)} available`);
    }
  }
  lines.push(`Spending limit: ${fmtDollars(config.limit)}`);
  if (recent != null) {
    const pct = config.limit > 0 ? ((recent / config.limit) * 100).toFixed(0) : "—";
    lines.push(`Recent spend: ${fmtDollars(recent)} (${pct}% of limit)`);
  }

  const cl = account.checklist;
  if (cl?.topup) {
    lines.push(`Auto top-up: ${fmtCents(cl.topup_amount)} when balance drops below ${fmtCents(cl.topup_threshold)}`);
  }
  lines.push("");

  // Current month — per-model totals
  if (usage.length > 0) {
    const currentMonth = usage[0];
    lines.push(`${fmtPeriod(currentMonth.period)} — ${fmtCents(currentMonth.total_cost)} total`);
    for (const ms of aggregateByModel(currentMonth.items)) {
      lines.push(`  ${ms.model}  ${fmtCents(ms.totalCostCents)}`);
    }

    // Previous months
    if (usage.length > 1) {
      lines.push("");
      for (let i = 1; i < usage.length; i++) {
        const m = usage[i];
        lines.push(`${fmtPeriod(m.period)}: ${fmtCents(m.total_cost)}`);
      }
    }
  }

  return lines.join("\n");
}

function buildDetails(data: DashboardData): Record<string, unknown> {
  const stripeBalance = data.account.checklist?.stripe_balance ?? null;
  const recent = data.account.checklist?.recent ?? null;
  const availableDollars = stripeBalance != null
    ? Math.abs(stripeBalance) - (recent ?? 0)
    : null;
  return {
    balanceDollars: stripeBalance != null ? Math.abs(stripeBalance) : null,
    availableDollars,
    spendingLimitDollars: data.config.limit,
    recentSpendDollars: recent,
    autoTopup: data.account.checklist?.topup ?? false,
    topupAmountCents: data.account.checklist?.topup_amount ?? null,
    topupThresholdCents: data.account.checklist?.topup_threshold ?? null,
    account: {
      uid: data.account.uid,
      email: data.account.email,
      displayName: data.account.display_name,
      isTeam: data.account.is_team_account,
    },
    months: data.usage.map((m) => ({
      period: m.period,
      totalCostCents: m.total_cost,
      totalCostDollars: m.total_cost / 100,
      models: aggregateByModel(m.items).map((ms) => ({
        name: ms.model,
        totalCostCents: ms.totalCostCents,
        totalCostDollars: ms.totalCostCents / 100,
      })),
    })),
  };
}

// ── Fetch data ───────────────────────────────────────────────────────────────

async function fetchData(apiKey: string, months: number, signal?: AbortSignal): Promise<DashboardData> {
  const now = new Date();
  const fromDate = new Date(now.getFullYear(), now.getMonth() - (months - 1), 1);
  const from = `${fromDate.getFullYear()}.${String(fromDate.getMonth() + 1).padStart(2, "0")}`;
  const to = `${now.getFullYear()}.${String(now.getMonth() + 1).padStart(2, "0")}`;

  const [account, config, usageResult] = await Promise.all([
    deepInfraFetch<AccountInfo>("/v1/me?checklist=true", apiKey, signal),
    deepInfraFetch<BillingConfig>("/payment/config", apiKey, signal),
    deepInfraFetch<{ months: UsageMonth[]; initial_month: string }>(
      `/payment/usage?from=${from}&to=${to}`,
      apiKey,
      signal,
    ),
  ]);

  // API returns oldest-first; reverse to show newest-first
  const usage = [...usageResult.months].reverse();
  return { account, config, usage };
}

// ── Custom TUI component ─────────────────────────────────────────────────────

class DeepInfraSummaryComponent implements Component {
  private lines: string[];

  constructor(
    private theme: { bold: (s: string) => string; fg: (c: string, s: string) => string },
    private done: () => void,
    details: ReturnType<typeof buildDetails>,
  ) {
    const lines: string[] = [];

    if (details.availableDollars != null) {
      lines.push(theme.bold(theme.fg("success", `💰 Balance: ${fmtDollars(details.availableDollars)} available`)));
    } else if (details.balanceDollars != null) {
      lines.push(theme.bold(theme.fg("success", `💰 Balance: ${fmtDollars(details.balanceDollars)} credit`)));
    }
    lines.push(theme.fg("text", `📊 Limit: ${fmtDollars(details.spendingLimitDollars)}`));
    if (details.recentSpendDollars != null) {
      lines.push(theme.fg("text", `📈 Recent: ${fmtDollars(details.recentSpendDollars)}`));
    }
    if (details.autoTopup) {
      lines.push(theme.fg("text", `🔄 Auto top-up: ${fmtCents(details.topupAmountCents!)} when below ${fmtCents(details.topupThresholdCents!)}`));
    }

    if (details.months?.length > 0) {
      const current = details.months[0];
      lines.push("");
      lines.push(theme.bold(theme.fg("accent", `${fmtPeriod(current.period)} — ${fmtCents(current.totalCostCents)}`)));
      for (const model of current.models) {
        lines.push(theme.fg("text", `  ${model.name}  ${fmtCents(model.totalCostCents)}`));
      }

      if (details.months.length > 1) {
        lines.push("");
        for (let i = 1; i < details.months.length; i++) {
          const m = details.months[i];
          lines.push(theme.fg("muted", `${fmtPeriod(m.period)}: ${fmtCents(m.totalCostCents)}`));
        }
      }
    }

    this.lines = lines;
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "q") || matchesKey(data, "return")) {
      this.done();
    }
  }

  render(_width: number): string[] {
    return this.lines;
  }

  invalidate(): void {}
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function deepinfraExtension(pi: ExtensionAPI) {
  // ── Tool: deepinfra_usage ──

  pi.registerTool({
    name: "deepinfra_usage",
    label: "DeepInfra Usage",
    description:
      "Show DeepInfra account balance, spending limit, and per-model cost breakdown. " +
      "Requires DEEPINFRA_API_KEY env var.",
    promptSnippet: "View DeepInfra account balance and usage breakdown",
    promptGuidelines: [
      "Use deepinfra_usage when the user asks about their DeepInfra spending, balance, cost, invoice, or how much they've used.",
    ],
    parameters: Type.Object({
      months: Type.Optional(
        Type.Number({
          description: "Number of months of history to include (1-12, default 3)",
          minimum: 1,
          maximum: 12,
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      try {
        const apiKey = getApiKey();
        const data = await fetchData(apiKey, params.months ?? 3, signal);
        return {
          content: [{ type: "text", text: buildSummary(data) }],
          details: buildDetails(data),
        };
      } catch (err: unknown) {
        throw new Error(`DeepInfra: ${err instanceof Error ? err.message : String(err)}`);
      }
    },

    renderResult(result, options, theme) {
      if (result.details?.error) {
        return new Text(theme.fg("error", `DeepInfra error: ${result.details.error}`), 0, 0);
      }

      const data = result.details as ReturnType<typeof buildDetails>;
      if (!data) {
        return new Text(result.content[0]?.text ?? "", 0, 0);
      }

      const lines: string[] = [];

      if (data.availableDollars != null) {
        lines.push(theme.bold(theme.fg("success", `💰 Balance: ${fmtDollars(data.availableDollars)} available`)));
      } else if (data.balanceDollars != null) {
        lines.push(theme.bold(theme.fg("success", `💰 Balance: ${fmtDollars(data.balanceDollars)} credit`)));
      }
      lines.push(theme.fg("text", `📊 Limit: ${fmtDollars(data.spendingLimitDollars)}`));
      if (data.recentSpendDollars != null) {
        lines.push(theme.fg("text", `📈 Recent: ${fmtDollars(data.recentSpendDollars)}`));
      }

      if (data.months?.length > 0) {
        const current = data.months[0];
        lines.push("");
        lines.push(theme.bold(theme.fg("accent", `${fmtPeriod(current.period)} — ${fmtCents(current.totalCostCents)}`)));
        for (const model of current.models) {
          lines.push(theme.fg("text", `  ${model.name}  ${fmtCents(model.totalCostCents)}`));
        }

        if (data.months.length > 1) {
          lines.push("");
          for (let i = 1; i < data.months.length; i++) {
            const m = data.months[i];
            lines.push(theme.fg("muted", `${fmtPeriod(m.period)}: ${fmtCents(m.totalCostCents)}`));
          }
        }
      }

      return new Text(lines.join("\n"), 0, 0);
    },
  });

  // ── Command: /deepinfra ──

  pi.registerCommand("deepinfra", {
    description: "Show DeepInfra account balance and usage",
    handler: async (_args, ctx) => {
      try {
        const apiKey = getApiKey();
        ctx.ui.setStatus("deepinfra", "⏳ Fetching…");
        const data = await fetchData(apiKey, 6, ctx.signal);
        ctx.ui.setStatus("deepinfra", undefined);

        const details = buildDetails(data);

        await ctx.ui.custom<string | undefined>((_tui, theme, _kb, done) => {
          return new DeepInfraSummaryComponent(theme, done, details);
        });
      } catch (err: unknown) {
        ctx.ui.setStatus("deepinfra", undefined);
        ctx.ui.notify(`DeepInfra: ${err instanceof Error ? err.message : String(err)}`, "error");
      }
    },
  });
}