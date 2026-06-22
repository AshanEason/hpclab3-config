#!/usr/bin/env bash
set -euo pipefail

role="${1:-}"
if [ "$role" != "controller" ] && [ "$role" != "cpu01" ] && [ "$role" != "gpu01" ]; then
  echo "usage: $0 controller|cpu01|gpu01" >&2
  exit 2
fi

cd "$(dirname "$0")"
sudo mkdir -p /etc/slurm
sudo install -m 644 slurm.conf /etc/slurm/slurm.conf
sudo install -m 644 cgroup.conf /etc/slurm/cgroup.conf

if [ "$role" = "gpu01" ]; then
  sudo install -m 644 gres.conf /etc/slurm/gres.conf
elif [ "$role" = "controller" ]; then
  sudo install -m 644 gres.conf /etc/slurm/gres.conf
fi

ls -l /etc/slurm
