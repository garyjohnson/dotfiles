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

A handful of small utilities symlinked individually (not the whole directory). Cross-platform: `until-fail`, `until-success`. macOS-only: `allow-exec`, `iterm-open`, `headless`. Typo/alias symlinks: `gti` → git, `vi`/`vim` → nvim. Ask before touching anything else in .local — most of it is legacy.

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

## The vibe

Setup scripts are intentionally cute (pink/lavender/sparkle output). That's on purpose, keep it that way. Changes should be idempotent — running a script twice should be safe and skip what's already done.
