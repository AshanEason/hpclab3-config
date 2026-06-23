#!/usr/bin/env bash
set -euo pipefail

echo "[before module]"
sudo -iu judge bash -lc 'command -v stress-ng || true; command -v apptainer || true; command -v all_reduce_perf || true'

echo "[module load]"
sudo -iu judge bash -lc 'type ml; time ml lab3; command -v stress-ng; command -v apptainer; command -v all_reduce_perf || true'

echo "[versions]"
sudo -iu judge bash -lc 'ml lab3; stress-ng --version; apptainer --version; all_reduce_perf -h | head -5 || true'
