# clutta-scan

Deploys the Clutta scan daemon as a Kubernetes DaemonSet. One pod per node, each watching node-local logs (via a `hostPath` mount of `/var/log`), polling the Kubernetes API for events and pod state, and syncing findings to the Clutta backend.

## Install

```bash
# 1. Create the credentials Secret from your local clutta login.
clutta login
kubectl create namespace clutta
kubectl create secret generic clutta-scan-credentials \
  --namespace clutta \
  --from-file=auth.json=$HOME/.clutta/auth.json

# 2. Install the chart.
helm install clutta-scan ./k8s/helm/clutta-scan \
  --namespace clutta

# 3. Verify.
kubectl -n clutta get daemonset clutta-scan
kubectl -n clutta logs -l app.kubernetes.io/name=clutta-scan --tail=50
```

## Customise

Override `values.yaml` defaults at install time:

```bash
helm install clutta-scan ./k8s/helm/clutta-scan \
  --namespace clutta \
  --set image.tag=0.1.1 \
  --set-file scanConfig=./my-scan.yaml
```

Common tweaks:

- **Live mode**: edit `scanConfig.diagnose.dry_run` to `false`. Default is `true` so fresh installs never consume credits without operator opt-in.
- **Exclude noisy namespaces**: extend `scanConfig.exclude.namespaces`.
- **Tighten resources**: adjust `resources.requests` and `resources.limits`.
- **Keep scan off control-plane**: remove the master tolerations from `values.yaml`.

## What it watches

| Source        | How                                                                      |
|---------------|--------------------------------------------------------------------------|
| Filesystem    | `hostPath` mount of `/var/log` (default), read by the file provider      |
| Kubernetes    | Kubernetes API (namespaces, pods, events) via the ServiceAccount, using client-go in-process |
| systemd-journal | Not available inside the container; gracefully skipped                 |

## RBAC

The chart creates a `ClusterRole` with `get + list` on `pods`, `events`, and `namespaces` cluster-wide. Set `rbac.create=false` if your cluster manages RBAC out-of-band.

## Coverage

Per-pod coverage (how many sources each scan instance is actually subscribed to vs how many failed silently) appears in the daemon log on every transition (`coverage: N/M source(s) running`) and in `clutta scan status`. A WARN line names the failure when a source drops.

Cluster-wide coverage (how many nodes are running scan vs how many should be) is an operator-side check. A single pod cannot know about its siblings:

```bash
# pods vs nodes — should match for a healthy DaemonSet roll-out.
kubectl -n clutta get pods -l app.kubernetes.io/name=clutta-scan -o wide
kubectl get nodes
```

If the pod count is lower than the schedulable node count, a node is unreachable, tainted in a way the DaemonSet auto-tolerations don't cover, or hitting a scheduling constraint.

## State persistence

Per-pod state (PID, log, findings, cost, sync) lives in an `emptyDir` volume. On pod restart, the installation_id resets and any unsynced findings re-emit; the backend dedups by Finding.ID.

To persist state across restarts, swap the `clutta-state` volume for a `hostPath` or PVC (chart change required; not currently a values knob).
