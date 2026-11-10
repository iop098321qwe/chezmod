#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temp_root="${TMPDIR:-/tmp/opencode}"
[ -d "$temp_root" ] || temp_root=/tmp
scratch="$(mktemp -d "$temp_root/chezmod-chra.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

# Never use the user's Git configuration, identity, network, or dotfiles.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
source "$repo_root/cbc-module.sh"

chezmoi() {
  case "$1" in
    source-path) printf '%s\n' "$fixture_source" ;;
    managed) printf '%s/dot_config\n' "$fixture_source" ;;
    diff) printf '%s' "$diff_text" ;;
    execute-template) echo testhost ;;
    re-add) echo re-add >> "$calls" ;;
    *) echo "Unexpected chezmoi command: $*" >&2; return 1 ;;
  esac
}

gum() {
  case "$1" in
    spin)
      shift
      while [ "$1" != -- ]; do shift; done
      shift
      "$@"
      ;;
    confirm)
      [ "$2" = --default=false ] || return 99
      printf '%s\n' "$3" >> "$prompts"
      case "$3" in
        'Remote changes'*) return "$sync_response" ;;
        *) return "$final_response" ;;
      esac
      ;;
    *) return 99 ;;
  esac
}

delta() { cat; }
bat() { cat; }

fixture() {
  case_dir="$scratch/$1"
  mkdir -p "$case_dir"
  export HOME="$case_dir/home"
  mkdir -p "$HOME/.config/hypr"
  echo 'local monitor' > "$HOME/.config/hypr/monitors.conf"
  source_dir="$case_dir/source"
  calls="$case_dir/calls"
  prompts="$case_dir/prompts"
  : > "$calls"
  : > "$prompts"
  sync_response=1
  final_response=0
  diff_text='example reverse diff'
  git init -q --bare --initial-branch=shared "$case_dir/remote"
  git clone -q "$case_dir/remote" "$case_dir/other" 2>/dev/null
  echo base > "$case_dir/other/config"
  git -C "$case_dir/other" add config
  git -C "$case_dir/other" commit -qm base
  git -C "$case_dir/other" push -q origin shared
  git clone -q --origin peer "$case_dir/remote" "$source_dir"
  mkdir -p "$source_dir/.chezmoitemplates/hypr/monitors"
  echo original > "$source_dir/.chezmoitemplates/hypr/monitors/testhost.conf"
  git -C "$source_dir" add .chezmoitemplates
  git -C "$source_dir" commit -qm template
  git -C "$source_dir" push -q peer shared
  git -C "$case_dir/other" pull -q --ff-only
  # All calls originate outside the chezmoi repository.
  cd "$case_dir"
}

incoming() {
  echo incoming > "$case_dir/other/incoming"
  git -C "$case_dir/other" add incoming
  git -C "$case_dir/other" commit -qm incoming
  git -C "$case_dir/other" push -q origin shared
}

local_commit() {
  echo local > "$source_dir/local"
  git -C "$source_dir" add local
  git -C "$source_dir" commit -qm local
}

run_chra() {
  result=0
  fixture_source="$source_dir"
  chra > "$case_dir/output" 2>&1 || result=$?
}

contains() { grep -Fq -- "$2" "$1"; }

unchanged() {
  [ ! -s "$calls" ]
  [ "$(cat "$source_dir/.chezmoitemplates/hypr/monitors/testhost.conf")" = original ]
}

completed() {
  [ "$result" -eq 0 ]
  contains "$calls" re-add
  [ "$(cat "$source_dir/.chezmoitemplates/hypr/monitors/testhost.conf")" = 'local monitor' ]
}

test_equal() {
  fixture equal
  run_chra
  completed
  [ "$(wc -l < "$prompts")" -eq 1 ]
  contains "$case_dir/output" 'does not prove source changes have been applied'
}

test_ahead() {
  fixture ahead
  local_commit
  run_chra
  completed
  [ "$(wc -l < "$prompts")" -eq 1 ]
}

