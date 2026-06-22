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

if [ "$role" = "controller" ]; then
  sudo install -m 644 slurmctld.service /etc/systemd/system/slurmctld.service
  sudo mkdir -p /var/spool/slurmctld
  sudo touch /var/log/slurmctld.log
  sudo chmod 755 /var/spool/slurmctld
  sudo chmod 644 /var/log/slurmctld.log
else
  sudo install -m 644 slurmd.service /etc/systemd/system/slurmd.service
  sudo mkdir -p /var/spool/slurmd
  sudo touch /var/log/slurmd.log
  sudo chmod 755 /var/spool/slurmd
  sudo chmod 644 /var/log/slurmd.log
fi

sudo systemctl daemon-reload
ls -l /etc/slurm
