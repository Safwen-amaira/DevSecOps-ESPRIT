# DevSecOps pipeline operating guide

## As-is inventory

The initial repository had a Jenkinsfile but no provisioned Jenkins job, incoming webhook, Kubernetes cluster, or usable local setup procedure. Pre-commit definitions existed, but developers had to install them manually. The baseline checks were not connected into an automated developer-to-deployment path.

## To-be pipeline and security gates

```text
IDE (SonarQube for IDE live feedback)
  → Git commit (pre-commit: Gitleaks, Semgrep, Trivy IaC, hygiene)
  → GitHub push / pull request (tests, Gitleaks, Semgrep, Trivy SCA/IaC/image, ZAP)
  → Jenkins (polls; requires successful GitHub run for exact master commit)
  → Local k3s (image build/import, MySQL + application rollout, health check)
  → ZAP DAST against deployed service
  → Pushgateway → Prometheus history → provisioned Grafana dashboard
```

Critical security findings, failed tests, leaked secrets, and Semgrep errors block the GitHub workflow. Jenkins checks that workflow result for the exact commit before repeating blocking scans and deploying. ZAP informational findings are retained for triage. Scan exports are retained as GitHub Actions artifacts and Jenkins build artifacts. Jenkins polls every five minutes, so a successful GitHub run is deployed on its next poll.

## IDE and local commit gate

`.vscode/extensions.json` recommends SonarQube for IDE (formerly SonarLint), GitHub Actions, YAML, and Docker extensions. In IntelliJ, install SonarQube for IDE from Marketplace. Start Compose, configure the IDE extension's connected mode against `http://localhost:9000`, create a user token in SonarQube, and bind the project to `tn.esprit.spring.services:timesheet-devops`. The token belongs in the IDE credential store and must not be committed. This provides live feedback as developers edit; the Git hook remains the commit gate.

Install Java 17, Maven, `pre-commit`, and Docker with its daemon running, then run:

```sh
./scripts/setup-devsecops.sh
mvn --batch-mode test
```

The script installs the Git hooks and runs the configured checks in all-files mode. Gitleaks remains scoped to staged changes. Git commits made through the IDE invoke the same hooks when that IDE uses this repository's Git executable. Gitleaks, Semgrep, and Trivy run from pinned Docker images; no scanner binaries need to be installed on the host. Semgrep checks Java security rules, Trivy checks critical dependency and IaC findings, and hygiene checks catch common file errors. The first Trivy run downloads its vulnerability database; later runs use a persistent Docker volume. Fix findings before retrying the commit. `security/checkstyle-security.xml` is an optional IntelliJ CheckStyle-IDEA profile.

### Troubleshoot Gitleaks failing to start

On hosts with a low process/thread limit, the Go runtime inside Gitleaks may fail before scanning staged files. The observed diagnostic is:

```text
runtime: failed to create new OS thread (have 2 already; errno=11)
runtime: may need to increase max user processes (ulimit -u)
fatal error: newosproc
```

The hook runs Gitleaks with `GOMAXPROCS=1` and one CPU allocated to reduce its runtime thread demand. After pulling that hook update, retry the commit. If this diagnostic still appears, check host limits with `ulimit -u` and `cat /sys/fs/cgroup/pids.max`; close excess processes or increase the applicable user/container process limit, then rerun `pre-commit run gitleaks-staged --all-files` and retry the commit. This is a scanner startup/resource failure, not a clean scan result; do not disable the secret scan to get a commit through.

## One-command local stack

The root `docker-compose.yml` provisions MySQL, the app, Jenkins with plugins and an automatically seeded pipeline job, SonarQube/PostgreSQL, Nexus, Prometheus, Pushgateway, Grafana, k3s, and one-shot Gitleaks/Semgrep/Trivy/ZAP scanners. Jenkins builds the app image through the Docker socket, imports it into k3s, deploys the database and app, checks readiness, then runs ZAP against the deployed service. The pipeline result is sent to Pushgateway; Prometheus stores its time series and Grafana loads the dashboard from versioned JSON.

```sh
docker compose up --build
```

On Linux, set `DOCKER_GID` in `.env` to the group id from `stat -c '%g' /var/run/docker.sock` so Jenkins can use the socket. On first startup, Jenkins plugins and container images are downloaded. Set Docker memory to at least 8 GB; SonarQube may require host `vm.max_map_count` of at least 524288.

Web UIs:

- App: `http://localhost:8082/timesheet-devops/`
- Jenkins: `http://localhost:8080` (`safwen` / `local-only-jenkins-password`)
- SonarQube: `http://localhost:9000`
- Nexus: `http://localhost:8081`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (`admin` / `local-only-grafana-password`)
- Kubernetes API: `https://localhost:6443`

Jenkins polls the public repository because this laptop Compose service is loopback-only and cannot receive GitHub-hosted webhooks. The local repository is public and needs no GitHub token. For a private repository, add a read-only token through an untracked `.env` and configure Jenkins credentials. SonarQube IDE connected mode requires an individual token and project binding.

Optional failure notification: add a Slack incoming webhook URL to the untracked `.env` as `SLACK_WEBHOOK_URL`. Jenkins sends the failed build URL and commit hash to that channel; the webhook value is passed to the container through Compose and is not committed.

All published ports bind to `127.0.0.1`. Default passwords are for local demonstration only; change them before exposing any service. k3s runs privileged and Jenkins can access the host Docker socket, so treat this as a local learning environment rather than a multi-tenant production cluster. Use `docker compose down` to stop it; use `docker compose down -v` only when intentionally deleting persistent data.

## Reports and exemption process

GitHub scan outputs are attached to each run as `devsecops-reports-<run id>`. Jenkins archives files under `reports/`. The screenshots and reports committed to the repository are examples, not proof of a current passing run. Capture current report exports for the final project presentation.

Exempt a finding only when it is a confirmed false positive or a documented, time-bounded accepted risk. Open an issue and link it in the pull request. Record the scanner and rule/CVE, affected file/component, evidence, compensating control, owner, approver, and expiry/remediation date. Suppress only the narrow rule/component with a reason and issue reference; a reviewer other than the author approves it. Remove the exception after remediation or expiry and rerun the scan. Never disable a whole scanner or use `SKIP=gitleaks` to hide an unreviewed secret; revoke and rotate exposed credentials.
