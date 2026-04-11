# dotfiles

This is my repo for first-time machine setup. It contains the scripts and files necessary for me to get my machines up and running for the first time, work and personal.

## Environment

macOS
(customizations in .macos)
Additionally I need list view to to be the default view in finder.

Homebrew should be installed to ~/homebrew because many of my systems are multi-user. Can we source it in .zshrc in a way that will be durable across different environments (given unique home folders)?

* Customizations in ~/.zshrc (in dotfiles)
* Machine-specific customizations and env vars in ~/.profile-env (sourced by .zshrc, not in dotfiles)

## Terminal apps

* neovim with AstroNvim (config in dotfiles)
* lua (nvim)
* zsh
* tmux (config in dotfiles)
* oh-my-posh (terminal prompt, custom theme in dotfiles)
* ripgrep (search)
* fzf (search)
* ack (search)
* tree (dir listings)
* zoxide (quick dir switching)

## Development

* node (nodenv)
* ruby (rbenv)
* postgres
* go

## AI

* claude code
* openai codex

## macOS Applications

* iTerm2 (pointed to config folder in dotfiles)
* Tailscale
* Magnet (App Store)
* VoiceInk (license file to activate)
* Cap (configured to my local server at https://cap.app.usefulbits.io)
* Fastmail
* Obsidian
* Google Chrome (secondary)
* Slack
* Notion
* 1Password

## PWAs

* https://trilium-gary.app.usefulbits.io/ added to dock from Safari

## .local

Much of this is not relevant anymore, so ask before doing anything here. The things I care about:
* allow-exec
* until-fail
* until-success
* iterm-open
* gti (should be symlinked to homebrewed git)
* vi (should be symlinked to homebrewed nvim)
* vim (should be symlinked to homebrewed nvim)
