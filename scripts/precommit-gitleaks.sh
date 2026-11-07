#!/usr/bin/env sh
set -eu
repo=$(git rev-parse --show-toplevel)
docker run --rm -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/src \
  -v "$repo:/src" -w /src ghcr.io/gitleaks/gitleaks:v8.30.1 \
  protect --staged --redact --no-banner
