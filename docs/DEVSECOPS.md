# DevSecOps pipeline: current state and operating guide

## As-is inventory

The repository already contains a Jenkins pipeline in `pipeline/Jenkinsfile`. It builds and tests the Spring Boot application, submits SonarQube analysis and waits for its Quality Gate, scans dependencies and Kubernetes configuration with Trivy, builds and scans a container, then deploys to Kubernetes for health checks, ZAP DAST, and runtime/operations checks. Jenkins archives reports and sends email notifications. Local pre-commit hooks provide an early secret and SAST check.

The Jenkins stages require provisioned Jenkins plugins, credentials, Docker, Kubernetes, SonarQube, Vault, and the named runtime tools. A Jenkinsfile alone does not configure a GitHub webhook or Multibranch Pipeline. Configure the Jenkins GitHub push and pull-request triggers in the Jenkins job and repository webhook for that environment. Never put Jenkins credentials in this repository.

## To-be automation

`.github/workflows/devsecops.yml` now runs on pushes and pull requests targeting `master` or `main`, and can be launched manually. It runs Maven tests, Gitleaks over Git history, custom Semgrep rules, Trivy dependency and image scans, an image build, and OWASP ZAP against a running test application. JSON/HTML/log outputs are uploaded as a 30-day GitHub Actions artifact, including when a gate fails.

Blocking gates are failed tests, detected secrets, Semgrep ERROR findings, and unfixed CRITICAL dependency or image vulnerabilities. HIGH Trivy findings and ZAP informational/warning findings are reported for triage. Update the critical threshold only through a reviewed change with a documented risk rationale.

## Local developer setup

Install Java 17, Maven, pre-commit, Semgrep, and Gitleaks (available on `PATH`). The local hooks use the committed Semgrep rules and do not need Docker or a remote rule registry. From the repository root:

```sh
pre-commit install
pre-commit run --all-files
mvn --batch-mode test
```

Hooks are feedback before commit; CI repeats the security checks on every push and pull request. IDE users can enable SonarLint/SonarQube for continuous feedback and use the repository's Semgrep rules for Java findings. `security/checkstyle-security.xml` is an optional IntelliJ CheckStyle-IDEA profile; GitHub Actions does not claim Checkstyle as a CI gate.

## Exemption process

A gate may be exempted only for a confirmed false positive or a documented, time-bounded accepted risk. Open an issue and link it in the pull request; record the scanner, rule or CVE, affected file/component, evidence for the decision, compensating control, owner, approver, and expiry/remediation date. Exempt the narrow rule or component using the scanner's supported suppression mechanism with a reason and issue reference. Do not disable a whole scanner, weaken the global threshold, or add credentials to the exemption. A reviewer other than the author must approve it. Remove the exception when fixed or at expiry, and rerun the affected scan.

Emergency bypasses must be approved by the repository maintainers, logged in the issue and pull request, and followed by a remediation commit. Never use `SKIP=gitleaks` to conceal an unreviewed secret; exposed credentials must be revoked and rotated.

## Reports and follow-up

GitHub Actions reports are attached to each run as `devsecops-reports-<run id>`. Jenkins additionally archives its reports and publishes its HTML summary. The committed screenshots under `screenshots/` and `reports/` are illustrative snapshots, not proof that a current build passed. Record fresh run links and attach fresh scan exports when preparing the final project report and presentation.

The GitHub workflow gates CRITICAL findings for dependencies, IaC, and images. In the current Jenkinsfile, dependency and IaC scans are non-blocking, and the image scan uses `TRIVY_EXIT_CODE=0`, so it is report-only. Align Jenkins' SCA/IaC/image thresholds with the intended policy and confirm the Jenkins parameter and webhook configuration in the deployment environment before claiming those controls are blocking and push-triggered.

## One-command local stack

The tracked root `docker-compose.yml` is the single Compose entry point. It starts the MySQL-backed application, Jenkins, SonarQube/PostgreSQL, Nexus, Prometheus, and Grafana. It also runs one-shot Gitleaks, Semgrep, Trivy dependency/IaC/image, and OWASP ZAP scan containers. Scanner output is written under `reports/`.

```sh
docker compose up --build
```

Web UIs: app `http://localhost:8082/timesheet-devops/`, Jenkins `http://localhost:8080`, SonarQube `http://localhost:9000`, Nexus `http://localhost:8081`, Prometheus `http://localhost:9090`, and Grafana `http://localhost:3000` (admin / `local-only-grafana-password`). Jenkins and SonarQube show their first-run setup; initialize them in the UI. Jenkins job creation, GitHub webhook configuration, and Sonar project token creation are still administrator setup steps. The `pipeline/Jenkinsfile` documents the full deployment pipeline and expects a configured Jenkins with its plugins, credentials, Docker, Kubernetes, Vault and runtime-security tools; Compose provides the local app and analysis services, not a Kubernetes production cluster or those credentials.

The Compose stack binds published ports to `127.0.0.1`. Default passwords are local demo values and must be overridden via `.env` before any network exposure. Set Docker's memory to at least 8 GB for the complete Jenkins/SonarQube/Nexus stack; SonarQube may require host `vm.max_map_count` of at least 524288. Use `docker compose down` to stop services and `docker compose down -v` only when intentionally deleting persistent service data.

On a fresh host, scan reports are created in `reports/`; a failed high/critical gate exits its scanner container nonzero. Review them using `docker compose ps -a` and the JSON/HTML files in that directory. Docker image scanning requires access to the host Docker socket.
