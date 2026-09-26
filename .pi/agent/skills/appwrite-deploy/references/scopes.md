# Appwrite 1.9.x API key scopes

Scope names are dot notation. Pass them to `functions create/update --scopes`,
`organization create-key --scopes`, and when creating a project API key in the
console. An **invalid scope name** → HTTP 400, so get these right.

Source: https://appwrite.io/docs/partners/project/api-keys.md (request as `.md`).

## Scopes you'll commonly need

### VCS (GitHub) — critical for VCS wiring
- `vcs.read` — read VCS repositories / installations
- `vcs.write` — create/update/delete VCS repositories

### Functions
- `functions.read`, `functions.write`
- `execution.read` — read execution logs
- `execution.write` — execute functions

### Sites
- `sites.read`, `sites.write`
- `log.read`, `log.write` — site logs

### Databases / TablesDB (1.9.x)
- `databases.read`, `databases.write` — database containers
- `tables.read`, `tables.write` — tables
- `columns.read`, `columns.write` — table columns
- `indexes.read`, `indexes.write` — table indexes
- `rows.read`, `rows.write` — rows

> ⚠️ There is **no `messaging.read/write`**. Messaging is split (below).

### Messaging (1.9.x — split scopes)
- `messages.read`, `messages.write`
- `topics.read`, `topics.write`
- `subscribers.read`, `subscribers.write`
- `targets.read`, `targets.write`
- `providers.read`, `providers.write`

### Storage
- `files.read`, `files.write`
- `buckets.read`, `buckets.write`

### Users / Teams / Sessions
- `users.read`, `users.write`
- `teams.read`, `teams.write`
- `sessions.read`, `sessions.write`

### Project / keys
- `project.read`, `project.write`
- `keys.read`, `keys.write` — sensitive; needed to list/create project API keys
- `platforms.read`, `platforms.write`

### Other (less common)
- `locale.read`, `avatars.read`, `health.read`
- `migrations.read`, `migrations.write`
- `tokens.read`, `tokens.write`
- `webhooks.read`, `webhooks.write`
- `rules.read`, `rules.write` — proxy rules
- `assistant.read`
- `mocks.read`, `mocks.write`
- `policies.*` (password-strength, session, user-limit, etc.) — see the full table in the docs

## Bootstrap-key gotcha

The **first** project API key must be created in the console (Settings → API
Keys): CLI v27 removed `project create-key`, and user sessions lack
`keys.write`/`vcs.read`. For a new project, select at minimum:

```
vcs.read
functions.read functions.write
sites.read sites.write
databases.read databases.write tables.read tables.write columns.read columns.write rows.read rows.write
files.read files.write buckets.read buckets.write
users.read users.write
messages.read messages.write topics.read topics.write subscribers.read subscribers.write targets.read targets.write
keys.read keys.write   # optional, but handy for minting further keys via API
```

Store it in `~/.profile-env` as `APPWRITE_API_KEY`, reload, and point the CLI:
`appwrite client --endpoint … --project-id … --key "$APPWRITE_API_KEY"`.
