# mock-git-remote

This repository publishes a simple Docker image that acts as a "mock" git remote server. This is useful for developing
and testing code in a "gitops" like environment. This container additionally performs "livereload"
functionality.

In the example `docker-compose.yaml` file, the container is mounted from the local root directory in to the 
`/repos/mount/` folder in the container,

```
version: '3.1'

services:
  git-server:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8888:80"
    environment:
      GIT_USERNAME=dev
      GIT_PASSWORD=dev
    volumes:
      - ./:/repos/mount/git-remote-server-mock
```

Any folder mounted to `/repos/mount/` will be served by the container. You could clone this repository by running
`git clone http://dev:dev@localhost:8888/git/git-remote-server-mock.git`. Any time a file has changed, internally in the container,
a new commit is created and pushed to the repository. This is not reflected back on the host. If a gitops based
operator points to this repository, it will see the changes and apply them each time you save a file.

You can pull this image from the Docker package registry by running `git pull ghcr.io/windsor-hotel/git-remote-server-mock:v0.1.2`
