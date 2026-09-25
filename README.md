# Kubernetes Multi-Cluster Debugging Lab

A local practice environment for `kubectl` debugging, built with [`kind`](https://kind.sigs.k8s.io/)
(Kubernetes-in-Docker). It spins up **two clusters**, multiple **nodes**, and a set of
namespaces/deployments/services/pods where several are **intentionally broken** in
ways you'll see constantly in real production incidents.

## Requirements

`kubectl` is the only hard requirement. The lab auto-detects your environment
and runs in one of two modes (see `lib-env.sh`):

| Mode | Trigger | What happens |
|---|---|---|
| **kind** | Docker + `kind` both installed and Docker daemon reachable | Creates 2 separate local clusters (`debug-cluster-1`, `debug-cluster-2`) |
| **existing** | Docker/`kind` missing (e.g. you're on a bare k3s server) | Deploys everything onto whatever `kubectl config current-context` already points to — no extra install needed |

If you're running this **on a k3s server** (as in `root@k3s-server`), you're
already in "existing" mode automatically — the scripts just deploy the
workloads as namespaces on your real k3s cluster.

Optional, if you'd rather have true multi-cluster isolation:
[Docker](https://docs.docker.com/get-docker/) + [`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/#installation).

## Layout

```
k8s-debug-lab/
├── 00-check-prereqs.sh    # verifies docker/kind/kubectl are installed
├── 01-setup.sh            # creates both clusters + deploys all workloads
├── 02-status.sh           # quick health dump across both clusters
├── 99-cleanup.sh          # tears everything down
├── manifests/
│   ├── kind-cluster-1.yaml / kind-cluster-2.yaml   # cluster topology (node counts)
│   ├── 00-namespaces.yaml
│   ├── 01..09-*-bug.yaml      # each file = one intentional bug (see table below)
│   ├── 10-healthy-baseline.yaml
│   └── 20-cluster2-monitoring.yaml
└── README.md
```

## Quick start

```bash
chmod +x *.sh
./01-setup.sh        # builds both clusters and deploys workloads
./02-status.sh        # see everything at a glance
```

Switch between clusters:

```bash
kubectl config use-context kind-debug-cluster-1
kubectl config use-context kind-debug-cluster-2
```

Tear down when you're done:

```bash
./99-cleanup.sh
```

## Topology

**kind mode:**

| Cluster | Nodes | Namespaces | Purpose |
|---|---|---|---|
| `debug-cluster-1` | 1 control-plane + 2 workers | `frontend`, `backend`, `database` | Main "app" cluster, most bugs live here |
| `debug-cluster-2` | 1 control-plane + 1 worker | `monitoring` | Simulates a platform/observability cluster |

**existing mode (e.g. k3s):** all four namespaces (`frontend`, `backend`,
`database`, `monitoring`) are deployed to your one real cluster. You lose the
"two separate clusters" aspect but keep every pod/service/probe/PVC/
NetworkPolicy debugging scenario — namespaces keep everything cleanly
separated.

> **k3s + NetworkPolicy note:** scenario #7 (default-deny `NetworkPolicy`)
> only gets *enforced* if your CNI supports it. k3s ships **Flannel** by
> default, which does **not** enforce NetworkPolicies — the object will apply
> successfully but traffic won't actually be blocked. To make that scenario
> real on k3s, either install [Calico](https://docs.k3s.io/networking/basic-network-options#calico)
> or a NetworkPolicy controller like [kube-router](https://github.com/cloudnativelabs/kube-router),
> or just treat #7 as a read-only exercise: "explain what this policy *would*
> do and how you'd diagnose it if it were enforced."

## The 10 debugging scenarios

Don't read the manifest comments first if you want the full exercise — just run
`./02-status.sh` and start investigating. Answers/root causes are in the YAML
comments once you're ready to check your work.

| # | Symptom you'll see | Where | Concept practiced |
|---|---|---|---|
| 1 | `ImagePullBackOff` on `frontend-web` | `frontend` ns, cluster-1 | Bad image tag |
| 2 | `CrashLoopBackOff` on `backend-api` | `backend` ns, cluster-1 | App exits non-zero, reading container logs |
| 3 | Service `cache-svc` has no Endpoints | `backend` ns, cluster-1 | Label/selector mismatch |
| 4 | `OOMKilled` restarts on `database-primary-0` | `database` ns, cluster-1 | Resource limits too low |
| 5 | Pod `Running` but never `Ready` | `frontend` ns, cluster-1 (`frontend-gateway`) | Misconfigured readiness probe |
| 6 | `CreateContainerConfigError` | `backend` ns, cluster-1 (`backend-worker`) | Missing ConfigMap |
| 7 | Connections to `backend-api-svc` time out despite healthy pods | `backend` ns, cluster-1 | NetworkPolicy default-deny |
| 8 | PVC `database-backup-pvc` stuck `Pending` | `database` ns, cluster-1 | Nonexistent StorageClass |
| 9 | Pod restarts repeatedly even though the app works | `frontend` ns, cluster-1 (`frontend-slow-start`) | Liveness probe timing too aggressive |
| 10 | `connection refused` even though Endpoints exist | `monitoring` ns, cluster-2 | Service `targetPort` mismatch |

`frontend-healthy` (cluster-1) and `metrics-collector-svc` (cluster-2, correct one)
are your **known-good** baselines — compare their `describe` output against the
broken ones.

## Suggested debugging workflow per scenario

1. `kubectl get pods -A --context <ctx>` — find what's not `Running`/`Ready`.
2. `kubectl describe pod <name> -n <ns> --context <ctx>` — check `Events` at the bottom.
3. `kubectl logs <name> -n <ns> --context <ctx> [--previous]` — read app-level errors.
4. `kubectl get endpoints <svc> -n <ns> --context <ctx>` — confirm Service has backing pods.
5. `kubectl get events -n <ns> --sort-by=.lastTimestamp --context <ctx>` — chronological view.
6. Fix the manifest in `manifests/`, then `kubectl apply -f <file> --context <ctx>` and re-check.

## Handy cheat sheet

```bash
# Cross-cluster overview
kubectl get pods -A --context kind-debug-cluster-1 -o wide
kubectl get pods -A --context kind-debug-cluster-2 -o wide

# Why is this pod not ready?
kubectl describe pod <pod> -n <ns>

# Logs (current and previous crashed container)
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous

# Shell into a pod (if it has a shell)
kubectl exec -it <pod> -n <ns> -- sh

# Test service DNS/connectivity from inside the cluster
kubectl run tmp-debug --rm -it --image=busybox:1.36 --restart=Never -n <ns> -- \
  wget -qO- http://<service-name>.<ns>.svc.cluster.local:<port>

# Check why a Service has no traffic
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>

# Resource pressure / OOM
kubectl top pod -n <ns>          # requires metrics-server (not installed by default in kind)
kubectl describe pod <pod> -n <ns> | grep -A5 "Last State"

# NetworkPolicy audit
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy <name> -n <ns>

# PVC/storage
kubectl get pvc -n <ns>
kubectl describe pvc <name> -n <ns>
kubectl get storageclass

# Node-level issues
kubectl describe node <node-name>
kubectl get events -A --field-selector involvedObject.kind=Node

# Stream events live while you fix things
kubectl get events -A --watch
```

### Optional: install metrics-server (for `kubectl top`)

kind clusters don't ship `metrics-server` by default. To enable `kubectl top`:

```bash
kubectl --context kind-debug-cluster-1 apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kind's kubelet uses self-signed certs, so patch metrics-server to skip TLS verify:
kubectl --context kind-debug-cluster-1 -n kube-system patch deployment metrics-server \
  --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

## Resetting a single scenario

Every bug lives in its own file under `manifests/`, so you can reset just one:

```bash
kubectl delete -f manifests/02-backend-crashloop-bug.yaml --context kind-debug-cluster-1
kubectl apply  -f manifests/02-backend-crashloop-bug.yaml --context kind-debug-cluster-1
```

## Extending the lab

Ideas for adding more practice scenarios:
- A `Job` with `backoffLimit` misconfigured
- An `Ingress` pointing at a nonexistent Service
- RBAC: a `ServiceAccount` missing permissions (`Forbidden` errors)
- A `HorizontalPodAutoscaler` that can't scale (missing metrics-server)
- Two Services accidentally sharing the same NodePort
- A `Deployment` with an immutable field changed (triggers a rejected update)
