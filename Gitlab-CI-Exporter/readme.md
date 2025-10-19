# 📈 GitLab CI Pipelines Exporter with Docker Compose & Prometheus

This setup runs the **GitLab CI Pipelines Exporter** (`mvisonneau/gitlab-ci-pipelines-exporter`) as a Docker container to collect metrics from your GitLab instance and expose them to **Prometheus**.

---

## 🧱 Directory Structure

```
gitlab-project-metrics/
├── docker-compose.yml
├── gitlab-ci-pipelines-exporter.yml
└── README.md
```

---

## ⚙️ 1. Prerequisites

Before running the exporter, make sure you have:

- 🐳 Docker & Docker Compose installed  
- 🔑 A **GitLab Personal Access Token (PAT)** with the following scopes:
  - `api`
  - `read_api`
- 🌐 Network access to your GitLab instance (e.g., `https://gitlab.sananetco.com`)

---

## 🐳 2. Docker Compose Configuration

Example **docker-compose.yml:**

```yaml
version: '3.8'

services:
  gitlab-ci-exporter:
    image: mvisonneau/gitlab-ci-pipelines-exporter:latest
    container_name: gitlab-ci-exporter
    restart: always
    environment:
      GITLAB_TOKEN: "glpat-XXXXXXXXXXXXXXXXXXXX"
      GITLAB_URL: "https://gitlab.sananetco.com"
      CONFIG_FILE: /gitlab-ci-pipelines-exporter.yml
    ports:
      - "8085:8080"
    volumes:
      - ./gitlab-ci-pipelines-exporter.yml:/gitlab-ci-pipelines-exporter.yml
```

> ⚠️ Replace `GITLAB_TOKEN` with your **real** Personal Access Token.

---

## 🧩 3. Exporter Configuration

Example **gitlab-ci-pipelines-exporter.yml:**

```yaml
projects:
  - name: "group/project-name"
    refs:
      - "main"
    pull:
      pipelines: true
      jobs: true
      environments: false
```

You can add multiple projects under the `projects:` key.

---

## 🚀 4. Run the Exporter

Start the service:

```bash
docker compose up -d
```

Verify that it’s running:

```bash
docker ps
```

Check logs for confirmation:

```bash
docker logs -f gitlab-ci-exporter
```

---

## 🔍 5. Verify Metrics Endpoint

Once the container is up, visit:

```
http://<host>:8085/metrics
```

You should see metrics such as:

```
gitlab_ci_pipeline_last_run_status{project="group/project-name"} 1
gitlab_ci_pipeline_last_run_duration_seconds{project="group/project-name"} 42
```

---

## 📊 6. Add to Prometheus

In your **prometheus.yml**:

```yaml
scrape_configs:
  - job_name: 'gitlab-ci-exporter'
    static_configs:
      - targets: ['gitlab-ci-exporter:8080']
```

Restart Prometheus:

```bash
docker restart prometheus
```

---

## 🎨 7. Import Grafana Dashboard

You can visualize metrics with Grafana dashboards such as:

| Dashboard | Description | Grafana ID |
|------------|-------------|------------|
| GitLab CI Pipelines Exporter | Per-project pipeline metrics | **13659** |
| GitLab CI/CD Overview | Global pipeline summary | **13902** |

Go to Grafana → **+ → Import → Enter Dashboard ID**.

---

## 🧠 8. Troubleshooting

### ❌ Error: `Key: 'Config.Gitlab.Token' failed on 'required' tag`
Means your `GITLAB_TOKEN` is missing or invalid. Ensure it’s correctly set in your docker-compose file.

### ❌ Empty metrics
Make sure:
- Your GitLab token has correct scopes (`api`, `read_api`).
- Project name matches GitLab path exactly (e.g., `group/project-name`).
- The container can reach `https://gitlab.sananetco.com`.

---

## 🧰 9. Useful Commands

| Command | Description |
|----------|-------------|
| `docker compose up -d` | Start exporter |
| `docker logs -f gitlab-ci-exporter` | Follow logs |
| `curl http://localhost:8085/metrics` | Check metrics manually |
| `docker exec -it gitlab-ci-exporter env` | Verify environment variables |

