#!/usr/bin/env bats

setup_file() {
  export DOCKER_CONTAINER_NAME="git-server"
  export MOUNTED_FOLDER="./test/sample"
  export WORKING_DIR="/repos/serve/sample"
  export RSYNC_EXCLUDE="dontsync"
  mkdir -p "$MOUNTED_FOLDER"

  export GIT_SERVER_HOST="localhost"
  export GIT_SERVER_PORT="8888"
  export GIT_REPOSITORY_URL="http://local:local@${GIT_SERVER_HOST}:${GIT_SERVER_PORT}/git/sample.git"
  export TEMP_CLONE_DIR="./test/tmp_clone"

  # Create temporary directory for cloning
  mkdir -p "$TEMP_CLONE_DIR"

  docker-compose down
  docker-compose up -d --build
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

@test "Excluded files do not get synchronized" {
  # Create a new file in the mounted folder
  touch "$MOUNTED_FOLDER/excluded_file.txt"

  # Wait for the sync to complete
  sleep 2

  # Check if the file exists in the working directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" test ! -f "$WORKING_DIR/excluded_file.txt"
  [ "$status" -eq 0 ]
}

@test "Protected files do not get deleted" {
  # Define the protected directory and file path
  local protected_dir="flux-sync"
  local file_name="git_added_file.txt"
  local protected_file_path="$protected_dir/$file_name"

  # Add a file directly in the protected directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" mkdir -p "$WORKING_DIR/$protected_dir"
  run docker exec "$DOCKER_CONTAINER_NAME" touch "$WORKING_DIR/$protected_file_path"

  # Wait for the sync to complete
  sleep 2

  # Check that the file still exists in the protected directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" test -f "$WORKING_DIR/$protected_file_path"
  [ "$status" -eq 0 ]

  # Check that the file does not exist in the mounted folder on the host
  [ ! -f "$MOUNTED_FOLDER/$protected_file_path" ]
}

@test "Deletions in the mounted folder propagate to the working directory" {
  # Create and then delete a file in the mounted folder
  touch "$MOUNTED_FOLDER/deletable_file.txt"
  rm "$MOUNTED_FOLDER/deletable_file.txt"

  # Wait for the sync to complete
  sleep 2

  # Check that the file does not exist in the working directory inside the Docker container
  run docker exec "$DOCKER_CONTAINER_NAME" test ! -f "$WORKING_DIR/deletable_file.txt"
  [ "$status" -eq 0 ]
}

@test "Git repository can be cloned remotely" {
  # Perform a full clone into the temporary directory
  git clone "$GIT_REPOSITORY_URL" "$TEMP_CLONE_DIR"

  # Check if README.md exists in the cloned repository
  [ -f "$TEMP_CLONE_DIR/README.md" ]
}

teardown_file() {
  # Clean up test artifacts on the host
  rm -rf "$MOUNTED_FOLDER"/deletable_file.txt
  rm -rf "$MOUNTED_FOLDER"/git_added_file.txt
  rm -rf "$MOUNTED_FOLDER"/excluded_file.txt
  rm -rf "$MOUNTED_FOLDER"/new_file.txt
  rm -rf ./test/tmp_clone

  docker-compose down
}
