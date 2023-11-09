#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}

# Set default credentials
GIT_USERNAME=${GIT_USERNAME:-git}
GIT_PASSWORD=${GIT_PASSWORD:-p@$$w0rd}

# Create .htpasswd file for Nginx
htpasswd -bc /etc/nginx/.htpasswd "$GIT_USERNAME" "$GIT_PASSWORD"

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

  # Sync the current state
  rsync -av --delete "${exclude_args[@]}" "$src_dir/" "$work_dir/"

  cd "$work_dir" || exit
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
  rsync -av "${exclude_args[@]}" "$dir/" .

  # Add the contents to the git repository
  git add .

  # Commit the contents to the git repository
  git commit -m 'Initial commit'

  # Create a new branch named 'main' and switch to it
  git branch -m main

  # Push the contents to the bare repository
  git push "file:///repos/git/$repo_name.git" HEAD:refs/heads/main
done

# Adjust ownership and permissions for .htpasswd
chown nginx:nginx /etc/nginx/.htpasswd
chmod 0660 /etc/nginx/.htpasswd

# Change ownership of /repos/git to nginx user and group
chown -R nginx:nginx /repos/git
chmod -R u+rwX,go+rX,go-w /repos/git

# Monitor for changes and handle them as they occur
while inotifywait -r -e modify,create,delete,move /repos/mount; do
  for dir in /repos/mount/*; do
    repo_name=$(basename "$dir")
    handle_sync "$repo_name"
  done
done
