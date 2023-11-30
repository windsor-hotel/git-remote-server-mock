#!/usr/bin/env bats

setup() {
  export DOCKER_CONTAINER_NAME="git-server" # Name of the Docker container running the Git server
  export MOUNTED_FOLDER="./test/sample" # Host path of the mounted folder
  export WORKING_DIR="/repos/serve/sample" # Path to the working directory inside the Docker container
  export RSYNC_EXCLUDE="dontsync"
  mkdir -p "$MOUNTED_FOLDER"
}

@test "Files are synced from mounted folder to working directory" {
  # Create a new file in the mounted folder
  touch "$MOUNTED_FOLDER/new_file.txt"

  # Wait for the sync to complete
  sleep 5

  # Check if the file exists in the working directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" test -f "$WORKING_DIR/new_file.txt"
  [ "$status" -eq 0 ]
}

@test "Files added via Git do not get deleted or synced back" {
  # Add a file directly in the working directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" bash -c "touch '$WORKING_DIR/git_added_file.txt' && git -C '$WORKING_DIR' add git_added_file.txt && git -C '$WORKING_DIR' commit -m 'Add file via Git'"

  # Wait for the sync to complete
  sleep 5

  # Check that the file still exists in the working directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" test -f "$WORKING_DIR/git_added_file.txt"
  [ "$status" -eq 0 ]

  # Check that the file does not exist in the mounted folder on the host
  [ ! -f "$MOUNTED_FOLDER/git_added_file.txt" ]
}

@test "Deletions in the mounted folder propagate to the working directory" {
  # Create and then delete a file in the mounted folder
  touch "$MOUNTED_FOLDER/deletable_file.txt"
  rm "$MOUNTED_FOLDER/deletable_file.txt"

  # Wait for the sync to complete
  sleep 5

  # Check that the file does not exist in the working directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" test ! -f "$WORKING_DIR/deletable_file.txt"
  [ "$status" -eq 0 ]
}

teardown() {
  # Clean up test artifacts on the host
  rm -rf "$MOUNTED_FOLDER"/*
}
