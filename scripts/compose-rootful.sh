#!/usr/bin/env sh
set -eu

# This project runs k3s, which needs cgroup controllers unavailable to the
# rootless Podman socket that may be exposed as `docker` on some Linux hosts.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$script_dir")
cd "$project_dir"
exec "$script_dir/docker-rootful.sh" compose "$@"
