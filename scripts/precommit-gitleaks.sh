#!/usr/bin/env sh
set -eu
repo=$(git rev-parse --show-toplevel)
# Keep Go's runtime within the low process/thread limits used by some developer
# machines and container runtimes. Without this, Gitleaks can fail before it
# scans anything with: "runtime: failed to create new OS thread".
docker run --rm --cpus=1 -e GOMAXPROCS=1 \
  -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/src \
  -v "$repo:/src" -w /src ghcr.io/gitleaks/gitleaks:v8.30.1 \
  protect --staged --redact --no-banner
