#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}

# Function to handle exclusion arguments for rsync
build_exclude_args() {
  local exclude_args=('--exclude=.git')
  if [ -n "$RSYNC_EXCLUDE" ]; then
    IFS=',' read -ra EXCLUDES <<< "$RSYNC_EXCLUDE"
    for exclude in "${EXCLUDES[@]}"; do
      exclude_args+=("--exclude=$exclude")
    done
  fi
  echo "${exclude_args[@]}"
}

# Function to handle syncing, committing, and pushing for a given repository
handle_sync() {
  local repo_name="$1"
  local src_dir="/repos/mount/$repo_name"
  local work_dir="/repos/serve/$repo_name"
  local bare_repo_dir="/repos/git/$repo_name.git"
  local exclude_args
  exclude_args=$(build_exclude_args)

  cd "$work_dir" || return

  # Check if remote 'origin' exists, add if not
  if ! git remote | grep -q origin; then
    git remote add origin "file://$bare_repo_dir"
  fi

  # Fetch changes from the bare repository
  git fetch origin

  # Reset to the latest state of 'origin/main'
  git reset --hard origin/main

  # Sync the current state
  rsync -av --delete "${exclude_args[@]}" "$src_dir/" "$work_dir/"

  # Stage changes
  git add .

  # Check if there are any changes to commit
  if ! git diff-index --quiet HEAD --; then
    # Commit and rebase with the latest changes
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Autocommit: $timestamp"
    git pull --rebase origin main
    git push origin main
  fi
}

# Monitor for changes and handle them as they occur
while inotifywait -r -e modify,create,delete,move /repos/mount; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    handle_sync "$repo_name"
  done
done
