# Prometheus + Node Exporter (TLS) + Alertmanager + Grafana (Docker Compose)

This repo runs a monitoring stack with:

- Prometheus (Docker)
- Alertmanager (Docker)
- Grafana (Docker)
- Nginx reverse proxy (Docker)
- Discord webhook proxy (Docker)
- Node Exporter on host (systemd) with TLS enabled

Node Exporter serves **HTTPS on port 9100** using a **self-signed certificate**.

---

## 1) Prometheus configuration (with cluster relabel under `kms`)

Save as `./prometheus.yaml` (mounted to `/etc/prometheus/prometheus.yml` in the Prometheus container):

```yaml
global:
  scrape_interval: 15s # هر ۱۵ ثانیه داده‌ها را جمع‌آوری
  external_labels:
    cluster: "mycluster"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - "alertmanager:9093"

rule_files:
  - "rules/alert_rules.yaml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "docker-host"
    static_configs:
      - targets: ["10.211.55.69:8080"]

  - job_name: "kms"
    static_configs:
      - targets: ["10.211.55.50:8080"]
    relabel_configs:
      - target_label: cluster
        replacement: "mycluster"

  - job_name: "node-exporter-tls"
    scheme: https
    tls_config:
      ca_file: /etc/prometheus/certs/node_exporter.crt
      insecure_skip_verify: true
    static_configs:
      - targets: ["10.211.55.69:9100"]
    relabel_configs:
      - target_label: cluster
        replacement: "mycluster"
```

### Notes
- `external_labels.cluster: "mycluster"` sets a global external label.
- `relabel_configs` above **adds/overrides** the `cluster` label per job (fine to keep).

---

## 2) Node Exporter (TLS) on host

### 2.1 Create the user
```bash
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter
```

### 2.2 Install Node Exporter binary (example)
```bash
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar xvf node_exporter-1.8.1.linux-amd64.tar.gz

sudo mv node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

### 2.3 Create TLS directory + permissions
```bash
sudo mkdir -p /etc/node_exporter/tls
sudo chown -R node_exporter:node_exporter /etc/node_exporter
sudo chmod 750 /etc/node_exporter
```

### 2.4 Create self-signed certificate (your command)
```bash
cd /etc/node_exporter/tls

sudo openssl req -x509 -newkey rsa:4096 \
  -keyout node_exporter.key \
  -out node_exporter.crt \
  -days 365 \
  -nodes \
  -subj "/CN=node-exporter"
```

Permissions:
```bash
sudo chown node_exporter:node_exporter /etc/node_exporter/tls/node_exporter.*
sudo chmod 600 /etc/node_exporter/tls/node_exporter.key
sudo chmod 644 /etc/node_exporter/tls/node_exporter.crt
```

### 2.5 Node Exporter web config: `/etc/node_exporter/web.yml`
```yaml
tls_server_config:
  cert_file: /etc/node_exporter/tls/node_exporter.crt
  key_file: /etc/node_exporter/tls/node_exporter.key

# Optional: Basic Auth
# basic_auth_users:
#   prometheus: $2y$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Permissions:
```bash
sudo chown node_exporter:node_exporter /etc/node_exporter/web.yml
sudo chmod 640 /etc/node_exporter/web.yml
```

### 2.6 systemd service: `/etc/systemd/system/node_exporter.service`

Make sure `[Unit]` is capitalized:

```ini
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=:9100 \
  --web.config.file=/etc/node_exporter/web.yml
Restart=always

[Install]
WantedBy=multi-user.target
```

Reload/start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl restart node_exporter
sudo systemctl status node_exporter
```

### 2.7 Test Node Exporter
On exporter host:
```bash
curl -vk https://localhost:9100/metrics
```

From Prometheus host:
```bash
curl -vk https://10.211.55.69:9100/metrics
```

---

## 3) Copy certificate to Prometheus (for bind mount)

On the docker-compose host:
```bash
mkdir -p certs
sudo cp /etc/node_exporter/tls/node_exporter.crt ./certs/node_exporter.crt
```

Your Prometheus container mounts it as:
- `./certs/node_exporter.crt -> /etc/prometheus/certs/node_exporter.crt`

---

## 4) Docker Compose

Save as `docker-compose.yml`:

```yaml
version: '3.8'

services:
  discord-webhook-proxy:
    build: .
    container_name: discord-webhook-proxy
    restart: unless-stopped
    ports:
      - "5000:5000"
    networks:
      - monitoring

  prometheus:
    image: docker.arvancloud.ir/prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./certs/node_exporter.crt:/etc/prometheus/certs/node_exporter.crt
      - ./rules/alert_rules.yaml:/etc/prometheus/rules/alert_rules.yaml
      - ./rules/docker_rules.yaml:/etc/prometheus/rules/docker_rules.yaml
      - ./prometheus.yaml:/etc/prometheus/prometheus.yml
    networks:
      - monitoring

  grafana:
    image: docker.arvancloud.ir/grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring

  nginx:
    image: nginx:latest
    container_name: nginx_reverse_proxy
    restart: unless-stopped
    volumes:
      - ./ssl:/etc/nginx/ssl
      - ./htfile:/etc/nginx/htfile
      - ./grafana.conf:/etc/nginx/conf.d/grafana.conf:ro
      - ./nginx.conf:/etc/nginx/conf.d/nginx.conf:ro
    ports:
      - "80:80"
      - "443:443"
    networks:
      - monitoring

  alertmanager:
    image: docker.arvancloud.ir/prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
    ports:
      - "9093:9093"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  grafana_data:
```

Start:
```bash
docker compose up -d
docker compose ps
```

---

## 5) Reload Prometheus after changes

Simplest way (restart container):
```bash
docker restart prometheus
```

If you enable lifecycle reload in Prometheus (optional), you can reload without restart.

---

## 6) Troubleshooting

### 6.1 `server returned HTTP status 400 Bad Request`
Means Prometheus tried **HTTP** against a **HTTPS-only** node exporter.

Fix: ensure the job uses:
```yaml
scheme: https
```

### 6.2 `x509: cannot validate certificate ... doesn't contain any IP SANs`
Because you scrape `https://10.211.55.69:9100` using an IP, but your cert CN is `node-exporter` and has no IP SAN.

Your chosen workaround:
```yaml
tls_config:
  insecure_skip_verify: true
```

---

## Optional (recommended): Create proper cert with IP SAN (no insecure_skip_verify)

If you want to set `insecure_skip_verify: false`, recreate cert with an IP SAN:

```bash
cd /etc/node_exporter/tls

cat <<'EOF' | sudo tee san.cnf
[req]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_req

[dn]
CN = 10.211.55.69

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = 10.211.55.69
DNS.1 = node-exporter
EOF

sudo openssl req -x509 -new -nodes \
  -newkey rsa:4096 \
  -keyout node_exporter.key \
  -out node_exporter.crt \
  -days 365 \
  -config san.cnf
```

Then:
- restart `node_exporter`
- copy new cert to `./certs/node_exporter.crt`
- set `insecure_skip_verify: false`

---

## Quick checklist

- [ ] `curl -vk https://10.211.55.69:9100/metrics` returns metrics
- [ ] Prometheus target `node-exporter-tls` is **UP**
- [ ] No other job scrapes `10.211.55.69:9100` using HTTP
