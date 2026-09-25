#!/usr/bin/env bash
# 00-check-prereqs.sh
# kubectl is always required. Docker + kind are OPTIONAL: if present, the lab
# runs in "kind" mode (2 separate local clusters). If absent, the lab runs in
# "existing" mode against whatever cluster your current kubectl context
# already points to (e.g. a running k3s server) — nothing extra needed.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
hard_fail=false

echo "== Checking prerequisites =="

if command -v kubectl >/dev/null 2>&1; then
  echo -e "${GREEN}[OK]${NC} kubectl found: $(command -v kubectl)"
else
  echo -e "${RED}[MISSING]${NC} kubectl not found (required in every mode)."
  hard_fail=true
fi

if command -v docker >/dev/null 2>&1 && command -v kind >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo -e "${GREEN}[OK]${NC} Docker + kind found -> lab will run in KIND mode (2 local clusters)."
else
  echo -e "${YELLOW}[INFO]${NC} Docker/kind not available -> lab will run in EXISTING-CLUSTER mode"
  echo "       (deploys onto whatever 'kubectl config current-context' already points to,"
  echo "        e.g. a running k3s server). This is fine and requires no extra install."
fi

if [ "$hard_fail" = true ]; then
  echo
  echo -e "${YELLOW}Install kubectl:${NC} https://kubernetes.io/docs/tasks/tools/#kubectl"
  exit 1
fi

if command -v kubectl >/dev/null 2>&1; then
  if kubectl cluster-info >/dev/null 2>&1; then
    ctx="$(kubectl config current-context 2>/dev/null || echo '<none>')"
    echo -e "${GREEN}[OK]${NC} kubectl can reach a cluster. Current context: $ctx"
  else
    echo -e "${YELLOW}[WARN]${NC} kubectl cannot reach a cluster on the current context yet."
    echo "       If you're relying on EXISTING-CLUSTER mode, fix this first"
    echo "       (check: kubectl get nodes / \$KUBECONFIG / /etc/rancher/k3s/k3s.yaml)."
  fi
fi

echo
echo -e "${GREEN}Prerequisite check complete.${NC}"
