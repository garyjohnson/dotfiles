#!/usr/bin/env bash
#
# sync-deepinfra-langfuse.sh
#
# Pull model cost config (token pricing) from DeepInfra and upload it to a
# self-hosted Langfuse instance.
#
# By default it only syncs models you've actually used (from DeepInfra
# /payment/usage). Pass --all to sync every token-priced / text-generation
# model DeepInfra lists.
#
# Dependencies: curl, jq
#
# Requires (env): DEEPINFRA_API_KEY, LANGFUSE_BASE_URL, LANGFUSE_PUBLIC_KEY,
#   LANGFUSE_SECRET_KEY. Missing vars are sourced from ~/.profile-env if defined.
#
set -euo pipefail

DEEPINFRA_API="${DEEPINFRA_API_URL:-https://api.deepinfra.com}"
DEEPINFRA_USAGE_FROM="${DEEPINFRA_USAGE_FROM:-current-1}"   # period for usage scan
MODE="used"                                                 # 'used' | 'all'
DRY_RUN=""

usage() {
  cat <<EOF
Usage: sync-deepinfra-langfuse.sh [options]

Options:
  --all            Sync every token-priced text-generation model DeepInfra lists
                   (default: only models with usage in the scanned period)
  --from <period>  DeepInfra usage period (YYYY.MM, current, current-N, or unix ts).
                   Default: ${DEEPINFRA_USAGE_FROM}
  --dry-run        Print what would be synced without hitting the Langfuse API.
  -h, --help       Show this help

Env:
  DEEPINFRA_API_KEY        Your DeepInfra API token (required)
  LANGFUSE_BASE_URL        e.g. https://langfuse.example.com (required)
  LANGFUSE_PUBLIC_KEY      Langfuse public key (required)
  LANGFUSE_SECRET_KEY      Langfuse secret key (required)
  DEEPINFRA_USAGE_FROM     Usage period override (see --from)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) MODE="all"; shift ;;
    --from) DEEPINFRA_USAGE_FROM="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# ---- Load env ----
for v in DEEPINFRA_API_KEY LANGFUSE_BASE_URL LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY; do
  if [[ -z "${!v:-}" ]]; then
    if [[ -f "$HOME/.profile-env" ]]; then
      # shellcheck disable=SC1090
      set +u; source "$HOME/.profile-env"; set -u
    fi
    break
  fi
done

for v in DEEPINFRA_API_KEY LANGFUSE_BASE_URL LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY; do
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: $v is not set. Export it or add to ~/.profile-env." >&2
    exit 1
  fi
done

LF_AUTH="${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}"

log()  { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

# ---------- Fetch DeepInfra usage (which models have been used) ----------
fetch_usage_models() {
  local from="$1"
  local resp
  resp="$(curl -sf --retry 2 \
    -H "Authorization: Bearer ${DEEPINFRA_API_KEY}" \
    "${DEEPINFRA_API}/payment/usage?from=${from}")" \
    || { echo "ERROR: failed to fetch DeepInfra usage" >&2; return 1; }
  # distinct model names that saw usage
  jq -r '.months[].items[].model.model_name' <<<"$resp" | grep -v '^$' | sort -u
}

# ---------- Fetch DeepInfra model list (current pricing) ----------
fetch_models() {
  curl -sf --retry 2 "${DEEPINFRA_API}/models/list" \
    || { echo "ERROR: failed to fetch DeepInfra model list" >&2; return 1; }
}

# Build the Langfuse POST body for one model. Stores USD-per-token under
# pricingTiers so cached input tokens are costed separately.
build_payload() {
  local model_name="$1" input_cents="$2" output_cents="$3" cached_mult="${4:-}"

  local input_usd output_usd cached_usd
  # cents per token -> USD per token
  input_usd="$(awk "BEGIN{printf \"%.12f\", ($input_cents)/100}")"
  output_usd="$(awk "BEGIN{printf \"%.12f\", ($output_cents)/100}")"

  # regex-escape the model name for exact match
  local esc
  esc="$(printf '%s' "$model_name" | sed 's/[.[\*^$()+?{|}]/\\&/g')"

  local prices="{\"input\":${input_usd},\"output\":${output_usd}"
  if [[ -n "$cached_mult" && "$cached_mult" != "null" ]]; then
    cached_usd="$(awk "BEGIN{printf \"%.12f\", ($input_cents)/100*($cached_mult)}")"
    prices="${prices},\"cache_read_input_tokens\":${cached_usd}"
  fi
  prices="${prices}}"

  jq -n \
    --arg modelName "$model_name" \
    --arg matchPattern "(?i)^(${esc})$" \
    --argjson prices "$prices" \
    '{ modelName: $modelName,
       matchPattern: $matchPattern,
       unit: "TOKENS",
       pricingTiers: [
         { name: "Standard", isDefault: true, priority: 0,
           conditions: [], prices: $prices }
       ]
     }'
}

