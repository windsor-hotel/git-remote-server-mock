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

# Change ownership of /repos/git to nginx user and group
chown -R nginx:nginx /repos/git
chmod -R u+rwX,go+rX,go-w /repos/git

# Start supervisord
/usr/bin/supervisord -c /etc/supervisord.conf
