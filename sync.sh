#!/usr/bin/env bash
set -eoux pipefail

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
  local IFS=' ' # Set IFS to space for joining the array
  echo "${exclude_args[*]}" # Echo the arguments separated by spaces
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

  git remote set-url origin "file://$bare_repo_dir"
  git fetch origin

  # Reset to the latest state of 'origin/main'
  git reset --hard origin/main

  # Sync the current state
  # shellcheck disable=SC2086
  rsync -av --delete $exclude_args "$src_dir/" "$work_dir/"

  # Stage changes
  git add .

  # Check if there are any changes to commit
  if ! git diff --quiet --cached; then
    # Commit and rebase with the latest changes
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Autocommit: $timestamp"

    # Pull and rebase changes from the remote repository
    git pull --rebase origin main

    # Push changes to the remote repository
    git push origin main
  fi
}

# Monitoring and syncing loop for changes other than deletions
while inotifywait -r -e modify,create,move /repos/mount; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    handle_sync "$repo_name"
  done
done &

# Deletion tracking loop
while read -r path action file; do
  if [ "$action" = "DELETE" ]; then
    # Construct the full path of the deleted file
    full_src_path="$path$file"
    apply_deletion "$full_src_path" "/repos/serve"
  fi
done < <(inotifywait -m -r -e delete --format '%w %e %f' /repos/mount)

