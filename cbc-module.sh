#!/usr/bin/env bash

# chezmoi aliases
alias ch='chezmoi'
alias chad='chezmoi add'
alias chap='gum confirm "Run chezmoi apply?" && chezmoi apply'
alias chd='chezmoi cd'
alias chra='gum confirm "Run chezmoi re-add?" && chezmoi re-add'
# alias chup='gum confirm "Run chezmoi update?" && chezmoi update'
alias chup='chupp'

function chupp() {
  # --- Dependency checks ---
  for cmd in chezmoi gum delta bat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: required command not found in PATH: $cmd"
      return 1
    fi
  done

  echo "Previewing pending chezmoi changes before update:"
  echo "---------------------------------------------------"

  # --- Skip preview if nothing is pending ---
  if chezmoi diff --reverse -x scripts --no-pager --quiet >/dev/null 2>&1; then
    echo "No local changes currently pending."
  else
    if ! chezmoi diff --reverse -x scripts --no-pager | delta; then
      echo "Error: diff preview pipeline failed."
      return 1
    fi
  fi

  echo "---------------------------------------------------"

  # --- Confirm update ---
  if gum confirm "Run 'chezmoi update'? This may pull new changes and apply them."; then
    echo "Running: chezmoi update"
    chezmoi update
  else
    echo "Canceled. No changes applied."
  fi
}
