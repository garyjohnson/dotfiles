---
name: appwrite-deploy
description: Create and deploy a new Appwrite app (static site + serverless function) on the self-hosted Appwrite 1.9.x server at appwrite.app.usefulbits.io using the gh and appwrite CLIs. Covers GitHub repo creation, Appwrite project + TablesDB/storage/messaging resources, node-16.0 function deployment, static site hosting with a public domain, and GitHub-connected (VCS) auto-deploy wiring. Use when creating, provisioning, or deploying an Appwrite project from this machine.
---

# appwrite-deploy

End-to-end playbook for standing up a new Appwrite app on this machine's
self-hosted server: a GitHub repo, an Appwrite project with resources, a
serverless function, a static site, and GitHub-connected auto-deploy.

## Machine facts (baked in — this server only)

| What | Value |
|---|---|
| Server endpoint | `https://appwrite.app.usefulbits.io/v1` |
| Server version | **1.9.6** (self-hosted) |
| Org (team) | `6a81dd3f003b60391441` ("Personal projects") — get fresh with `appwrite list-organizations` |
| Sites wildcard domain | `*.appwritesite.usefulbits.io` (DNS already wildcards → `162.226.5.145`) |
| Installed function runtimes | `node-16.0`, `php-8.0`, `ruby-3.0`, `python-3.9` (only `node-16.0` for JS — newer node needs server-side image pulls) |
| Site frameworks | 15 available; use `other` for plain HTML (buildRuntime `node-22`) |
| CLI | `appwrite-cli@27.0.0` (npm global) — **already compatible with 1.9.x, do NOT downgrade** (its README states "compatible with Appwrite server version 1.9.x") |
| Env vars (in `~/.profile-env`) | `APPWRITE_API_ENDPOINT`, `APPWRITE_API_KEY` (project-scoped!), `DEEPINFRA_API_KEY`, `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL` |
| GitHub | `gh` CLI authed (run `gh auth setup-git` once so `git push` doesn't prompt) |

## Critical gotchas (read once, save hours)

These bit us building the first demo. Full detail in the reference files.

1. **API keys are project-scoped.** A key for project A 401s on project B. A new
   project needs its own key. **The first key per project must be created in the
   console** (Settings → API Keys) — CLI v27 removed `project create-key`, and
   user sessions lack the `keys.write`/`vcs.read` scopes. See [Phase 1](#phase-1--auth--project-key).
2. **CLI needs project context via `appwrite.config.json`, not `--project-id`.**
   Most commands reject `--project-id`. Run `appwrite init project` in the repo
   to write a valid `appwrite.config.json` (must be **valid JSON — no `#` comments**).
3. **GitHub (VCS) connection is project-scoped and is a one-time browser step.**
   There is **no REST endpoint to initiate the GitHub OAuth connect**. You must
   click "Connect to Git" once in the console for each new project, then cancel
   the create dialog (the installation record persists). See [references/vcs-github.md](references/vcs-github.md).
4. **1.9.x renames `databases`→`tablesdb`.** Use the `tablesdb` CLI group; the REST
   route is `/tablesdb/{db}/tables/{table}/rows` (NOT `/databases/`). Messaging
   scopes are `messages.read/write` (no `messaging.read/write`). `createExecution`
   returns `responseBody`, not `response`. See [references/cli-quirks.md](references/cli-quirks.md).
5. **node-16.0 functions are CommonJS with the classic `context` API**, no global
   `fetch`, and the internal API endpoint 308-redirects HTTP→HTTPS (follow it).
   See [references/function-runtime.md](references/function-runtime.md).
6. **Do NOT load the browser SDK from esm.sh** — its `json-bigint`→`bignumber.js`
   shim makes `instanceof` throw "E is not a function" on the first real API
   response. **Bundle the SDK with esbuild and vendor it.** See [references/browser-sdk.md](references/browser-sdk.md).

## Prereqs (verify once)

```bash
# Appwrite CLI present + compatible
appwrite --version          # expect 27.x
appwrite whoami             # expect endpoint = ...usefulbits.io/v1

# GitHub CLI authed + git uses its credentials
gh auth status
gh auth setup-git           # run once; lets `git push` use gh's token

# Env loaded
set -a; source ~/.profile-env; set +a
echo "key len=${#APPWRITE_API_KEY}  endpoint=${APPWRITE_API_ENDPOINT:-MISSING}"
```

If `APPWRITE_API_KEY` is missing or scoped to the wrong project, see Phase 1.

---

## Phase 1 — Auth & project key

You need a project API key with `vcs.read` + write scopes. Keys are
project-scoped, so for a **new** project the first key must come from the console:

1. **Human (browser):** Appwrite console → create the project first (Phase 2
   creates the project via CLI; alternatively create it in the console here),
   then Settings → API Keys → Add API Key. Select scopes: `vcs.read`,
   `functions.read/write`, `sites.read/write`, `tables.read/write`,
   `rows.read/write`, `users.read/write`, `messages.read/write`,
   `files.read/write`, and (optionally) `keys.read/write`. Set expiration unlimited.
   Copy the secret.
2. **Store it** in `~/.profile-env` as `APPWRITE_API_KEY` (and keep
   `APPWRITE_API_ENDPOINT=https://appwrite.app.usefulbits.io/v1`), then reload:
   ```bash
   set -a; source ~/.profile-env; set +a
   ```
3. **Point the CLI** at endpoint + project + key (persisted to `~/.appwrite/prefs.json`):
   ```bash
   appwrite client --endpoint https://appwrite.app.usefulbits.io/v1 \
     --project-id <PROJECT_ID> --key "$APPWRITE_API_KEY"
   ```

> Tip: if you already have a key with `keys.write` for an org-scope, you can mint
> more project keys via `appwrite organization create-key` — but the bootstrap
> key still starts in the console.

---

## Phase 2 — GitHub repo + Appwrite project

```bash
# 2a. Create + clone the repo under ~/repositories/<REPO> (NOT directly in ~/repositories)
REPO=useful-bits-<name>
gh repo create garyjohnson/$REPO --private --clone --description "..." 
cd ~/repositories/$REPO

# 2b. Create the Appwrite project under the org
ORG=$(appwrite list-organizations -j | python3 -c "import sys,json;print(json.load(sys.stdin)['teams'][0]['\$id'])")
appwrite organization create-project --organization-id $ORG \
  --project-id <PROJECT_ID> --name "<Project Name>"   # project-id: a-z and hyphen, max 36

# 2c. Bind this repo to the project (writes a valid appwrite.config.json + pulls resources)
appwrite client --endpoint https://appwrite.app.usefulbits.io/v1 --project-id <PROJECT_ID> --key "$APPWRITE_API_KEY"
appwrite init project --organization-id $ORG --project-id <PROJECT_ID> --project-name "<Project Name>" -f
```

`appwrite init project` also drops an `appwrite-cli` agent skill under
`.agents/skills/` — keep or `git rm` it per taste.

---

## Phase 3 — Appwrite resources

Create with the **session or project key**. `stringArray` flags need the flag
**repeated per value** (not comma-separated). Optional columns need
`--required=false`.

```bash
PID=<PROJECT_ID>
# Database (TablesDB, not databases)
appwrite tablesdb create --database-id main --name "Main"

# Table + permissions (row-level security)
appwrite tablesdb create-table --database-id main --table-id messages --name "Messages" \
  --row-security \
  --permissions 'read("users")' --permissions 'create("users")' \
  --permissions 'update("users")' --permissions 'delete("users")'
  # NOTE: inline --columns is finicky (rejects 'longtext'). Add columns individually:

appwrite tablesdb create-string-column  --database-id main --table-id messages --key userId  --required      --size 64
appwrite tablesdb create-longtext-column --database-id main --table-id messages --key prompt --required
appwrite tablesdb create-longtext-column --database-id main --table-id messages --key response --required=false
appwrite tablesdb create-string-column  --database-id main --table-id messages --key role    --required=false --size 16

# Storage bucket (file security)
appwrite storage create-bucket --bucket-id uploads --name "Uploads" --file-security \
  --permissions 'read("users")' --permissions 'create("users")' --permissions 'update("users")' --permissions 'delete("users")'

# Messaging topic
appwrite messaging create-topic --topic-id activity --name "Activity"

# Web platform for the site hostname (so the origin is recognized)
appwrite project create-web-platform --project-id $PID --platform-id <site>-web \
  --name "<Site>" --hostname <site-subdomain>.appwritesite.usefulbits.io
```

---

## Phase 4 — Function (node-16.0)

Use the template in [assets/function/](assets/function/). It's CommonJS, classic
`context` API, native `https` (no fetch), follows redirects, calls an
OpenAI-compatible endpoint, stores a TablesDB row, and drafts a messaging email.

```bash
# 4a. Create the function. scopes MUST be valid names (no messaging.read — use messages.read).
#     See references/scopes.md. An invalid scope -> HTTP 400.
appwrite functions create --function-id <fn-id> --name "<Fn>" --runtime node-16.0 \
  --entrypoint src/main.js --execute 'users' \
  --scopes 'tables.read' --scopes 'tables.write' --scopes 'rows.read' --scopes 'rows.write' \
  --scopes 'users.read' --scopes 'messages.read' --scopes 'messages.write' \
  --scopes 'files.read' --scopes 'files.write' \
  --timeout 30

# 4b. Function variables (OpenAI-compatible endpoint). --variable-id is required.
appwrite functions create-variable --function-id <fn-id> --variable-id OPENAI_API_BASE_URL --key OPENAI_API_BASE_URL --value "https://api.deepinfra.com/v1"
appwrite functions create-variable --function-id <fn-id> --variable-id OPENAI_API_KEY       --key OPENAI_API_KEY       --value "$DEEPINFRA_API_KEY" --secret
appwrite functions create-variable --function-id <fn-id> --variable-id OPENAI_MODEL        --key OPENAI_MODEL        --value "openai/gpt-oss-20b"

# 4c. First deploy (manual upload — no GitHub needed yet). Build waits for status 'ready' AND active.
appwrite functions create-deployment --function-id <fn-id> --code functions/<fn-id> \
  --entrypoint src/main.js --commands "npm install --omit=dev" --activate

# 4d. Test end-to-end. Note: response field is 'responseBody' in 1.9.x.
python3 - <<'PY'
import os,urllib.request,urllib.error,json
ep=os.environ['APPWRITE_API_ENDPOINT']; key=os.environ['APPWRITE_API_KEY']; proj="<PROJECT_ID>"
def call(m,p,b=None):
  data=json.dumps(b).encode() if b is not None else None
  r=urllib.request.Request(ep+p,data=data,method=m)
  if data: r.add_header('Content-Type','application/json')
  r.add_header('X-Appwrite-Key',key); r.add_header('X-Appwrite-Project',proj); r.add_header('X-Appwrite-Response-Format','1.9.0')
  try:
    with urllib.request.urlopen(r,timeout=60) as x: return x.status,x.read().decode()
  except urllib.error.HTTPError as e: return e.code,e.read().decode()[:300]
s,b=call('POST','/functions/<fn-id>/executions',{'method':'POST','body':json.dumps({'prompt':'ping'}),'async':False})
e=json.loads(b); print('status',e.get('status'),'http',e.get('responseStatusCode'))
print('logs:',(e.get('logs') or '').replace(chr(10),' | '))
print('body:',(e.get('responseBody') or '')[:300])
PY
```

> Need a newer runtime (node-18/20/22)? It's a **server-side change** — pull the
> runtime executor image + register it. Not doable from the CLI. The demo used
> node-16.0 (EOL but functional) and worked around its limits.

---

## Phase 5 — Static site

Use the template in [assets/site/](assets/site/). Plain HTML + the Appwrite Web
SDK, **bundled locally** (see [assets/bundle-sdk.sh](assets/bundle-sdk.sh) /
[references/browser-sdk.md](references/browser-sdk.md)).

```bash
# 5a. Create the site (framework 'other', static adapter, no build/install commands)
appwrite sites create --site-id <site-id> --name "<Site>" --framework other --adapter static \
  --build-runtime node-22 --output-directory . --install-command "" --build-command ""

# 5b. Bundle the Web SDK into the repo (one-time per project; do NOT use esm.sh)
bash <skill-dir>/assets/bundle-sdk.sh site/    # writes site/appwrite-sdk.mjs
# import map in index.html: { "imports": { "appwrite": "./appwrite-sdk.mjs" } }

# 5c. First deploy (manual upload)
appwrite sites create-deployment --site-id <site-id> --code site --activate

# 5d. Public URL. Self-hosted gives a *preview* domain gated behind console auth.
#      For a public URL, create a site rule on the wildcard subdomain (no DNS needed):
appwrite proxy create-site-rule --domain <site-subdomain>.appwritesite.usefulbits.io --site-id <site-id>
#      Status becomes 'verified' immediately; serve at https://<site-subdomain>.appwritesite.usefulbits.io/
```

Verify: `curl -sSL https://<site-subdomain>.appwritesite.usefulbits.io/ | head`.

> The preview domain (`<randomId>.appwritesite.usefulbits.io`) requires a console
> session cookie — fine for browsing in the console, not for curl/public access.

---

## Phase 6 — GitHub-connected (VCS) auto-deploy

**Requires Phase 1's one-time browser connect** (see [references/vcs-github.md](references/vcs-github.md)).

```bash
PID=<PROJECT_ID>
set -a; source ~/.profile-env; set +a

# 6a. Confirm the GitHub App installation exists for THIS project (project-scoped!)
python3 -c "
import os,urllib.request,json
ep=os.environ['APPWRITE_API_ENDPOINT']; key=os.environ['APPWRITE_API_KEY']; proj='$PID'
r=urllib.request.Request(ep+'/vcs/installations'); r.add_header('X-Appwrite-Key',key)
r.add_header('X-Appwrite-Project',proj); r.add_header('X-Appwrite-Response-Format','1.9.0')
d=json.load(urllib.request.urlopen(r,timeout=15))
print('installations:',[(i['\$id'],i['organization']) for i in d['installations']])
"
#   If empty -> HUMAN STEP: console -> this project -> Functions(or Sites) -> Create
#   -> Connect to Git/GitHub -> one click (App already on your GH account) -> Cancel.
#   Then re-run the snippet.

# 6b. Get GitHub's numeric repo ID = providerRepositoryId (NOT the repo name)
REPO_NUM=$(gh api repos/garyjohnson/<repo> --jq .id)
INSTALL_ID=<the $id from 6a>

# 6c. Wire the function to GitHub. update REQUIRES --name + --runtime even if unchanged.
appwrite functions update --function-id <fn-id> --name "<Fn>" --runtime node-16.0 \
  --entrypoint src/main.js --execute 'users' \
  --scopes 'tables.read' --scopes 'tables.write' --scopes 'rows.read' --scopes 'rows.write' \
  --scopes 'users.read' --scopes 'messages.read' --scopes 'messages.write' \
  --scopes 'files.read' --scopes 'files.write' \
  --installation-id $INSTALL_ID --provider-repository-id $REPO_NUM \
  --provider-branch main --provider-root-directory /functions/<fn-id> --provider-silent-mode

# 6d. Wire the site to GitHub. update REQUIRES --name + --framework + --build-runtime.
appwrite sites update --site-id <site-id> --name "<Site>" --framework other --adapter static \
  --build-runtime node-22 --output-directory . --install-command "" --build-command "" \
  --installation-id $INSTALL_ID --provider-repository-id $REPO_NUM \
  --provider-branch main --provider-root-directory /site --provider-silent-mode

# 6e. Trigger the first VCS builds from the main branch
appwrite functions create-vcs-deployment --function-id <fn-id> --type branch --reference main --activate
appwrite sites    create-vcs-deployment --site-id    <site-id> --type branch --reference main --activate

# 6f. Push to main from now on -> GitHub webhook auto-deploys both (within ~6s)
git add -A && git -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" commit -m "..." && git push
```

## Done

- Site: `https://<site-subdomain>.appwritesite.usefulbits.io/`
- Function: executable via the site (Functions SDK) or `POST /functions/<fn-id>/executions`
- Auto-deploy: any `git push` to `main` rebuilds both

## References

- [references/cli-quirks.md](references/cli-quirks.md) — CLI behavior gotchas (flags, JSON, project context)
- [references/function-runtime.md](references/function-runtime.md) — node-16.0 runtime contract + redirect-fix pattern
- [references/vcs-github.md](references/vcs-github.md) — GitHub App connect flow + providerRepositories endpoint + wiring
- [references/browser-sdk.md](references/browser-sdk.md) — esm.sh bug, esbuild bundling, SDK method notes
- [references/scopes.md](references/scopes.md) — full scope-name list for 1.9.x
- [assets/function/](assets/function/) — function template (CommonJS, OpenAI-compatible, TablesDB + messaging)
- [assets/site/](assets/site/) — static site template (HTML + bundled SDK)
- [assets/bundle-sdk.sh](assets/bundle-sdk.sh) — bundle the Web SDK with esbuild
