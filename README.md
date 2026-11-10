# Chezmod

Helpers for managing a chezmoi dotfiles repo with gum-driven prompts.
Covers apply, diff preview, add or forget flows, and update or re-add actions.

## Functions
- `chd`: Open the chezmoi source directory in yazi.
- `chad`: Add files to chezmoi with optional interactive selection.
- `chfo`: Forget managed files from chezmoi with optional selection.
- `chra`: Check upstream freshness, preview reverse diff, sync the
  host-specific Hypr monitor template when available, and run `chezmoi re-add`.
- `chup`: Preview pending diff and run `chezmoi update` after confirmation.

## Aliases
- `ch`: Run `chezmoi`.
- `chap`: Confirm and run `chezmoi apply`.
- `chdiff`: Show reverse diff (excluding scripts) through delta.

## Cross-machine re-add safety

`chra` checks the Git repository at `chezmoi source-path`, fetching the current
branch's configured upstream remote before comparing commits. It does not
assume a remote or branch name, and never pulls, merges, or applies dotfiles
automatically.

If the branch is behind or diverged, `chra` warns and defaults to cancellation.
The same confirmation is required when freshness cannot be verified, such as
when offline, without Git or an upstream, on a detached HEAD, or using a
non-Git source. You can explicitly continue anyway, then review the usual diff.
Unresolved merge conflicts stop the operation without an override. Ahead-only
branches and ordinary staged, unstaged, or untracked changes remain allowed.

Re-add copies this machine's files back into the source repository. Git being
up-to-date does **not** prove newer source changes have been applied locally;
the diff cannot distinguish intentional edits from stale machine state.
Review and reconcile source and machine changes before proceeding. All
confirmations default to No; declining or unavailable confirmation prevents
both the monitor-template copy and `chezmoi re-add`. Fetching may still update
Git's remote-tracking metadata.

## Tests

Run `npm test` to exercise the guard with temporary local Git repositories and
mocked interactive commands. Tests do not access real dotfiles or the network.
