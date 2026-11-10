# DevSecOps ESPRIT

Automated security gates for the Timesheet application, from IDE feedback through deployment and monitoring. The local lab uses Git hooks, GitHub Actions, Jenkins, k3s, Prometheus, and Grafana.

## Delivery flow

```text
IDE SonarQube for IDE feedback
  → Git pre-commit (Gitleaks, Semgrep, Trivy IaC, file hygiene)
  → GitHub Actions on push and pull request (tests, SAST, SCA, IaC, image, secrets, DAST)
  → Jenkins waits for the successful GitHub run for that exact master commit
  → Jenkins repeats blocking scans and builds the container
  → k3s deploys MySQL + application, then checks rollout and health
  → ZAP scans the deployed app
  → Pushgateway → Prometheus history → provisioned Grafana dashboard
```

Critical vulnerabilities, leaked secrets, failed tests, and Semgrep errors block deployment. See [docs/DEVSECOPS.md](docs/DEVSECOPS.md) for the as-is/to-be analysis, setup, quality gates, and exemption process.

## Start the local stack

Requirements: rootful Docker Engine with Compose, at least 8 GB available memory, and a host `vm.max_map_count` of at least `524288` for SonarQube. On Linux, set `DOCKER_GID` in `.env` to `stat -c '%g' /var/run/docker.sock` so Jenkins can use the host Docker socket. The helper below explicitly selects `/var/run/docker.sock`; this matters on systems where `docker` otherwise points to rootless Podman.

```sh
./scripts/compose-rootful.sh up -d --build
```

Use the same helper for other Compose commands, for example `./scripts/compose-rootful.sh ps` and `./scripts/compose-rootful.sh logs -f jenkins`. If you previously started this project through rootless Podman, stop that copy once with `docker compose down` from this repository before starting the rootful Docker copy; the two engines have separate containers and port mappings.

Jenkins creates the `DevSecOps-ESPRIT` job automatically and polls GitHub every five minutes. The local test stack binds published ports to loopback. The first run downloads images and Jenkins plugins and may take several minutes.

| Component | Local URL |
|---|---|
| Timesheet application | http://localhost:8082/timesheet-devops/ |
| Jenkins | http://localhost:8080 (`Safwen-amaira` / `local-only-jenkins-password`) |
| SonarQube | http://localhost:9000 |
| Nexus | http://localhost:8081 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (`admin` / `local-only-grafana-password`) |
| k3s API | https://localhost:6443 |

Grafana dashboard: [DevSecOps delivery overview](http://localhost:3000/d/devsecops-overview/devsecops-delivery-overview). Scan outputs are stored in `reports/` and in the matching GitHub Actions/Jenkins run artifacts.

## Developer setup

Install Java 17, Maven, pre-commit, and rootful Docker Engine. Open the repository in VS Code to install recommended extensions from `.vscode/extensions.json`; IntelliJ users can install SonarQube for IDE from Marketplace. Connect the IDE plugin to `http://localhost:9000` in connected mode and bind the project to `tn.esprit.spring.services:timesheet-devops`. Keep the SonarQube user token in the IDE credential store. Gitleaks, Semgrep, and Trivy run in containers from the Git hooks through `scripts/docker-rootful.sh`.

Install hooks and verify the checkout:

```sh
./scripts/setup-devsecops.sh
mvn --batch-mode test
```

IDE Git commits execute the installed Git hooks. GitHub Actions repeats the security checks on every push and pull request.

## Repository map

- `.github/workflows/devsecops.yml` — GitHub tests and security quality gates.
- `.pre-commit-config.yaml` — local developer commit gate.
- `jenkins/` and `pipeline/Jenkinsfile` — provisioned Jenkins controller and gated delivery pipeline.
- `kubernetes/` — k3s deployment and services.
- `monitoring/` — Prometheus and Grafana provisioning/dashboard.
- `security/` — Semgrep rules and optional security policy examples.
- `docs/DEVSECOPS.md` — detailed operating and project guide.

## Local data and credentials

`.env.example` documents demo-only settings. `.env` is ignored by Git. Change all default passwords before exposing services beyond loopback. Jenkins has Docker socket access and k3s runs privileged, so this Compose stack is a local learning lab rather than a multi-tenant production deployment. `docker compose down` stops services; `docker compose down -v` deletes persistent database and monitoring data.
