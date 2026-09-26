# CLI quirks (appwrite-cli 27.x ↔ server 1.9.6)

Learned the hard way. Keep these in mind for every command.

## Project context

- **`--project-id` is rejected by most commands** (e.g. `apps list`, and it's not
  a global flag). The CLI resolves the project from `appwrite.config.json` in
  the cwd. Run `appwrite init project` to write it.
- **`appwrite.config.json` must be valid JSON.** `#` comments break parsing
  (`invalid character '#'`). If you hand-write it, use `{}`. Prefer
  `appwrite init project --organization-id X --project-id Y --project-name Z -f`,
  which writes a valid file and pulls resources.
- **`appwrite pull --all -f`** re-syncs `appwrite.config.json` from the server.
  It may scaffold empty function dirs (e.g. `functions/<name>/`); delete the
  strays and fix the `path` field to point at your real code dir.
- **The CLI keeps dropping context** between invocations if the config file is
  invalid. Symptom: "project is not set" right after `appwrite client …`
  succeeded → your `appwrite.config.json` is malformed. Fix the file.

## Auth (cookie vs key)

- `appwrite login` stores a **session cookie** in `~/.appwrite/prefs.json`.
  The cookie can create resources (projects, DBs, tables, buckets, topics,
  functions/sites without VCS) but REST VCS + key operations need
  `vcs.read` / `keys.write` scopes that user sessions **do not** carry.
- `appwrite client --endpoint … --project-id … --key "$APPWRITE_API_KEY"`
  stores a key in prefs. Keys are **project-scoped** — a key for project A
  401s on project B.
- When the CLI has both, it falls back to the cookie for resource creation
  if the key lacks scopes. VCS-linked creates then 404 ("Installation not
  found") because the cookie can't read VCS. Use a project key with
  `vcs.read` for VCS work.

## Flag parsing (cobra)

- **`stringArray` flags need the flag repeated per value**, not comma-separated:
  `--permissions 'read("users")' --permissions 'create("users")'`.
  Comma form → "unknown command" error.
- **Optional columns need `--required=false` explicitly** — `--required` is a
  required bool flag; omitting it errors with `required flag(s) "required" not set`.
- **`--variable-id` is required** for `functions create-variable` (not just
  `--key`/`--value`).
- **`functions update` requires `--name` and `--runtime`** even when you're
  only changing VCS fields. Same for `sites update` (`--name`, `--framework`,
  `--build-runtime`). Omitting → "required flag(s) 'name' not set".
- **`appwrite init project` is interactive** unless `-f` / `--all` is passed
  (`appwrite pull --all -f`).

## JSON output

- **`-j` (filtered JSON) drops some fields.** E.g. the execution `response`
  body and `responseBody` are omitted from `-j` output. Use **`-R` (raw)** or
  fetch the endpoint via raw HTTP (Python `urllib`) for full payloads.
- When parsing CLI `-j` output in Python, guard for empty/non-JSON (the CLI
  prints errors to stdout on failure).

## 1.9.x naming changes (the big ones)

- **`databases` is deprecated → `tablesdb`.** CLI group `tablesdb`; REST route
  `/tablesdb/{db}/tables/{table}/rows` (NOT `/databases/`).
- **Messaging scopes:** no `messaging.read/write` — use `messages.read/write`,
  `topics.read/write`, `subscribers.read/write`, `providers.read/write`,
  `targets.read/write`. Passing `messaging.read` to `functions create --scopes`
  → HTTP 400.
- **`createExecution` returns `responseBody`**, not `response` (older servers
  used `response`). Read `responseBody ?? response` for forward-compat.
- **Scope names are dot notation:** `tables.read`, `files.read`, `vcs.read`,
  `keys.write`, etc. See [scopes.md](scopes.md).

## TablesDB column quirks

- Inline `--columns` on `create-table` rejects some types (`longtext` →
  "Invalid type for attribute"). Create the table with no columns, then add
  columns with `create-string-column` / `create-longtext-column` / etc.
- Column statuses start `processing`; they're usable within a second or two.
- `list-columns --database-id … --table-id …` to verify.

## Functions build/deploy polling

- After `create-deployment` (or `create-vcs-deployment`), wait for the
  deployment `status` to become `ready` **AND** the function's `deploymentId`
  to equal the new deployment's `$id` (activation can lag the build).
- `functions list-deployments` then `functions get-deployment` to poll; or
  `functions get` for the active `deploymentId`.
- node-16.0 ESM → "Unexpected token 'export'"; see [function-runtime.md](function-runtime.md).

## Sites on self-hosted

- The auto-generated preview domain (`<id>.appwritesite.usefulbits.io`) is
  **gated behind console auth** (returns the console SPA to curl). For a public
  URL, `appwrite proxy create-site-rule --domain <sub>.appwritesite.usefulbits.io --site-id <id>`.
- No DNS work needed — `*.appwritesite.usefulbits.io` already wildcards.
- Register the hostname as a web platform (`project create-web-platform`) so
  Appwrite recognizes the origin for client SDK calls.
