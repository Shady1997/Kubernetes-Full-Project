#!/usr/bin/env bash
# 99-cleanup.sh
# Tears down the lab. In kind mode, deletes both local clusters.
# In existing-cluster mode, deletes only the namespaces/resources the lab
# created (frontend/backend/database/monitoring) — leaves your k3s server
# and any other workloads untouched.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib-env.sh

if [ "$LAB_MODE" = "kind" ]; then
  echo "This will delete kind clusters: debug-cluster-1, debug-cluster-2"
  read -r -p "Continue? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
  kind delete cluster --name debug-cluster-1 || true
  kind delete cluster --name debug-cluster-2 || true
  echo "Done. Both clusters removed."
else
  echo "This will delete namespaces on context '$CTX1': frontend, backend, database, monitoring"
  echo "(along with the cluster-scoped NetworkPolicy/PVC objects the lab created)."
  read -r -p "Continue? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
  kubectl --context "$CTX1" delete namespace frontend backend database monitoring --ignore-not-found
  echo "Done. Lab namespaces removed from $CTX1. Your cluster itself is untouched."
fi