test_behind() {
  fixture behind
  incoming
  run_chra
  [ "$result" -eq 0 ]
  contains "$case_dir/output" 'behind its upstream by 1'
  # The remote-tracking ref was stale before chra fetched it.
  contains "$prompts" 'Remote changes'
  unchanged
}

test_diverged() {
  fixture diverged
  incoming
  local_commit
  run_chra
  contains "$case_dir/output" 'diverged: 1 local and 1 incoming'
  unchanged
}

test_fetch_failure() {
  fixture fetch-failure
  git -C "$source_dir" remote set-url peer "$case_dir/missing"
  run_chra
  contains "$case_dir/output" 'Fetching the chezmoi upstream failed'
  unchanged
}

test_no_upstream() {
  fixture no-upstream
  git -C "$source_dir" branch --unset-upstream
  run_chra
  contains "$case_dir/output" 'no configured upstream'
  unchanged
}

test_missing_git() {
  fixture missing-git
  command() {
    if [ "${1:-}" = -v ] && [ "${2:-}" = git ]; then return 1; fi
    builtin command "$@"
  }
  run_chra
  contains "$case_dir/output" 'Git is unavailable'
  unchanged
}

test_detached() {
  fixture detached
  git -C "$source_dir" checkout -q --detach
  run_chra
  contains "$case_dir/output" 'detached HEAD'
  unchanged
}

test_non_git() {
  fixture non-git
  source_dir="$case_dir/plain"
  mkdir -p "$source_dir/.chezmoitemplates/hypr/monitors"
  echo original > "$source_dir/.chezmoitemplates/hypr/monitors/testhost.conf"
  run_chra
  contains "$case_dir/output" 'not a Git worktree'
  unchanged
}

test_conflicts() {
  fixture conflicts
  echo incoming > "$case_dir/other/config"
  git -C "$case_dir/other" commit -qam incoming
  git -C "$case_dir/other" push -q origin shared
  echo local > "$source_dir/config"
  git -C "$source_dir" commit -qam local
  git -C "$source_dir" fetch -q peer
  if git -C "$source_dir" merge peer/shared > /dev/null 2>&1; then
    echo 'Expected a merge conflict' >&2
    exit 1
  fi
  sync_response=0
  run_chra
  [ "$result" -eq 1 ]
  contains "$case_dir/output" 'resolve the chezmoi repository'
  [ ! -s "$prompts" ]
  unchanged
}

test_dirty() {
  fixture dirty
  echo staged > "$source_dir/staged"
  git -C "$source_dir" add staged
  echo unstaged >> "$source_dir/config"
  echo untracked > "$source_dir/untracked"
  run_chra
  completed
  contains "$source_dir/config" unstaged
  [ -f "$source_dir/untracked" ]
  git -C "$source_dir" diff --cached --name-only | grep -qx staged
}

test_override() {
  fixture override
  incoming
  sync_response=0
  run_chra
  completed
  [ "$(wc -l < "$prompts")" -eq 2 ]
  contains "$case_dir/output" 'Previewing changes'
}

test_unavailable_confirmation() {
  fixture unavailable
  incoming
  sync_response=2
  run_chra
  unchanged
}

test_final_cancel() {
  fixture final-cancel
  incoming
  sync_response=0
  final_response=1
  run_chra
  unchanged
}

test_final_unavailable() {
  fixture final-unavailable
  final_response=2
  run_chra
  unchanged
}

test_override_unknown() {
  fixture override-unknown
  git -C "$source_dir" branch --unset-upstream
  sync_response=0
  run_chra
  completed
  contains "$case_dir/output" 'no configured upstream'
  [ "$(wc -l < "$prompts")" -eq 2 ]
}

test_no_diff() {
  fixture no-diff
  diff_text=''
  run_chra
  completed
  contains "$prompts" 'No changes detected'
}

for test in equal ahead behind diverged fetch_failure no_upstream missing_git \
  detached non_git conflicts dirty override unavailable_confirmation final_cancel \
  final_unavailable override_unknown no_diff; do
  ( "test_$test" )
  printf 'PASS %s\n' "$test"
done
