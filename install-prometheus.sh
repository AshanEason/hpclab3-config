#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROM_VERSION=3.10.0
PROM_DIR="prometheus-${PROM_VERSION}.linux-amd64"
PROM_TARBALL="${PROM_DIR}.tar.gz"
PROM_URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PROM_TARBALL}"

find_prometheus_binary() {
  for path in \
    "/home/ubuntu/${PROM_DIR}/prometheus" \
    "/home/judge/${PROM_DIR}/prometheus" \
    "/opt/${PROM_DIR}/prometheus" \
    "/tmp/${PROM_DIR}/prometheus"; do
    if [ -x "$path" ]; then
      echo "$path"
      return
    fi
  done

  if [ -f "/home/ubuntu/${PROM_TARBALL}" ]; then
    tar -xzf "/home/ubuntu/${PROM_TARBALL}" -C /tmp
    echo "/tmp/${PROM_DIR}/prometheus"
    return
  fi

  if [ -f "/home/judge/${PROM_TARBALL}" ]; then
    tar -xzf "/home/judge/${PROM_TARBALL}" -C /tmp
    echo "/tmp/${PROM_DIR}/prometheus"
    return
  fi

  wget -q "$PROM_URL" -O "/tmp/${PROM_TARBALL}"
  tar -xzf "/tmp/${PROM_TARBALL}" -C /tmp
  echo "/tmp/${PROM_DIR}/prometheus"
}

prom_bin="$(find_prometheus_binary)"

if ! id prometheus >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
fi

sudo install -m 755 "$prom_bin" /usr/local/bin/prometheus
sudo install -d -o prometheus -g prometheus -m 755 /etc/prometheus /var/lib/prometheus
sudo install -m 644 prometheus.yml /etc/prometheus/prometheus.yml
sudo install -m 644 prometheus.service /etc/systemd/system/prometheus.service
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
systemctl is-active prometheus
curl -s 'http://localhost:9090/api/v1/query?query=up' | head -c 500
echo
