#!/usr/bin/env sh
set -eu

# Explicitly use rootful Docker instead of a rootless Podman-compatible socket.
if [ "$(id -u)" -eq 0 ]; then
  exec env -u DOCKER_HOST -u DOCKER_CONTEXT docker -H unix:///var/run/docker.sock "$@"
fi

exec sudo env -u DOCKER_HOST -u DOCKER_CONTEXT docker -H unix:///var/run/docker.sock "$@"