# ---------- Langfuse: does a custom model with this name already exist? ----------
find_existing_custom() {
  local model_name="$1"
  local page=1 limit=100 found_id=""
  while :; do
    local resp
    resp="$(curl -sf --retry 2 \
      -u "$LF_AUTH" \
      "${LANGFUSE_BASE_URL}/api/public/models?page=${page}&limit=${limit}")" \
      || { echo "ERROR: failed to fetch Langfuse models (page ${page})" >&2; return 1; }
    found_id="$(jq -r --arg n "$model_name" \
      '.data[]? | select(.modelName == $n and .isLangfuseManaged == false) | .id' \
      <<<"$resp" | head -1)"
    [[ -n "$found_id" ]] && { echo "$found_id"; return 0; }
    # stop when we've covered all pages
    local meta_total
    meta_total="$(jq -r '.meta.totalItems // 0' <<<"$resp" 2>/dev/null)"
    local last
    last=$(( ( (10#$meta_total) + limit - 1) / limit ))
    [[ "$page" -ge "$last" ]] && break
    page=$((page + 1))
    [[ "$page" -gt 50 ]] && break
  done
  echo ""
}

delete_model() {
  local id="$1" name="$2"
  curl -sf --retry 2 -X DELETE -u "$LF_AUTH" \
    "${LANGFUSE_BASE_URL}/api/public/models/${id}" \
    >/dev/null \
    && log "deleted existing custom model '${name}' (${id})"
}

create_model() {
  local payload="$1" name="$2"
  local body
  body="$(curl -sf --retry 2 -X POST \
    -u "$LF_AUTH" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${LANGFUSE_BASE_URL}/api/public/models")" \
    || { echo "ERROR: failed to create model '${name}'" >&2; return 1; }
  jq -r '"created '"'"'\(.modelName)'"'"' (id='"'"'\(.id)'"'"')"' <<<"$body"
}

# ================= MAIN =================
log "DeepInfra usage period: ${DEEPINFRA_USAGE_FROM} (mode: ${MODE})"

if [[ "$MODE" == "used" ]]; then
  used="$(fetch_usage_models "$DEEPINFRA_USAGE_FROM")"
  [[ -z "$used" ]] && { echo "No model usage found for period '${DEEPINFRA_USAGE_FROM}'. Try --from current-2 or --all." >&2; exit 1; }
  log "Models with usage:"
  echo "$used" | sed 's/^/    /'
fi

models_json="$(fetch_models)"
log "Fetched $(jq 'length' <<<"$models_json") models from DeepInfra."

dry="${DRY_RUN:+ (dry-run)}"
synced=0 skipped=0
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  # pull the pricing object for this model
  pricing="$(jq -c --arg n "$name" '[.[] | select(.model_name == $n)][0] | .pricing' <<<"$models_json")"
  [[ -z "$pricing" || "$pricing" == "null" ]] && { warn "no pricing data for '${name}' — skipping"; skipped=$((skipped+1)); continue; }

  ptype="$(jq -r '.type' <<<"$pricing")"
  if [[ "$ptype" != "tokens" ]]; then
    warn "'${name}' priced by '${ptype}' (not tokens) — skipping"
    skipped=$((skipped+1))
    continue
  fi

  input_cents="$(jq -r '.cents_per_input_token // empty' <<<"$pricing")"
  output_cents="$(jq -r '.cents_per_output_token // empty' <<<"$pricing")"
  cached_mult="$(jq -r '.rate_per_input_token_cached // null' <<<"$pricing")"
  if [[ -z "$input_cents" || -z "$output_cents" || "$input_cents" == "null" || "$output_cents" == "null" ]]; then
    warn "'${name}' missing input/output token price — skipping"
    skipped=$((skipped+1))
    continue
  fi

  payload="$(build_payload "$name" "$input_cents" "$output_cents" "$cached_mult")"
  in_m="$(awk "BEGIN{printf \"%.4f\", ${input_cents}/100*1000000}")"
  out_m="$(awk "BEGIN{printf \"%.4f\", ${output_cents}/100*1000000}")"
  cache_s=""
  if [[ -n "$cached_mult" && "$cached_mult" != "null" ]]; then
    cache_s=" cache_mult=${cached_mult}"
  fi
  log "Syncing '${name}': \$${in_m}/M in, \$${out_m}/M out${cache_s}${dry}"

  if [[ -n "$DRY_RUN" ]]; then
    continue
  fi

  existing="$(find_existing_custom "$name")"
  if [[ -n "$existing" ]]; then
    delete_model "$existing" "$name"
  fi
  if create_model "$payload" "$name"; then
    synced=$((synced+1))
  else
    skipped=$((skipped+1))
  fi
done < <(if [[ "$MODE" == "used" ]]; then echo "$used"; else jq -r '.[].model_name | select(. != null)' <<<"$models_json"; fi)

log "Done. Synced: ${synced}, skipped: ${skipped}${dry:-.}"
