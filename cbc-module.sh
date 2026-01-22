#!/usr/bin/env bash

# chezmoi aliases
alias ch='chezmoi'
alias chad='chezmoi add -p'
alias chap='gum confirm "Run chezmoi apply?" && chezmoi apply'
alias chd='chezmoi cd'
alias chdiff='chezmoi diff --reverse -x scripts --no-pager | delta'


function chra() {
  for cmd in chezmoi gum delta bat; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: missing $cmd"; return 1; }
  done

  echo "Previewing changes (reverse diff; scripts excluded):"
  echo "---------------------------------------------------"

  if chezmoi diff --reverse -x scripts --no-pager --quiet >/dev/null 2>&1; then
    echo "No file changes detected (with current diff filters)."
    return 0
  fi

  # chezmoi diff --reverse -x scripts --no-pager | delta | bat || {
  chezmoi diff --reverse -x scripts --no-pager | delta || {
    echo "Error: diff preview command failed."
    return 1
  }

  echo "---------------------------------------------------"

  gum confirm "Apply these changes with 'chezmoi re-add'?" || {
    echo "Canceled. No changes applied."
    return 0
  }

  echo "Running: chezmoi re-add"
  chezmoi re-add
}

function chup() {
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
  if chezmoi diff -x scripts --no-pager --quiet >/dev/null 2>&1; then
    echo "No local changes currently pending."
  else
    if ! chezmoi diff -x scripts --no-pager | delta; then
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
