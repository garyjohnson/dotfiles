#!/usr/bin/env bash
# Bundle the Appwrite Web SDK into a single self-contained ESM file and vendor
# it into a site directory. DO NOT load appwrite from esm.sh — its json-bigint
# shim breaks `instanceof` on real API responses ("E is not a function").
#
# Usage:  bash appwrite-deploy/assets/bundle-sdk.sh <site-dir> [version]
#   <site-dir>  dir containing index.html (e.g. ./site)
#   [version]   appwrite version (default 26.2.0)
#
# Writes <site-dir>/appwrite-sdk.mjs and wires the import map to use it.
set -euo pipefail

SITE_DIR="${1:?usage: $0 <site-dir> [version]}"
VERSION="${2:-26.2.0}"
SDK_OUT="$SITE_DIR/appwrite-sdk.mjs"

if [ ! -f "$SITE_DIR/index.html" ]; then
  echo "✗ $SITE_DIR/index.html not found" >&2; exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ bundling appwrite@$VERSION with esbuild into $SDK_OUT"
cd "$TMP"
echo 'export * from "appwrite"' > entry.mjs
echo '{"name":"sdk-build","version":"1.0.0","type":"module","private":true}' > package.json
npm install --no-audit --no-fund --silent "appwrite@$VERSION" esbuild >/dev/null
npx esbuild entry.mjs --bundle --format=esm --minify --outfile=appwrite-sdk.mjs

cp appwrite-sdk.mjs "$SDK_OUT"
SZ=$(wc -c < "$SDK_OUT")
echo "✓ wrote $SDK_OUT ($SZ bytes)"

# Ensure the import map points at the local bundle (idempotent-ish: checks for the
# local path; if missing, it expects the file to already use an importmap).
if ! grep -q '"./appwrite-sdk.mjs"' "$SITE_DIR/index.html"; then
  echo "⚠ $SITE_DIR/index.html: add/fix the import map:"
  echo '    <script type="importmap">{ "imports": { "appwrite": "./appwrite-sdk.mjs" } }</script>'
fi

# Sanity: no bare imports should remain in the bundle.
if grep -qE '^import .* from ["'"'"']' "$SDK_OUT"; then
  echo "⚠ WARNING: bare imports remain in $SDK_OUT — the bundle is not self-contained" >&2
else
  echo "✓ self-contained (no bare imports)"
fi
