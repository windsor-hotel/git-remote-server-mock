#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}

# Always exclude .git and expand other excludes from RSYNC_EXCLUDE variable
exclude_args=('--exclude=.git')
if [ -n "$RSYNC_EXCLUDE" ]; then
  IFS=',' read -ra EXCLUDES <<< "$RSYNC_EXCLUDE"
  for exclude in "${EXCLUDES[@]}"; do
    exclude_args+=("--exclude=$exclude")
  done
fi

# Function to handle syncing, committing, and pushing for a given repository
handle_sync() {
  repo_name="$1"
  src_dir="/repos/mount/$repo_name"
  work_dir="/repos/serve/$repo_name"
  bare_repo_dir="/repos/git/$repo_name.git"

  cd "$work_dir" || exit

  # Ensure the local repository tracks the remote repository
  git remote add origin "file://$bare_repo_dir" || true
  git fetch origin

  # Reset the local state to match the remote
  git reset --hard origin/main

  # Sync the current state
  rsync -av --delete "${exclude_args[@]}" "$src_dir/" "$work_dir/"

  git add .

  # Check if there are any changes to commit
  if ! git diff-index --quiet HEAD --; then
    # Commit, pull and push the changes
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Autocommit: $timestamp"
    if git remote | grep -q origin; then
      git pull origin main --rebase
    else
      git remote add origin "file://$bare_repo_dir"
      git pull origin main --rebase
    fi
    git push "file://$bare_repo_dir" HEAD:refs/heads/main
  fi
}

# Monitor for changes and handle them as they occur
while inotifywait -r -e modify,create,delete,move /repos/mount; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    handle_sync "$repo_name"
  done
done
