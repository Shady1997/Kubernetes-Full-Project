#!/usr/bin/env bash
# 02-status.sh
# Quick health overview across the lab — a good "first look" command
# when you start a debugging session. Works in both kind mode and
# existing-cluster mode (auto-detected via lib-env.sh).
set -euo pipefail
cd "$(dirname "$0")"
source ./lib-env.sh

CONTEXTS="$CTX1"
[ "$CTX1" != "$CTX2" ] && CONTEXTS="$CTX1 $CTX2"
LAB_NAMESPACES="frontend backend database monitoring"

for ctx in $CONTEXTS; do
  echo "==================================================================="
  echo " Context: $ctx"
  echo "==================================================================="

  echo -e "\n--- Nodes ---"
  kubectl --context "$ctx" get nodes -o wide

  for ns in $LAB_NAMESPACES; do
    kubectl --context "$ctx" get namespace "$ns" >/dev/null 2>&1 || continue
    echo -e "\n--- Namespace: $ns ---"
    echo "Pods:"
    kubectl --context "$ctx" get pods -n "$ns" -o wide
    echo "Services:"
    kubectl --context "$ctx" get svc -n "$ns"
    echo "Endpoints:"
    kubectl --context "$ctx" get endpoints -n "$ns"
  done

  echo -e "\n--- Events (last 20, sorted by time) ---"
  kubectl --context "$ctx" get events -A --sort-by=.lastTimestamp | tail -n 20
  echo
done
