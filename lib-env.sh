#!/usr/bin/env bash
# lib-env.sh
# Detects whether we can use kind (multi-cluster, Docker-based) or whether
# we should fall back to deploying everything onto an existing real cluster
# (e.g. an already-running k3s server). Sourced by the other scripts.
#
# Sets:
#   LAB_MODE  = "kind" | "existing"
#   CTX1      = kubectl context to use for the "cluster-1" workloads (frontend/backend/database)
#   CTX2      = kubectl context to use for the "cluster-2" workloads (monitoring)

detect_lab_mode() {
  if command -v kind >/dev/null 2>&1 && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    LAB_MODE="kind"
    CTX1="kind-debug-cluster-1"
    CTX2="kind-debug-cluster-2"
  else
    LAB_MODE="existing"
    if ! command -v kubectl >/dev/null 2>&1; then
      echo "ERROR: kubectl not found and kind/docker unavailable. Nothing to run against." >&2
      exit 1
    fi
    if ! kubectl cluster-info >/dev/null 2>&1; then
      echo "ERROR: kubectl cannot reach a cluster (no kind/docker, and current context is unreachable)." >&2
      echo "       Check: kubectl config current-context / kubectl get nodes" >&2
      exit 1
    fi
    CTX1="$(kubectl config current-context)"
    CTX2="$CTX1"
  fi
  export LAB_MODE CTX1 CTX2
}

detect_lab_mode

echo "Lab mode: $LAB_MODE"
if [ "$LAB_MODE" = "existing" ]; then
  echo "  -> No kind/Docker detected. Deploying everything onto your existing cluster: $CTX1"
  echo "     (namespaces frontend/backend/database/monitoring keep workloads isolated"
  echo "      from each other on this single real cluster.)"
else
  echo "  -> kind + Docker detected. Will create 2 separate local clusters: $CTX1, $CTX2"
fi
