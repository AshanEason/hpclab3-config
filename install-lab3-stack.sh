#!/usr/bin/env bash
set -euo pipefail

role="${1:-}"
if [ "$role" != "controller" ] && [ "$role" != "cpu01" ] && [ "$role" != "gpu01" ]; then
  echo "usage: $0 controller|cpu01|gpu01" >&2
  exit 2
fi

cd "$(dirname "$0")"

LAB3_ROOT=/home/judge/opt/lab3
BUILD_ROOT=/tmp/lab3-build
APPTAINER_PREFIX="$LAB3_ROOT/apptainer-1.4.4"
STRESS_PREFIX="$LAB3_ROOT/stress-ng-0.19.04"
NCCL_PREFIX="$LAB3_ROOT/nccl-2.17.1"
NCCL_TESTS_PREFIX="$LAB3_ROOT/nccl-tests-2.17.6"

apt_install_common() {
  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates curl wget git build-essential pkg-config \
    lmod lua5.4 \
    squashfs-tools squashfuse fuse3 cryptsetup uidmap fakeroot runc \
    libseccomp-dev libglib2.0-dev libfuse3-dev libssl-dev uuid-dev \
    libgpgme-dev libdevmapper-dev libapparmor-dev golang-go
}

setup_module_files() {
  sudo install -d -o judge -g judge -m 755 /home/judge/modulefiles
  sudo install -d -o judge -g judge -m 755 "$LAB3_ROOT"
  sudo install -m 644 lab3.lua /home/judge/modulefiles/lab3.lua
  sudo install -m 644 lab3-modules.sh /etc/profile.d/lab3-modules.sh
  sudo install -m 644 osu.def /home/judge/osu.def
  sudo chown judge:judge /home/judge/osu.def

  if ! grep -q '^judge:' /etc/subuid 2>/dev/null; then
    echo 'judge:100000:65536' | sudo tee -a /etc/subuid >/dev/null
  fi
  if ! grep -q '^judge:' /etc/subgid 2>/dev/null; then
    echo 'judge:100000:65536' | sudo tee -a /etc/subgid >/dev/null
  fi
}

build_stress_ng() {
  if [ -x "$STRESS_PREFIX/bin/stress-ng" ]; then
    "$STRESS_PREFIX/bin/stress-ng" --version || true
    return
  fi

  rm -rf "$BUILD_ROOT/stress-ng"
  mkdir -p "$BUILD_ROOT"
  git clone --depth 1 --branch V0.19.04 https://github.com/ColinIanKing/stress-ng.git "$BUILD_ROOT/stress-ng"
  make -C "$BUILD_ROOT/stress-ng" -j"$(nproc)"

  sudo install -d -o judge -g judge -m 755 "$STRESS_PREFIX/bin"
  sudo install -m 755 "$BUILD_ROOT/stress-ng/stress-ng" "$STRESS_PREFIX/bin/stress-ng"
  sudo chown -R judge:judge "$STRESS_PREFIX"
  "$STRESS_PREFIX/bin/stress-ng" --version
}

build_apptainer() {
  if [ -x "$APPTAINER_PREFIX/bin/apptainer" ]; then
    "$APPTAINER_PREFIX/bin/apptainer" --version || true
    return
  fi

  rm -rf "$BUILD_ROOT/apptainer"
  mkdir -p "$BUILD_ROOT"
  git clone --depth 1 --branch v1.4.4 https://github.com/apptainer/apptainer.git "$BUILD_ROOT/apptainer"
  (
    cd "$BUILD_ROOT/apptainer"
    ./mconfig --prefix="$APPTAINER_PREFIX" --without-suid
    make -C builddir -j"$(nproc)"
    sudo make -C builddir install
  )
  sudo chown -R judge:judge "$APPTAINER_PREFIX"
  "$APPTAINER_PREFIX/bin/apptainer" --version
}

install_cuda_and_nccl_deps() {
  if ! command -v nvcc >/dev/null 2>&1 && [ ! -x /usr/local/cuda/bin/nvcc ]; then
    tmpdeb=/tmp/cuda-keyring_1.1-1_all.deb
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O "$tmpdeb"
    sudo dpkg -i "$tmpdeb"
    sudo apt-get update
    if apt-cache show cuda-toolkit-12-2 >/dev/null 2>&1; then
      sudo apt-get install -y cuda-toolkit-12-2
    elif apt-cache show nvidia-cuda-toolkit >/dev/null 2>&1; then
      sudo apt-get install -y nvidia-cuda-toolkit
    elif apt-cache show cuda-toolkit >/dev/null 2>&1; then
      sudo apt-get install -y cuda-toolkit
    else
      echo "No CUDA toolkit package found. Please install nvcc first." >&2
      exit 1
    fi
  fi

  sudo apt-get update
  sudo apt-get install -y libibverbs-dev libnuma-dev
}

