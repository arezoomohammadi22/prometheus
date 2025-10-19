# 🦩 GitLab Runner + Prometheus Metrics + Grafana Dashboard (ID 9631)

This repository provides a **step-by-step installation** for setting up a **self-hosted GitLab Runner**
using **Docker Compose**, exposing its **Prometheus metrics**, and visualizing them in **Grafana**.

---

## 🚀 1. Clone and Run

```bash
git clone https://github.com/<your-username>/gitlab-runner-metrics.git
cd gitlab-runner-metrics
docker compose up -d
```

---

## ⚙️ 2. Register Your Runner

Get your registration token from GitLab UI  
(`Admin Area → CI/CD → Runners → Registration token`):

```bash
docker exec -it gitlab-runner gitlab-runner register   --non-interactive   --url http://gitlab.example.com/   --registration-token <YOUR_TOKEN>   --executor docker   --docker-image "alpine:latest"   --description "Self-hosted Runner"   --tag-list "docker,self-hosted"   --run-untagged="true"   --locked="false"
```

---

## 📊 3. Expose Metrics

Metrics are automatically available on:

```
http://<your-runner-host>:9252/metrics
```

You should see metrics such as:
- `gitlab_runner_jobs_total`
- `gitlab_runner_job_duration_seconds`
- `gitlab_runner_errors_total`

---

## 🔧 4. Add to Prometheus

In your Prometheus configuration (`prometheus.yml`):

```yaml
scrape_configs:
  - job_name: 'gitlab-runner'
    static_configs:
      - targets: ['<runner-host>:9252']
```

Restart Prometheus and verify that it collects data.

---

## 📈 5. Import Grafana Dashboard

1. Go to Grafana → **"+" → Import**
2. Enter dashboard ID **9631**
3. Select your Prometheus data source
4. Click **Import**

🎯 Dashboard Reference: [Grafana Dashboard 9631 – GitLab Runner](https://grafana.com/grafana/dashboards/9631-gitlab-runner/)

---

## 🧩 6. Verify

Once the dashboard is imported, you’ll see:
- Active jobs and builds
- Job duration over time
- Runner health and error rate

---

## 🧰 Tech Stack

- 🐳 Docker Compose  
- 🦩 GitLab Runner  
- 📈 Prometheus  
- 📊 Grafana  

---
 
Inspired by GitLab + Grafana open-source ecosystem 💙
