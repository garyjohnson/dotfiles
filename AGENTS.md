# dotfiles

One-command macOS machine setup. Run `./setup.sh` on a fresh Mac and it installs everything, symlinks configs, and tells you what's left to do manually. Used across both work and personal machines.

## How it works

`setup.sh` is the entry point. It installs Homebrew, runs the `Brewfile`, symlinks dotfiles into `$HOME`, sets up dev toolchains (node via nodenv, ruby via rbenv), configures SSH/GitHub, pulls VPN credentials from 1Password CLI, applies macOS defaults, and prints manual steps at the end.

The Brewfile and setup.sh are the source of truth for what gets installed -- don't duplicate that list here or in docs.

## Key design decisions

**Homebrew lives at `~/homebrew`**, not `/opt/homebrew` or `/usr/local`. This is intentional -- some machines are multi-user, so everything stays under `$HOME`. The .zshrc sources brew via `$HOME/homebrew/bin/brew shellenv` so it works regardless of the username.

**Machine-specific config goes in `~/.profile-env`**, which is sourced by .zshrc but not checked into this repo. Git identity, machine-specific env vars, anything that differs between machines lives there.

**Configs in this repo are symlinked, not copied.** Changes to .zshrc, .gitconfig, .tmux.conf, nvim config, oh-my-posh themes, and iTerm prefs are all symlinked from the dotfiles dir into `$HOME`. Edit them here.

**1Password gets special treatment** -- it must live in `/Applications` (not `~/Applications` like everything else) because it's picky about that.

## What's in .local/bin

A handful of small utilities that get symlinked individually (not the whole directory). The ones that matter: `allow-exec`, `until-fail`, `until-success`, `iterm-open`. There are also typo/alias symlinks: `gti` -> git, `vi`/`vim` -> nvim. Ask before touching anything else in .local -- most of it is legacy.

## The vibe

The setup script is intentionally cute (pink/lavender/sparkle output). That's on purpose, keep it that way. Changes should be idempotent -- running setup.sh twice should be safe and skip what's already done.
