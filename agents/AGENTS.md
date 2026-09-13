# dotfiles

Machine setup scripts for macOS and Debian. One command per platform to install everything, symlink configs, and print what's left to do manually.

## Scripts

- **`setup-dev-macos.sh`** — Full macOS dev setup: Homebrew, Brewfile, dotfile symlinks, nodenv, rbenv, Claude Code, SSH/GitHub, VPN, macOS defaults, iTerm2
- **`setup-dev-debian.sh`** — Headless Debian dev setup: apt bootstrap, Linuxbrew, Brewfile, dotfile symlinks, nodenv, rbenv, Claude Code, npm globals (codex, pi, firecrawl-cli), skills, SSH/GitHub
- **`setup-llm-server-macos-headless.sh`** — Apple Silicon LLM server setup: GPU memory split, sleep prevention, SSH, auto-login, LM Studio, dock config

The Brewfile is the source of truth for brew packages — shared across platforms with `OS.mac?` guards for Mac-only casks.

## How it works

Run the appropriate script on a fresh machine. It installs dependencies, symlinks dotfiles into `$HOME`, sets up dev toolchains (node via nodenv, ruby via rbenv), configures SSH/GitHub, and prints manual steps at the end.

## Key design decisions

**Homebrew path differs by platform.** On macOS it lives at `~/homebrew` (intentional — multi-user safe, everything under `$HOME`). On Linux it's at `/home/linuxbrew/.linuxbrew` (standard Linuxbrew location). The `.zshrc` detects platform via `$OSTYPE` and sources the right one.

**Machine-specific config goes in `~/.profile-env`**, which is sourced by .zshrc but not checked into this repo. Git identity, API keys, machine-specific env vars live there. Scripts gracefully skip if it doesn't exist.

**Configs in this repo are symlinked, not copied.** Changes to .zshrc, .gitconfig, .tmux.conf, nvim config, oh-my-posh themes are symlinked from the dotfiles dir into `$HOME`. Edit them here.

**1Password gets special treatment on Mac** — it must live in `/Applications` (not `~/Applications`) because it's picky about that.

## What's in .local/bin

A handful of small utilities symlinked individually (not the whole directory). Cross-platform: `until-fail`, `until-success`, `sync-deepinfra-langfuse.sh`. macOS-only: `allow-exec`, `iterm-open`, `headless`. Typo/alias symlinks: `gti` → git, `vi`/`vim` → nvim. Ask before touching anything else in .local — most of it is legacy.

`sync-deepinfra-langfuse.sh` pulls model token pricing from DeepInfra's `GET /models/list` for the models you've actually used (via `GET /payment/usage`) and upserts them as custom Langfuse model definitions (`unit=TOKENS`, with a `cache_read_input_tokens` price) through the public API. Idempotent; dry-run with `--dry-run`, sync all with `--all`. Needs `DEEPINFRA_API_KEY` + `LANGFUSE_BASE_URL/PUBLIC_KEY/SECRET_KEY` (sourced from `~/.profile-env` if unset). See `README-sync-deepinfra-langfuse.md`.

## Tea CLI for Forgejo

[tea](https://gitea.com/gitea/tea) is the command-line tool for interacting with Forgejo (Gitea-compatible) repos — issues, PRs, releases, labels, milestones, and more. Think of it as `gh` but for Forgejo.

Installed via the Brewfile alongside `gh`. After `brew bundle`, run `tea login add` to authenticate against `https://forgejo.app.usefulbits.io`. The setup scripts handle this interactively on first run.

Common commands:

- `tea login list` — show configured logins
- `tea issues` — list repo issues (from `$PWD` context)
- `tea pulls` — list / create pull requests
- `tea releases` — create / list releases
- `tea repos` — show repo details
- `tea open` — open the repo in a browser

Note: `tea` is **not** the same as the Debian `tea` apt package (a GUI text editor). The Debian setup script intentionally omits the apt `tea` package — the real CLI comes from Homebrew.

## Agent-utility CLIs

Two command-line tools on this machine for web search, scraping, and extraction. Both are agent-friendly (JSON/structured output). Available to **pi** (via `bash`); **not** available to Claude Code.

**`kagi`** — Kagi search CLI, JSON-first output built for agents. Installed via Homebrew (`kagi/0.9.0`), **not in the Brewfile**. Use this instead of scraping Google/DDG or distributor sites directly — those block naive scraping (Cloudflare/bot walls); Kagi does not.

- `kagi search "<query>" --format json` — structured results (title, url, snippet). Other formats: `markdown`, `csv`, `pretty`, `compact`.
- `kagi summarize <url>` / `kagi extract <url>` — summarize a page, or extract full content as markdown
- `kagi quick "<q>"` / `kagi fastgpt "<prompt>"` — Quick Answer / FastGPT
- `kagi assistant` / `kagi ask-page <url>` — Assistant + page Q&A
- `kagi mcp` — run a stdio MCP server exposing Kagi tools
- Also: `news`, `enrich`, `smallweb`, `watch`, `translate`, `notify`, `history`, `site-pref`

**`firecrawl`** — Firecrawl CLI (`firecrawl-cli`, npm global, v1.23.2). Scrape, crawl, map, parse, and search the web with an AI extraction agent. Complements Kagi (search/summarize) with deep page fetching, JS-heavy site renders, full-site crawls, and structured AI extraction.

- `firecrawl scrape <url...>` — scrape URLs concurrently, saved to `.firecrawl/`
- `firecrawl crawl <url>` / `firecrawl map <url>` — full-site crawl / map URLs
- `firecrawl search "<query>"` — web search
- `firecrawl developer "<query>"` — search a coding-agent index (GitHub issues/PRs, repo READMEs, curated docs); express repo/source/language/topic scope in the query text
- `firecrawl research "<query>"` — search ~43M research-paper abstracts (PubMed, bioRxiv, medRxiv, arXiv) + GitHub history; use for biomedical/scientific literature instead of scraping PubMed/Scholar
- `firecrawl parse <file>` — local file (HTML/PDF/DOCX/XLSX…) → markdown/JSON/links
- `firecrawl agent "<prompt>"` / `firecrawl interact` — AI extraction agent / live-browser session against a prior scrape
- `firecrawl --status` / `firecrawl login` — check auth+credits / authenticate

Rule of thumb: **Kagi for search & summaries, Firecrawl for full pages, crawls, parsing, and structured extraction.**

**`trilium`** — TriliumNext CLI (`triliumnext-cli`, single binary). Push/pull notes to the local TriliumNext instance. Use this **explicitly when asked to retrieve notes or save notes** (not for web search/scraping). The setup scripts build it from source with Bun (the upstream `darwin-arm64` prebuilt binary is broken — corrupt code signature + dyld chained-fixups — so macOS SIGKILLs it).

- `trilium auth login --server <url>` — interactive login; stores the ETAPI token in `~/.config/triliumnext-cli/config.json`
- `trilium notes search "<query>"` — search notes; `--limit`, `--order-by`
- `trilium notes get <noteId>` / `get-content <noteId>` — fetch a note / its content
- `trilium notes create --title "..." --content "..." --markdown` — save a new note
- `echo "# note" | trilium notes create --title "..." --markdown` — pipe markdown straight in
- `trilium notes set-content <noteId> --content "..." --markdown` — update existing note content
- `--format json` for machine-readable output (pipe to `jq`)

## The vibe

Setup scripts are intentionally cute (pink/lavender/sparkle output). That's on purpose, keep it that way. Changes should be idempotent — running a script twice should be safe and skip what's already done.
