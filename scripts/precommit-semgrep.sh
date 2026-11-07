#!/usr/bin/env sh
set -eu
repo=$(git rev-parse --show-toplevel)
docker run --rm -v "$repo:/src:ro" semgrep/semgrep:1.100.0 \
  scan --metrics=off --config=/src/security/semgrep-rules.yml --error --severity=ERROR /src
