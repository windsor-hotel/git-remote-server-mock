# Use an Alpine base image
FROM alpine:3.18.4

# Install git, git-daemon, and rsync
RUN apk update && apk add --no-cache git git-daemon rsync inotify-tools

# Copy the init script into the image
COPY init.sh /init.sh

# Set the init script as the command to run when the container starts
CMD ["/init.sh"]
