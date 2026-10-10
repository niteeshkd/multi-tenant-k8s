#!/usr/bin/env bash
# Create a 3-node kind cluster (1 control-plane + 2 workers) on Ubuntu 24.04.
# Usage:  bash setup-kind.sh        (run from the folder containing kind-orchestra.yaml)
set -euo pipefail

KIND_VERSION=v0.29.0
KUBECTL_VERSION=v1.33.1
ARCH=$(dpkg --print-architecture)   # amd64 or arm64

# 1. Docker Engine
if ! command -v docker >/dev/null; then
  echo ">> Installing Docker"
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo ">> Added $USER to the docker group. Log out and back in (or run 'newgrp docker'), then re-run this script."
  exit 0
fi

# 2. kind
if ! command -v kind >/dev/null; then
  echo ">> Installing kind $KIND_VERSION"
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
fi

# 3. kubectl
if ! command -v kubectl >/dev/null; then
  echo ">> Installing kubectl $KUBECTL_VERSION"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi

# 4. Raise inotify limits (multi-node kind clusters fail with "too many open files" otherwise)
echo ">> Raising inotify limits"
sudo tee /etc/sysctl.d/99-kind.conf >/dev/null <<'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF
sudo sysctl --system >/dev/null

# 5. Create the cluster
if kind get clusters | grep -qx orchestra; then
  echo ">> Cluster 'orchestra' already exists"
else
  kind create cluster --config kind-orchestra.yaml --wait 180s
fi

# 6. Verify
kubectl cluster-info --context kind-orchestra
kubectl get nodes -L tenant -o wide
