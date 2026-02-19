#!/usr/bin/env bash

# chezmoi aliases
alias ch='chezmoi'
alias chap='gum confirm "Run chezmoi apply?" && chezmoi apply'
alias chd='chezmoi cd'
alias chdiff='chezmoi diff --reverse -x scripts --no-pager | delta'


function chad() {
  for cmd in chezmoi gum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: missing $cmd"; return 1; }
  done

  if [ "$#" -gt 0 ]; then
    gum confirm "Add file(s) with 'chezmoi add'?" || {
      echo "Canceled. No files added."
      return 0
    }

    chezmoi add "$@"
    return $?
  fi

  local globstar_set
  local nullglob_set
  local dotglob_set

  shopt -q globstar; globstar_set=$?
  shopt -q nullglob; nullglob_set=$?
  shopt -q dotglob; dotglob_set=$?

  shopt -s globstar nullglob dotglob

  local -a options=()
  local entry
  for entry in **/*; do
    if [[ "$entry" == ".git" || "$entry" == ".git/"* || "$entry" == */.git || "$entry" == */.git/* ]]; then
      continue
    fi
    options+=("$entry")
  done

  if [ "$globstar_set" -ne 0 ]; then
    shopt -u globstar
  fi
  if [ "$nullglob_set" -ne 0 ]; then
    shopt -u nullglob
  fi
  if [ "$dotglob_set" -ne 0 ]; then
    shopt -u dotglob
  fi

  if [ "${#options[@]}" -eq 0 ]; then
    echo "No files found."
    return 0
  fi

  local selected
  if ! selected="$(printf '%s\n' "${options[@]}" | gum filter --no-limit \
    --header "Select files or directories" \
    --placeholder "Filter...")"; then
    echo "Canceled. No files added."
    return 0
  fi

  if [ -z "$selected" ]; then
    echo "No files selected."
    return 0
  fi

  local -a selected_items=()
  mapfile -t selected_items <<< "$selected"

  if ! printf '%s\n' "Selected items:" "" "${selected_items[@]}" | gum pager --soft-wrap; then
    echo "Error: preview failed."
    return 1
  fi

  gum confirm "Add selected item(s) with 'chezmoi add'?" || {
    echo "Canceled. No files added."
    return 0
  }

  chezmoi add -- "${selected_items[@]}"
}


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
