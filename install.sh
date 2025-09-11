#!/usr/bin/env bash
# Prometheus binary installer + systemd unit
# Usage: sudo ./install.sh [--yes]
# If --yes is provided the script runs non-interactively and may overwrite existing files.

set -euo pipefail

FORCE=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  FORCE=true
fi

confirm() {
  if $FORCE; then
    return 0
  fi
  read -rp "$1 [y/N]: " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
  fi
}

require_root

echo "Prometheus binary installer + systemd unit"
echo "This will download the latest Prometheus linux-amd64 release, install binaries to /usr/local/bin,"
echo "place config in /etc/prometheus and create a systemd unit at /etc/systemd/system/prometheus.service"
echo

if ! confirm "Proceed with installation?"; then
  echo "Aborted."
  exit 0
fi

PROM_USER=prometheus
PROM_GROUP=prometheus
ETC_DIR=/etc/prometheus
DATA_DIR=/var/lib/prometheus
TMPDIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Creating user and directories..."
if ! id -u "$PROM_USER" >/dev/null 2>&1; then
  useradd --no-create-home --shell /usr/sbin/nologin "$PROM_USER"
  echo "Created user $PROM_USER"
else
  echo "User $PROM_USER already exists"
fi

mkdir -p "$ETC_DIR" "$DATA_DIR" /opt/prometheus
chown -R "$PROM_USER":"$PROM_GROUP" "$ETC_DIR" "$DATA_DIR" /opt/prometheus

echo "Detecting latest Prometheus release for linux-amd64..."
cd "$TMPDIR"
ASSET_URL=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest \
  | grep "browser_download_url" \
  | grep linux-amd64 \
  | cut -d '"' -f4 || true)

if [[ -z "$ASSET_URL" ]]; then
  echo "Failed to find linux-amd64 release asset URL. Exiting." >&2
  exit 1
fi

echo "Found asset: $ASSET_URL"
echo
if ! confirm "Download and install release from the URL above?"; then
  echo "Aborted."
  exit 0
fi

echo "Downloading..."
wget -q --show-progress -O prometheus.tar.gz "$ASSET_URL"

echo "Extracting..."
tar xzf prometheus.tar.gz
EXTRACTED_DIR=$(tar tzf prometheus.tar.gz | head -1 | cut -f1 -d"/")
echo "Extracted: $EXTRACTED_DIR"

# Install binaries
echo "Installing binaries to /usr/local/bin..."
cp "$EXTRACTED_DIR"/prometheus "$EXTRACTED_DIR"/promtool /usr/local/bin/
chown "$PROM_USER":"$PROM_GROUP" /usr/local/bin/prometheus /usr/local/bin/promtool
chmod 0755 /usr/local/bin/prometheus /usr/local/bin/promtool

# Install consoles and config
echo "Installing consoles and default config to $ETC_DIR..."
if [[ -d "$ETC_DIR/consoles" && "$FORCE" != "true" ]]; then
  if confirm "$ETC_DIR already contains consoles. Overwrite?"; then
    rm -rf "$ETC_DIR/consoles" "$ETC_DIR/console_libraries"
  else
    echo "Keeping existing consoles."
  fi
fi

cp -r "$EXTRACTED_DIR"/consoles "$EXTRACTED_DIR"/console_libraries "$ETC_DIR"/
if [[ -f "$ETC_DIR/prometheus.yml" && "$FORCE" != "true" ]]; then
  if confirm "$ETC_DIR/prometheus.yml already exists. Overwrite?"; then
    cp "$EXTRACTED_DIR"/prometheus.yml "$ETC_DIR"/prometheus.yml
  else
    echo "Keeping existing prometheus.yml"
  fi
else
  cp "$EXTRACTED_DIR"/prometheus.yml "$ETC_DIR"/prometheus.yml
fi

chown -R "$PROM_USER":"$PROM_GROUP" "$ETC_DIR"
chown -R "$PROM_USER":"$PROM_GROUP" "$DATA_DIR"

# Write a cautious systemd unit (will prompt if exists)
SYSTEMD_UNIT=/etc/systemd/system/prometheus.service
if [[ -f "$SYSTEMD_UNIT" && "$FORCE" != "true" ]]; then
  if confirm "$SYSTEMD_UNIT already exists. Overwrite?"; then
    :
  else
    echo "Keeping existing systemd unit."
  fi
fi

cat > "$SYSTEMD_UNIT" <<'UNIT'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and starting prometheus service..."
systemctl enable --now prometheus

echo
echo "Installation finished. Quick checks:"
echo "  systemctl status prometheus --no-pager"
echo "  journalctl -u prometheus -n 50 --no-pager"
echo "  curl -sS http://localhost:9090/metrics | head -n 20"
echo
echo "If your server is remote, ensure port 9090 is reachable (firewall rules)."
echo "Default config installed at: $ETC_DIR/prometheus.yml"
echo "Data directory: $DATA_DIR"
