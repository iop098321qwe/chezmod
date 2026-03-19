# Chezmod

Helpers for managing a chezmoi dotfiles repo with gum-driven prompts.
Covers apply, diff preview, add or forget flows, and update or re-add actions.

## Functions
- `chd`: Open the chezmoi source directory in yazi.
- `chad`: Add files to chezmoi with optional interactive selection.
- `chfo`: Forget managed files from chezmoi with optional selection.
- `chra`: Preview reverse diff and run `chezmoi re-add`.
- `chup`: Preview pending diff and run `chezmoi update` after confirmation.

## Aliases
- `ch`: Run `chezmoi`.
- `chap`: Confirm and run `chezmoi apply`.
- `chdiff`: Show reverse diff (excluding scripts) through delta.
