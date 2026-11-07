#!/usr/bin/env sh
set -eu
repo=$(git rev-parse --show-toplevel)
docker run --rm -v "$repo:/src:ro" -v devsecops-trivy-cache:/root/.cache/trivy aquasec/trivy:0.76.2 \
  config --severity CRITICAL --exit-code 1 /src
