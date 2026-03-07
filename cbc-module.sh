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

function chfo() {
  for cmd in chezmoi gum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: missing $cmd"; return 1; }
  done

  if [ "$#" -gt 0 ]; then
    gum confirm "Forget file(s) with 'chezmoi forget'?" || {
      echo "Canceled. No files forgotten."
      return 0
    }

    chezmoi forget --force -- "$@"
    return $?
  fi

  local current_dir
  current_dir="${PWD%/}"
  if [ -z "$current_dir" ]; then
    current_dir="/"
  fi

  local path_prefix
  if [ "$current_dir" = "/" ]; then
    path_prefix="/"
  else
    path_prefix="$current_dir/"
  fi

  local managed_output
  if ! managed_output="$(chezmoi managed --path-style=absolute --include=files "$current_dir")"; then
    echo "Error: failed to list managed files."
    return 1
  fi

  local -a options=()
  local entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [[ "$entry" == "$path_prefix"* ]]; then
      options+=("${entry#"$path_prefix"}")
    fi
  done <<< "$managed_output"

  if [ "${#options[@]}" -eq 0 ]; then
    echo "No managed files found."
    return 0
  fi

  local selected
  if ! selected="$(printf '%s\n' "${options[@]}" | gum filter --no-limit \
    --header "Select managed files to forget" \
    --placeholder "Filter...")"; then
    echo "Canceled. No files forgotten."
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

  gum confirm "Forget selected item(s) with 'chezmoi forget'?" || {
    echo "Canceled. No files forgotten."
    return 0
  }

  local -a selected_paths=()
  local item
  for item in "${selected_items[@]}"; do
    selected_paths+=("$path_prefix$item")
  done

  chezmoi forget --force -- "${selected_paths[@]}"
}

function chra() {
  for cmd in chezmoi gum delta bat; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: missing $cmd"; return 1; }
  done

  local source_dir
  if ! source_dir="$(chezmoi source-path)"; then
    echo "Error: failed to determine chezmoi source path."
    return 1
  fi

  local changelog_source
  changelog_source="$source_dir/CHANGELOG.md"

  local managed_output
  if ! managed_output="$(chezmoi managed --path-style=source-absolute --exclude=scripts)"; then
    echo "Error: failed to list managed files."
    return 1
  fi

  local -a diff_targets=()
  local managed_entry
  while IFS= read -r managed_entry; do
    [ -z "$managed_entry" ] && continue
    [ "$managed_entry" = "$changelog_source" ] && continue
    diff_targets+=("$managed_entry")
  done <<< "$managed_output"

  echo "Previewing changes (reverse diff; scripts excluded):"
  echo "---------------------------------------------------"

  if [ "${#diff_targets[@]}" -eq 0 ]; then
    echo "No file changes detected (with current diff filters)."
    return 0
  fi

  local diff_output
  if ! diff_output="$(chezmoi diff --reverse -x scripts --source-path --no-pager -- "${diff_targets[@]}")"; then
    echo "Error: diff preview command failed."
    return 1
  fi

  if [ -z "$diff_output" ]; then
    echo "No file changes detected (with current diff filters)."
    return 0
  fi

  # chezmoi diff --reverse -x scripts --no-pager | delta | bat || {
  printf '%s\n' "$diff_output" | delta || {
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

  local source_dir
  if ! source_dir="$(chezmoi source-path)"; then
    echo "Error: failed to determine chezmoi source path."
    return 1
  fi

  local changelog_source
  changelog_source="$source_dir/CHANGELOG.md"

  local managed_output
  if ! managed_output="$(chezmoi managed --path-style=source-absolute --exclude=scripts)"; then
    echo "Error: failed to list managed files."
    return 1
  fi

  local -a diff_targets=()
  local managed_entry
  while IFS= read -r managed_entry; do
    [ -z "$managed_entry" ] && continue
    [ "$managed_entry" = "$changelog_source" ] && continue
    diff_targets+=("$managed_entry")
  done <<< "$managed_output"

  echo "Previewing pending chezmoi changes before update:"
  echo "---------------------------------------------------"

  # --- Skip preview if nothing is pending ---
  if [ "${#diff_targets[@]}" -eq 0 ]; then
    echo "No local changes currently pending."
    return 0
  fi

  local diff_output
  if ! diff_output="$(chezmoi diff -x scripts --source-path --no-pager -- "${diff_targets[@]}")"; then
    echo "Error: diff preview pipeline failed."
    return 1
  fi

  if [ -z "$diff_output" ]; then
    echo "No local changes currently pending."
  else
    if ! printf '%s\n' "$diff_output" | delta; then
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
