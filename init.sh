#!/usr/bin/env bash
set -eou pipefail

RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-}

# Set default credentials
GIT_USERNAME=${GIT_USERNAME:-git}
GIT_PASSWORD=${GIT_PASSWORD:-p@$$w0rd}

# Create .htpasswd file for Nginx
htpasswd -bc /etc/nginx/.htpasswd "$GIT_USERNAME" "$GIT_PASSWORD"

# Adjust ownership and permissions for .htpasswd
chown nginx:nginx /etc/nginx/.htpasswd
chmod 0660 /etc/nginx/.htpasswd

# Set the user identity for making commits
git config --global user.name "Auto-commit"
git config --global user.email "auto-commit@localhost"

# Always exclude .git and expand other excludes from RSYNC_EXCLUDE variable
exclude_args=('--exclude=.git')
if [ -n "$RSYNC_EXCLUDE" ]; then
  IFS=',' read -ra EXCLUDES <<< "$RSYNC_EXCLUDE"
  for exclude in "${EXCLUDES[@]}"; do
    exclude_args+=("--exclude=$exclude")
  done
fi

# Initial setup for all repositories
for dir in /repos/mount/*; do
  repo_name=$(basename "$dir")

  # Initialize a new bare repository in /repos/git
  git init --bare "/repos/git/$repo_name.git"

  # Create a corresponding non-bare repository in /repos/serve
  mkdir -p "/repos/serve/$repo_name"

  # Change to the new non-bare repository directory
  cd "/repos/serve/$repo_name" || exit

  # Set safe directory
  git config --global --add safe.directory "/repos/serve/$repo_name"

  # Initialize a new non-bare repository
  git init

  # Add the bare repository as a remote named 'origin'
  git remote add origin "file:///repos/git/$repo_name.git"

  # Sync files from mount to serve
  rsync -av "${exclude_args[@]}" "$dir/" .

  # Check if there are files to commit
  if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m 'Initial commit'
    git branch -m main
  else
    echo "No files to commit in $repo_name"
    continue # Skip to the next repository if there are no files to commit
  fi

  # Push the initial commit to the bare repository
  git push -u origin main
done

# Change ownership of /repos/git to nginx user and group
chown -R nginx:nginx /repos/git
chmod -R u+rwX,go+rX,go-w /repos/git

# Start supervisord
/usr/bin/supervisord -c /etc/supervisord.conf
