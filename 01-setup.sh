#!/usr/bin/env bash
# 01-setup.sh
# Builds the Kubernetes debugging lab. Two modes, auto-detected:
#   - "kind" mode: creates 2 separate local clusters (debug-cluster-1, debug-cluster-2)
#     when Docker + kind are available.
#   - "existing" mode: deploys everything onto whatever cluster your current
#     kubectl context already points to (e.g. a running k3s server) — no
#     Docker/kind required. Namespaces keep workloads isolated.
set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "\n${CYAN}==> $1${NC}"; }

source ./lib-env.sh   # sets LAB_MODE, CTX1, CTX2

if [ "$LAB_MODE" = "kind" ]; then
  step "Creating cluster: debug-cluster-1"
  if kind get clusters 2>/dev/null | grep -qx debug-cluster-1; then
    echo "debug-cluster-1 already exists, skipping creation."
  else
    kind create cluster --config manifests/kind-cluster-1.yaml
  fi

  step "Creating cluster: debug-cluster-2"
  if kind get clusters 2>/dev/null | grep -qx debug-cluster-2; then
    echo "debug-cluster-2 already exists, skipping creation."
  else
    kind create cluster --config manifests/kind-cluster-2.yaml
  fi
else
  step "Using existing cluster (context: $CTX1) — no clusters created"
  kubectl --context "$CTX1" get nodes -o wide
fi

step "Deploying workloads (frontend/backend/database) to context: $CTX1"
kubectl --context "$CTX1" apply -f manifests/00-namespaces.yaml
for f in manifests/0[1-9]-*.yaml manifests/10-*.yaml; do
  echo "  applying $f"
  kubectl --context "$CTX1" apply -f "$f"
done

step "Deploying monitoring workloads to context: $CTX2"
kubectl --context "$CTX2" apply -f manifests/20-cluster2-monitoring.yaml

step "Waiting a few seconds for the scheduler to place pods..."
sleep 5

step "Contexts in use"
echo "  cluster-1 workloads -> $CTX1"
echo "  cluster-2 workloads -> $CTX2"

echo -e "\n${GREEN}Lab is up.${NC}"
if [ "$LAB_MODE" = "kind" ]; then
  echo "Switch clusters with:"
  echo "  kubectl config use-context $CTX1"
  echo "  kubectl config use-context $CTX2"
fi
echo
echo "Start debugging with:"
echo "  kubectl get pods -A --context $CTX1"
[ "$CTX1" != "$CTX2" ] && echo "  kubectl get pods -A --context $CTX2"
echo
echo "See README.md for the full list of broken scenarios and hints."
