# Use an Alpine base image
FROM alpine:3.18.4

# Install git, git-daemon, rsync, openssh, and nginx
RUN apk update && apk add --no-cache git git-daemon rsync inotify-tools nginx fcgiwrap apache2-utils

# Copy the init script into the image
COPY init.sh /init.sh
COPY nginx.conf /etc/nginx/nginx.conf

# Create the necessary directories if they don't exist
RUN mkdir -p /repos/git /repos/serve /repos/mount

# Use 'main' as the default branch
RUN git config --global init.defaultBranch main

# Set the init script as the command to run when the container starts
CMD ["/init.sh"]
