# Browser SDK (Appwrite Web SDK) for static sites

How to use the Appwrite Web SDK in a no-build static site on this server.

## DO NOT use esm.sh for appwrite

Loading `https://esm.sh/appwrite@26.2.0` breaks on the first real API response:

```
Auth failed: E is not a function. (evaluating 'u instanceof E')
```

Cause: esm.sh's bundling of `appwrite` → `json-bigint` → `bignumber.js` returns
a **plain module-namespace object** instead of the `BigNumber` constructor. Inside
`json-bigint`, `var E = require("bignumber.js")` is then not a function, so
`u instanceof E` throws when the SDK parses a response containing a big-int ID
(e.g. account creation). The page loads fine; it only throws on a real API call.

## DO: bundle the SDK with esbuild and vendor it

One self-contained ESM file, no runtime CDN, no dependency rewriting.

```bash
# see assets/bundle-sdk.sh
cd <repo>
mkdir -p /tmp/sdk-build && cd /tmp/sdk-build
echo 'export * from "appwrite"' > entry.mjs
npm i --no-audit --no-fund appwrite@26.2.0 esbuild
npx esbuild entry.mjs --bundle --format=esm --minify --outfile=appwrite-sdk.mjs
cp appwrite-sdk.mjs <repo>/site/appwrite-sdk.mjs   # ~148 KB
```

Then an import map in `index.html`:

```html
<script type="importmap">
{ "imports": { "appwrite": "./appwrite-sdk.mjs" } }
</script>
<script type="module" src="app.js"></script>
```

```js
// app.js
import { Client, Account, TablesDB, Storage, Functions, Messaging, ID, Query, Permission, Role } from "appwrite";
```

## Exports available (verified in the 26.2.0 bundle)

`Account, TablesDB, Databases, Storage, Functions, Messaging, Teams, Avatars,
Locale, Graphql, Realtime, ID, Query, Permission, Role, OAuthProvider,
AppwriteException, Browser, BrowserPermission, BrowserTheme, Channel, …`

- **`TablesDB`** is the service for TablesDB rows (not `Databases`, which is the
  legacy documents API). Use `TablesDB` on 1.9.x.

## Method signatures (26.2.0) — dual positional + object

Most methods accept either positional args or a single options object:

```js
functions.createExecution(functionId, body, async, path, method)
// or
functions.createExecution({ functionId, body, async, xpath: path, method, headers, scheduledAt })
```

Note the object form uses **`xpath`** (not `path`) for the path arg.

Key methods used by a demo site:

| Service | Methods |
|---|---|
| Account | `get()`, `create(userId, email, password)`, `createEmailPasswordSession(email, password)`, `deleteSession("current")`, `createPushTarget(targetId, identifier, providerId)` |
| TablesDB | `createRow(databaseId, tableId, rowId, data, permissions)`, `listRows(databaseId, tableId, queries)` |
| Storage | `createFile(bucketId, fileId, file, permissions)`, `listFiles(bucketId, queries)` |
| Functions | `createExecution(functionId, body, async, path, method)` |
| Messaging | `createSubscriber(topicId, subscriberId, targetId)`, `deleteSubscriber` |

## Gotchas

- **`createExecution` returns `responseBody`** in 1.9.x (not `response`):
  `const raw = exec.responseBody ?? exec.response ?? "";`
- **No client `Messaging.listMessages`** — listing messages is server-only. The
  client `Messaging` class has `createSubscriber` / `deleteSubscriber` / `list`
  / `create` / `update` / `upsert` / `delete` / `createFile` / `listFiles`.
  Drafts created server-side by a function are viewable in the console.
- **`createPushTarget` needs an FCM/APNs provider** to be useful (none on this
  server). Subscribe-to-topic will fail without a push provider — fine; drafts
  are still created server-side by the function.
- **Register a web platform** (`project create-web-platform --hostname <site-host>`)
  so Appwrite recognizes the site origin for client SDK calls.
- **No secrets in the site.** The site uses per-user sessions (Account), not an
  API key. `config.js` carries only the public endpoint + project + resource IDs
  (commit it; it's not secret).

## Verifying SDK method existence

```bash
# fetch the ESM bundle the site will use and grep for a method name
grep -o 'createExecution\|listRows\|listMessages\|createEmailPasswordSession' site/appwrite-sdk.mjs | sort -u
```
