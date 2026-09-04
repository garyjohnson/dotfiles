# osxphotos → SMB backup

Backs up an Apple Photos library to an SMB share using [osxphotos](https://github.com/RhetTbull/osxphotos). Idempotent — re-running the setup script updates the installed sync script, launchd plist, and credentials file in place.

## Files

| File | Purpose |
|---|---|
| `setup-osxphotos-smb.sh` | One-shot / repeatable setup. Prompts once for the SMB username + password and writes them to a local owner-only creds file (`~/.config/osxphotos-backup/smb.conf`, chmod 600). |
| `sync-osxphotos-backup.sh.template` | The actual sync script, rendered with your config values. Runs the osxphotos export. |
| `com.garyjohnson.osxphotos-backup.plist.template` | launchd LaunchAgent plist, rendered to `~/Library/LaunchAgents/`. |

## What it does on each sync run

1. Verifies the Photos library exists and has a `Photos.sqlite` database.
2. Mounts the SMB share (skips if already mounted; password read from the local creds file — no keychain, no unlock).
3. Runs `osxphotos export` with:
   - `--update` + `--overwrite` — only exports new/changed assets, never re-exports unchanged ones (incremental).
   - `--sidecar xmp` — writes XMP sidecars (metadata for Immich/other indexers).
   - `--download-missing` — pulls iCloud-only originals down first.
   - `--exportdb $HOME/osxphotos_state/osxphotos_export.db` — local state DB so partial runs resume cleanly and the flow is genuinely incremental.
   - `--report` — CSV audit trail per day.
4. Leaves the share mounted (reused on the next run) and rotates old logs.

## Config

Edit the `EDITABLE CONFIG` block near the top of `setup-osxphotos-smb.sh`:

- `SERVER` / `SHARE` — SMB host + share name (required).
- `PHOTOS_LIBRARY` — path to the Photos library (defaults to `~/Photos/...`).
- `MOUNT_POINT` / `SUB_DIR` — local mount + export subfolder (defaults to `/Volumes/osxphotos-backup/osxphotos`).
- `SYNC_INTERVAL_SECONDS` — default every 5 hours.

## Run it

```bash
./setup-osxphotos-smb.sh
```

The script installs osxphotos (via pipx), prompts for SMB credentials, renders + installs the sync script and plist, loads the LaunchAgent, and kicks off an immediate first sync. Tail the log with:

```bash
tail -f ~/osxphotos_logs/$(ls -t ~/osxphotos_logs | head -1)
```

## Full Disk Access (required)

osxphotos must read the Photos library database, which is protected by TCC. When run by launchd, grant **Full Disk Access** to the Python binary that osxphotos runs as:

```bash
head -1 "$(which osxphotos)"   # shows the Python shebang path
```

Add that binary under **System Settings → Privacy & Security → Full Disk Access**. (When run manually from Terminal, Terminal's own FDA suffices.)

## Resuming from a prior icloudpd backup?

No clean resume — start fresh in a new directory. osxphotos and icloudpd use different filenames and different export-state tracking, so pointing osxphotos at an existing icloudpd directory causes duplicates rather than a resume. Export to a new folder and keep the old icloudpd dir as a read-only archive until the new backup is confirmed complete.
