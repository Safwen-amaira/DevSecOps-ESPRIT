#!/usr/bin/env sh
set -eu

need=""
for tool in git pre-commit docker java mvn; do
  if ! command -v "$tool" >/dev/null 2>&1; then need="$need $tool"; fi
done
if [ -n "$need" ]; then
  echo "Missing local DevSecOps tools:$need" >&2
  echo "Install pre-commit, Docker, Java 17 and Maven, then rerun this script." >&2
  exit 1
fi
docker info >/dev/null 2>&1 || {
  echo "Start the Docker daemon before installing/running the container-based security hooks." >&2
  exit 1
}
java -version 2>&1 | grep -q '17\.' || {
  echo "Java 17 is required for this project's Maven build." >&2
  exit 1
}
pre-commit install --install-hooks
pre-commit run --all-files
echo "Local commit hooks are installed. IDE Git commits now invoke the same hooks."
