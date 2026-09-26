# VCS / GitHub App connection (Appwrite 1.9.x)

How GitHub-connected (auto) deployments are wired on this self-hosted server.

## Key facts

- **VCS installations are project-scoped.** The GitHub App installed for project
  A is **not** visible to project B. `GET /vcs/installations` returns 0 for a
  new project until it has been connected in the console.
- **There is no public REST endpoint to initiate the GitHub OAuth connect.**
  The server has `VCS/Http/GitHub/Authorize/Get.php` (responds with a redirect
  URL), but triggering it is a browser/console flow. You **cannot** script the
  initial connect from the CLI/API.
- Once connected, the installation **persists** even if you cancel the create
  dialog. So the connect is a one-time click per project.

## The one human step (per new project)

1. Appwrite console → switch to the **target project**.
2. Functions (or Sites) → **Create** → **Connect to Git / GitHub**.
3. The Appwrite GitHub App is already installed on your `garyjohnson` GitHub
   account, so it links with **one click** (no re-auth).
4. **Cancel** out of the function/site creation dialog. The installation
   record stays.

Then continue from the CLI.

## Confirm + discover via API (project key needs `vcs.read`)

```bash
set -a; source ~/.profile-env; set +a
python3 -c "
import os,urllib.request,json
ep=os.environ['APPWRITE_API_ENDPOINT']; key=os.environ['APPWRITE_API_KEY']; proj='<PROJECT_ID>'
r=urllib.request.Request(ep+'/vcs/installations')
r.add_header('X-Appwrite-Key',key); r.add_header('X-Appwrite-Project',proj); r.add_header('X-Appwrite-Response-Format','1.9.0')
d=json.load(urllib.request.urlopen(r,timeout=15))
print('installations:',[(i['\$id'],i['organization'],i['providerInstallationId']) for i in d['installations']])
"
```

`$id` here is the Appwrite **installation id** (use as `--installation-id`).
`providerInstallationId` is GitHub's numeric installation id (not needed for wiring).

## Get `providerRepositoryId`

`providerRepositoryId` is **GitHub's numeric repo id**, not the name:

```bash
REPO_NUM=$(gh api repos/garyjohnson/<repo> --jq .id)   # e.g. 1336611947
```

You can also list repos visible to the installation (the route is **not**
`/repositories`; the `type` query param is **required** and must be
`runtime` or `framework`):

```
GET /v1/vcs/github/installations/{installationId}/providerRepositories?type=runtime&search={name}
```

Response key is `runtimeProviderRepositories` (for `type=runtime`) or
`frameworkProviderRepositories` (for `type=framework`). Each item's `id` =
the GitHub numeric repo id = `providerRepositoryId`.

## Wire function + site to GitHub

Both `update` commands **require** the full set of required flags (`--name`,
and `--runtime` for functions / `--framework` + `--build-runtime` for sites)
even when only changing VCS fields.

```bash
INSTALL_ID=<Appwrite installation $id from above>
REPO_NUM=$(gh api repos/garyjohnson/<repo> --jq .id)

appwrite functions update --function-id <fn-id> --name "<Fn>" --runtime node-16.0 \
  --entrypoint src/main.js --execute 'users' \
  --scopes 'tables.read' --scopes 'tables.write' --scopes 'rows.read' --scopes 'rows.write' \
  --scopes 'users.read' --scopes 'messages.read' --scopes 'messages.write' \
  --scopes 'files.read' --scopes 'files.write' \
  --installation-id $INSTALL_ID --provider-repository-id $REPO_NUM \
  --provider-branch main --provider-root-directory /functions/<fn-id> --provider-silent-mode

appwrite sites update --site-id <site-id> --name "<Site>" --framework other --adapter static \
  --build-runtime node-22 --output-directory . --install-command "" --build-command "" \
  --installation-id $INSTALL_ID --provider-repository-id $REPO_NUM \
  --provider-branch main --provider-root-directory /site --provider-silent-mode
```

`--provider-root-directory` is the path **within the repo** to the code
(`/functions/<fn-id>`, `/site`). `--provider-silent-mode` stops Appwrite from
commenting on commits/PRs.

## Trigger the first VCS build

```bash
appwrite functions create-vcs-deployment --function-id <fn-id> --type branch --reference main --activate
appwrite sites    create-vcs-deployment --site-id    <site-id> --type branch --reference main --activate
```

Poll until `status == ready` and the resource's `deploymentId` == the new
deployment `$id`.

## Auto-deploy (webhook)

Once wired, **pushing to `main` auto-triggers new deployments** for both the
function and site (GitHub webhook → Appwrite). Observed latency ~6 seconds.
No further CLI action needed for routine deploys — just `git push`.

## Silent mode

`--provider-silent-mode` keeps Appwrite from posting comments on commits/PRs.
Leave it on for demo/internal repos.

## Reference: where the route paths live

The docs reference page (`/docs/references/cloud/server-rest/vcs.md`) is a stub
("No endpoints found"). The real routes are in the Appwrite server source:
`gh api repos/appwrite/appwrite/contents/src/Appwrite/Platform/Modules/VCS/Http/...?ref=1.9.6`.
`XList.php` files carry the `list*` routes (the `X` prefix is Appwrite's
convention). Useful when a route name is unknown.