cuda_make_args() {
  if [ -x /usr/local/cuda/bin/nvcc ]; then
    echo "CUDA_HOME=/usr/local/cuda CUDA_INC=/usr/local/cuda/include CUDA_LIB=/usr/local/cuda/lib64 NVCC=/usr/local/cuda/bin/nvcc NVCC_GENCODE=-gencode=arch=compute_70,code=sm_70"
    return
  fi

  for cuda_dir in /usr/local/cuda-*; do
    if [ -x "$cuda_dir/bin/nvcc" ]; then
      echo "CUDA_HOME=$cuda_dir CUDA_INC=$cuda_dir/include CUDA_LIB=$cuda_dir/lib64 NVCC=$cuda_dir/bin/nvcc NVCC_GENCODE=-gencode=arch=compute_70,code=sm_70"
      return
    fi
  done

  if command -v nvcc >/dev/null 2>&1; then
    echo "CUDA_HOME=/usr CUDA_INC=/usr/include CUDA_LIB=/usr/lib/x86_64-linux-gnu NVCC=$(command -v nvcc) NVCC_GENCODE=-gencode=arch=compute_70,code=sm_70"
    return
  fi

  echo "nvcc not found after CUDA installation" >&2
  exit 1
}

build_nccl_library() {
  if [ -f "$NCCL_PREFIX/include/nccl.h" ] && [ -f "$NCCL_PREFIX/lib/libnccl.so" ]; then
    return
  fi

  install_cuda_and_nccl_deps

  rm -rf "$BUILD_ROOT/nccl"
  mkdir -p "$BUILD_ROOT"
  git clone --depth 1 --branch v2.17.1-1 https://github.com/NVIDIA/nccl.git "$BUILD_ROOT/nccl"
  # shellcheck disable=SC2086
  make -C "$BUILD_ROOT/nccl" -j"$(nproc)" src.build $(cuda_make_args) CUDARTLIB=cudart

  sudo rm -rf "$NCCL_PREFIX"
  sudo install -d -o judge -g judge -m 755 "$NCCL_PREFIX"
  # shellcheck disable=SC2086
  sudo make -C "$BUILD_ROOT/nccl" src.install PREFIX="$NCCL_PREFIX" $(cuda_make_args) CUDARTLIB=cudart
  sudo chown -R judge:judge "$NCCL_PREFIX"
}

build_nccl_tests() {
  if [ "$role" != "gpu01" ]; then
    return
  fi
  if [ -x "$NCCL_TESTS_PREFIX/bin/all_reduce_perf" ]; then
    "$NCCL_TESTS_PREFIX/bin/all_reduce_perf" -h | head -5 || true
    return
  fi

  build_nccl_library

  rm -rf "$BUILD_ROOT/nccl-tests"
  mkdir -p "$BUILD_ROOT"
  git clone --depth 1 --branch v2.17.6 https://github.com/NVIDIA/nccl-tests.git "$BUILD_ROOT/nccl-tests"
  # shellcheck disable=SC2086
  make -C "$BUILD_ROOT/nccl-tests" -j"$(nproc)" MPI=0 NCCL_HOME="$NCCL_PREFIX" $(cuda_make_args)

  sudo install -d -o judge -g judge -m 755 "$NCCL_TESTS_PREFIX/bin"
  sudo install -m 755 "$BUILD_ROOT/nccl-tests/build/all_reduce_perf" "$NCCL_TESTS_PREFIX/bin/all_reduce_perf"
  sudo chown -R judge:judge "$NCCL_TESTS_PREFIX"
  "$NCCL_TESTS_PREFIX/bin/all_reduce_perf" -h | head -5 || true
}

apt_install_common
setup_module_files

if [ "$role" = "controller" ]; then
  build_stress_ng
  build_apptainer
elif [ "$role" = "gpu01" ]; then
  build_nccl_tests
fi

echo "Lab3 stack step finished for $role"
