#!/usr/bin/env bash
set -eou pipefail

# Start fcgiwrap
fcgiwrap -s unix:/var/run/fcgiwrap.socket &

# Wait for the socket to be created
while [ ! -S /var/run/fcgiwrap.socket ]; do
  sleep 0.1
done

# Set the permissions
chown nginx:nginx /var/run/fcgiwrap.socket
chmod 0660 /var/run/fcgiwrap.socket

# Keep the script running to not exit and hence keep the service running
wait
