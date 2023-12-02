#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}
RSYNC_PROTECT=${RSYNC_PROTECT:-}

declare exclude_arg_str='--exclude=.git'
declare protect_arg_str='--filter="P .git"'

# Build exclusion argument string
build_exclude_args() {
  if [[ -n "$RSYNC_EXCLUDE" ]]; then
    IFS=',' read -ra EXCLUDES <<< "$RSYNC_EXCLUDE"
    for exclude in "${EXCLUDES[@]}"; do
      [[ -n "$exclude" ]] && exclude_arg_str+=" --exclude=$exclude"
    done
  fi
}

# Build protection argument string
build_protect_args() {
  if [[ -n "$RSYNC_PROTECT" ]]; then
    IFS=',' read -ra PROTECTS <<< "$RSYNC_PROTECT"
    for protect in "${PROTECTS[@]}"; do
      if [[ -n "$protect" ]]; then
        protect_arg_str+=" --filter=\"P $protect\""
      fi
    done
  fi
}

# Function to handle syncing for a given repository
handle_sync() {
  local repo_name="$1"
  local src_dir="/repos/mount/$repo_name"
  local work_dir="/repos/serve/$repo_name"

  # Execute the rsync command with specific info level
  eval "rsync -a --delete --info=flist0,name $exclude_arg_str $protect_arg_str $src_dir/ $work_dir/"
}

# Perform Git operations in a separate function for clarity
handle_git_operations() {
  local work_dir="$1"
  cd "$work_dir" || return

  git add .

  if ! git diff --quiet --cached; then
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Autocommit: $timestamp"
    git pull --rebase origin main
    git push origin main
  fi
}

# Main execution
build_exclude_args
build_protect_args

while true; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    
    handle_sync "$repo_name"
    handle_git_operations "/repos/serve/$repo_name"
  done
  sleep 1
done