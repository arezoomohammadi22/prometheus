# Blackbox Exporter with Prometheus & Docker Compose + Alerting

## 📌 Overview
The **Blackbox Exporter** allows Prometheus to probe endpoints (HTTP, HTTPS, TCP, ICMP, DNS) from the outside.  
This setup shows how to integrate Blackbox Exporter into a **Docker Compose** stack with Prometheus and Grafana, and configure **alert rules** for uptime, latency, and SSL expiry.

---

## 🔹 Prerequisites
- Docker & Docker Compose installed
- Prometheus already running in Docker Compose
- Grafana (optional, for visualization)

---

## 🔹 Step 1: Create `docker-compose.yml`

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./blackbox-rules.yml:/etc/prometheus/blackbox-rules.yml
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox_exporter
    restart: unless-stopped
    volumes:
      - ./blackbox.yml:/etc/blackbox_exporter/config.yml
    command:
      - '--config.file=/etc/blackbox_exporter/config.yml'
    ports:
      - "9115:9115"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  grafana_data:
```

---

## 🔹 Step 2: Blackbox Exporter Configuration

Create a file named **`blackbox.yml`**:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      method: GET

  tcp_connect:
    prober: tcp
    timeout: 5s

  icmp:
    prober: icmp
    timeout: 5s
```

---

## 🔹 Step 3: Prometheus Configuration

Edit **`prometheus.yml`**:

```yaml
global:
  scrape_interval: 15s

rule_files:
  - "/etc/prometheus/blackbox-rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "blackbox"
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://google.com
          - https://example.com
          - http://grafana:3000
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

---

## 🔹 Step 4: Alert Rules

Create a file named **`blackbox-rules.yml`**:

```yaml
groups:
- name: blackbox-exporter-alerts
  rules:
    - alert: WebsiteDown
      expr: probe_success == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Website down ({{ $labels.instance }})"
        description: "The probe failed for {{ $labels.instance }} for more than 2 minutes."

    - alert: HighLatency
      expr: probe_duration_seconds > 1
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "High latency on {{ $labels.instance }}"
        description: "Probe duration is {{ $value }} seconds (above 1s)."

    - alert: SSLCertificateExpiringSoon
      expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 7
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "SSL certificate expiring soon for {{ $labels.instance }}"
        description: "SSL cert for {{ $labels.instance }} will expire in less than 7 days."

    - alert: SSLCertificateExpired
      expr: probe_ssl_earliest_cert_expiry - time() < 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "SSL certificate expired for {{ $labels.instance }}"
        description: "SSL certificate for {{ $labels.instance }} has expired!"
```

---

## 🔹 Step 5: Start the Stack

```bash
docker-compose up -d
```

---

## 🔹 Step 6: Verify

Check Prometheus UI:

```
http://localhost:9090/targets
```

Alerts will appear in:

```
http://localhost:9090/alerts
```

---

## ✅ Summary
- Blackbox Exporter added to Docker Compose stack.  
- Prometheus scrapes targets through Blackbox Exporter.  
- Alerting rules detect:  
  - Website down  
  - High latency  
  - SSL expiring soon  
  - SSL expired  

---

## 🔗 References
- [Blackbox Exporter GitHub](https://github.com/prometheus/blackbox_exporter)
- [Prometheus Docs](https://prometheus.io/docs/blackbox_exporter/)
