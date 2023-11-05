#!/usr/bin/env sh

# Function to handle syncing, committing, and pushing for a given repository
handle_sync() {
  repo_name="$1"
  src_dir="/repos/mount/$repo_name"
  work_dir="/repos/serve/$repo_name"
  bare_repo_dir="/repos/git/$repo_name.git"

  # Sync the current state
  rsync -av --delete --exclude='.git' "$(echo "${RSYNC_EXCLUDE}" | sed 's/,/ --exclude=/g' | sed 's/^/--exclude=/')" "$src_dir/" "$work_dir/"

  cd "$work_dir" || exit
  git add .

  # Check if there are any changes to commit
  if ! git diff-index --quiet HEAD --; then
    # Commit and push the changes
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Autocommit: $timestamp"
    git push "file://$bare_repo_dir" HEAD:refs/heads/main
  fi
}

# Create the necessary directories if they don't exist
mkdir -p /repos/git /repos/serve /repos/mount

# Use 'main' as the default branch
git config --global init.defaultBranch main

# Initial setup for all repositories
for dir in /repos/mount/*; do
  repo_name=$(basename "$dir")

  # Initialize a new bare repository in /repos/git
  git init --bare "/repos/git/$repo_name.git"

  # Create a corresponding non-bare repository in /repos/serve
  mkdir -p "/repos/serve/$repo_name"

  # Change to the new non-bare repository directory
  cd "/repos/serve/$repo_name" || exit

  # Initialize a new non-bare repository
  git init

  # Set the user identity for making commits
  git config user.name "Auto-commit"
  git config user.email "auto-commit@localhost"

  # Copy the contents of the current directory to the new non-bare repository, excluding the .git directory
  rsync -av --exclude='.git' "$dir/" .

  # Add the contents to the git repository
  git add .

  # Commit the contents to the git repository
  git commit -m 'Initial commit'

  # Create a new branch named 'main' and switch to it
  git branch -m main

  # Push the contents to the bare repository
  git push "file:///repos/git/$repo_name.git" HEAD:refs/heads/main
done

# Monitor for changes and handle them as they occur
while inotifywait -r -e modify,create,delete,move /repos/mount; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    handle_sync "$repo_name"
  done
done &

# Run the git daemon
exec git daemon --reuseaddr --base-path=/repos/git --export-all --enable=receive-pack --verbose
