# Function runtime contract (node-16.0 on Appwrite 1.9.x)

Empirically verified by deploying a probe function and reading `logs` + `responseBody`.

## Signature

node-16.0 is **CommonJS only**. ESM (`export default`) fails with
`Syntax error in src/main.js: Unexpected token 'export'`.

```js
// src/main.js
module.exports = async (context) => { … };
```

This is the **classic context API** (not the modern `export default ({req,res,…})`
shown in newer docs).

## `context` shape

```
context.req   context.res   context.log   context.error
```

### `context.req` (keys)
`body, bodyRaw, bodyText, bodyJson, bodyBinary, headers, method, host, scheme,
query, queryString, port, url, path`

- Input body: `context.req.body` (string → `JSON.parse`) or `context.req.bodyJson`.
- The per-execution Appwrite API key arrives on the **request header**, not an env var:
  `context.req.headers['x-appwrite-key']` (len ~183; scoped to the function's granted scopes).

### `context.res` (methods)
`send, text, binary, json, empty, redirect`

- `context.res.json(obj)` and `context.res.send(str, status, headers)` both work.
- The response is returned to the caller in the `createExecution` response
  (`responseBody` field in 1.9.x). The stored execution record's `responseBody`
  can appear empty when fetched later via GET — read it from the synchronous
  `createExecution` response instead.

## Environment variables (verified present)

| Var | Example | Use |
|---|---|---|
| `APPWRITE_FUNCTION_PROJECT_ID` | `usefulbits-appwrite-demo` | `X-Appwrite-Project` for server calls |
| `APPWRITE_FUNCTION_API_ENDPOINT` | `http://appwrite.app.usefulbits.io/v1` | base URL for server calls (**internal http** — see redirect note) |
| `APPWRITE_FUNCTION_ID` | `demo-fn` | self-reference |
| `APPWRITE_FUNCTION_DEPLOYMENT` | `6a8…` | current deployment |
| `APPWRITE_REGION` | `default` | |
| `APPWRITE_FUNCTION_RUNTIME_NAME/VERSION` | `Node.js` / `16.0` | |
| `APPWRITE_FUNCTION_MEMORY/CPUS` | `8192` / `8` | |
| `APPWRITE_VCS_*` | commit hash, repo, branch… | only when deployed via VCS |
| Your function variables | e.g. `OPENAI_API_KEY` | whatever you set |

> There is **no** `APPWRITE_FUNCTION_API_KEY` env var for runtime server calls —
> the key is on `x-appwrite-key` header. (The build-time `APPWRITE_FUNCTION_API_KEY`
> env var exists only during the build process.)

## Node 16 limits to work around

1. **No global `fetch`.** Use Node's native `https`/`http` modules (or `node-fetch`,
   but native keeps the bundle tiny). Write a small `request()` helper.
2. **Follow 3xx redirects.** `APPWRITE_FUNCTION_API_ENDPOINT` is internal
   `http://…` and the server **308-redirects to https**. Node's http/https clients
   don't follow redirects by default, so TablesDB/Messaging calls silently 308
   and return empty bodies. Your `request()` helper MUST follow 3xx (keep method
   + body on 307/308; drop to GET on 301/302/303).
3. **No top-level await / ESM.** CommonJS + `module.exports = async (context)`.

## Calling Appwrite from the function (raw REST)

Because node-appwrite's modern versions assume `fetch`, raw REST with native
`https` is the most robust path on node-16.0:

```js
const headers = {
  "X-Appwrite-Project": process.env.APPWRITE_FUNCTION_PROJECT_ID,
  "X-Appwrite-Response-Format": "1.9.0",
  "X-Appwrite-Key": context.req.headers["x-appwrite-key"] || "",
};
// TablesDB row:
await request(endpoint + "/tablesdb/main/tables/messages/rows",
  { method: "POST", headers, body: JSON.stringify({ rowId: "row-"+Date.now(), data: {...}, permissions: [...] }) });
// Messaging draft email:
await request(endpoint + "/messaging/messages/email",
  { method: "POST", headers, body: JSON.stringify({ messageId: "msg-"+Date.now(), subject, content, users:[userId], topics:[TOPIC_ID], draft: true, html: true }) });
```

Endpoints: TablesDB rows = `/tablesdb/{db}/tables/{table}/rows`;
messaging email = `/messaging/messages/email`; subscribers =
`/messaging/topics/{topicId}/subscribers`.

## OpenAI-compatible call

The function calls `/v1/chat/completions` on an OpenAI-compatible endpoint
(DeepInfra default). Configurable via function variables
`OPENAI_API_BASE_URL`, `OPENAI_API_KEY`, `OPENAI_MODEL`. Same native `https`
helper, `Authorization: Bearer <key>`.

## Deploy + test loop

```bash
appwrite functions create-deployment --function-id <id> --code functions/<id> \
  --entrypoint src/main.js --commands "npm install --omit=dev" --activate
# poll until deployment status 'ready' AND function.deploymentId == new deployment id
# test:
appwrite functions create-execution --function-id <id> --method POST \
  --body '{"prompt":"hi"}' -R   # or via raw HTTP POST /functions/<id>/executions
```

Read `logs` (always populated) and `responseBody` (from the synchronous
createExecution response) to debug.
