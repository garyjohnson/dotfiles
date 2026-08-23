# sync-deepinfra-langfuse.sh

Pull model token-pricing from [DeepInfra](https://deepinfra.com) and upload it to a
self-hosted [Langfuse](https://langfuse.com) instance so trace cost tracking is correct.

## What it does

1. **Discovers models you use** by querying DeepInfra's billing usage
   (`GET /payment/usage`). Default looks at the previous calendar month.
   Pass `--all` to sync every token-priced model DeepInfra lists instead.
2. **Pulls current list pricing** from `GET /models/list`.
3. For each token-priced model, creates (or recreates) a custom Langfuse model
   definition with a `Standard` pricing tier (`unit = TOKENS`):
   - `input` / `output` — USD per token, converted from DeepInfra's cents/token
   - `cache_read_input_tokens` — DeepInfra bills cached input separately via a
     `rate_per_input_token_cached` multiplier; mapped so cached tokens cost correctly.
4. **Idempotent upsert** — Langfuse has no model update endpoint, so it lists
   existing models, deletes any existing *custom* (non-managed) definition with
   the same name, then creates a fresh one. Built-in Langfuse-managed models are
   never touched.

## Dependencies

- `curl`, `jq`

## Environment

```bash
export DEEPINFRA_API_KEY=...        # DeepInfra token (needed for /payment/usage)
export LANGFUSE_BASE_URL=https://langfuse.app.usefulbits.io
export LANGFUSE_PUBLIC_KEY=pk-lf-...
export LANGFUSE_SECRET_KEY=sk-lf-...
```

Missing vars are sourced from `~/.profile-env` if present.

## Usage

```bash
./sync-deepinfra-langfuse.sh            # sync models used last month
./sync-deepinfra-langfuse.sh --dry-run  # preview without writing
./sync-deepinfra-langfuse.sh --all      # sync every token-priced model
./sync-deepinfra-langfuse.sh --from current-3   # look further back for usage
```

| Option      | Description |
|-------------|-------------|
| `--all`     | Sync all token-priced models DeepInfra lists (default: only used ones) |
| `--from <p>`| DeepInfra usage period: `YYYY.MM`, `current`, `current-N`, or unix ts |
| `--dry-run` | Print what would be synced; don't call the Langfuse API |
| `-h`        | Show help |

## Notes / limitations

- Only models DeepInfra prices **per token** are synced. Image, video, time,
  character, and embedding-style pricing (e.g. `image_units`, `input_tokens`,
  `output_length`) are skipped with a warning.
- DeepInfra service-tier multipliers (`rate_per_service_tier_flex`/`priority`)
  are not modeled — base list price is used for `input`/`output`.
- Generated model name is the full DeepInfra slug (e.g.
  `deepseek-ai/DeepSeek-V4-Pro`); `matchPattern` is an exact, case-insensitive
  regex in the form `(?i)^(slug)$`. If your traces report a different
  `generation.model` string, adjust `matchPattern` in the script.
