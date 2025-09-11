# Prometheus Installation (Binary + systemd)

This project demonstrates how to **install Prometheus from the official binary release** and configure it as a **systemd service** so it runs on boot.

---

## 📌 Overview
- Download and extract Prometheus official binaries
- Create a dedicated `prometheus` user and directories
- Install binaries, config, and consoles
- Create a minimal `prometheus.yml` configuration
- Write a `systemd` unit file for Prometheus
- Start, enable, and verify the service

---

## 🚀 Installation Steps

### 1. Create Prometheus user & directories
```bash
sudo useradd --no-create-home --shell /usr/sbin/nologin prometheus
sudo mkdir -p /etc/prometheus /var/lib/prometheus /opt/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /opt/prometheus
```

### 2. Download latest Prometheus binary
```bash
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest   | grep "browser_download_url"   | grep linux-amd64   | cut -d '"' -f4   | xargs -n1 wget -q --show-progress -O prometheus.tar.gz
```

### 3. Extract and install
```bash
tar xzf prometheus.tar.gz
EXTRACTED=$(tar tzf prometheus.tar.gz | head -1 | cut -f1 -d"/")

sudo cp "$EXTRACTED"/prometheus "$EXTRACTED"/promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

sudo cp -r "$EXTRACTED"/consoles "$EXTRACTED"/console_libraries /etc/prometheus/
sudo cp "$EXTRACTED"/prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus
```

---

## ⚙️ Minimal `prometheus.yml`

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

Save as: `/etc/prometheus/prometheus.yml`

---

## 🔧 systemd Service Unit

Create file: `/etc/systemd/system/prometheus.service`

```ini
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus   --config.file=/etc/prometheus/prometheus.yml   --storage.tsdb.path=/var/lib/prometheus   --web.console.templates=/etc/prometheus/consoles   --web.console.libraries=/etc/prometheus/console_libraries
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## ▶️ Start & Enable Prometheus
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
```

---

## ✅ Verification

Check service status:
```bash
sudo systemctl status prometheus --no-pager
```

View logs:
```bash
sudo journalctl -u prometheus -n 20 --no-pager
```

Test metrics endpoint:
```bash
curl -s http://localhost:9090/metrics | head -n 10
```

Open the web UI:
```
http://<server-ip>:9090
```

---

## 🛠️ Troubleshooting
- **Permission denied** → Ensure `/etc/prometheus` and `/var/lib/prometheus` are owned by `prometheus`.
- **Port already in use** → Check for other services on port `9090`.
- **Service fails** → Run `journalctl -u prometheus -xe` for detailed logs.

---

## 📚 Next Steps
- Install [Node Exporter](https://github.com/prometheus/node_exporter) for host metrics.
- Add retention policy:  
  ```bash
  --storage.tsdb.retention.time=15d
  ```
- Secure access with reverse proxy / authentication.

---

## 📜 License
MIT – use freely in your own projects.
