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
    gum confirm "Add file(s) with 'chezmoi add -p'?" || {
      echo "Canceled. No files added."
      return 0
    }

    chezmoi add -p "$@"
    return $?
  fi

  local -a status_lines=()
  mapfile -t status_lines < <(chezmoi status) || {
    echo "Error: failed to read chezmoi status."
    return 1
  }

  if [ "${#status_lines[@]}" -eq 0 ]; then
    echo "No files to add (chezmoi status is clean)."
    return 0
  fi

  local selected
  selected="$(printf '%s\n' "${status_lines[@]}" | gum choose --no-limit --header "Select files to add")" || return 1

  if [ -z "$selected" ]; then
    echo "No files selected."
    return 0
  fi

  local -a selected_files=()
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue

    local path
    if [[ "$entry" == *" "* ]]; then
      path="${entry#* }"
    else
      path="$entry"
    fi

    path="${path#"${path%%[![:space:]]*}"}"

    if [ -n "$path" ]; then
      selected_files+=("$path")
    fi
  done <<< "$selected"

  if [ "${#selected_files[@]}" -eq 0 ]; then
    echo "No files selected."
    return 0
  fi

  gum confirm "Add selected file(s) with 'chezmoi add -p'?" || {
    echo "Canceled. No files added."
    return 0
  }

  chezmoi add -p -- "${selected_files[@]}"
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
