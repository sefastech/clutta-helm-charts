# Clutta Scan

This chart deploys one Clutta Scan pod per Kubernetes node. The public
configuration describes operator intent: where Clutta may collect evidence,
whether Analyze may run automatically, and where results are sent. Detection
policy and Clutta's internal vocabulary are managed by the product.

## Install

Create an installation key in Clutta, then store it in a Kubernetes Secret.
Avoid mounting a developer's complete login file for new installations. The
key identifies the workspace. The Scan configuration identifies the project.

```bash
kubectl create namespace clutta
kubectl create secret generic clutta-scan-credentials \
  --namespace clutta \
  --from-literal=api-key="$CLUTTA_API_KEY"

helm repo add clutta https://raw.githubusercontent.com/sefastech/clutta-helm-charts/main
helm repo update clutta
helm install clutta-scan clutta/clutta-scan \
  --namespace clutta \
  --set-string scope.projectId="$CLUTTA_PROJECT_ID"

kubectl -n clutta rollout status daemonset/clutta-scan
kubectl -n clutta logs -l app.kubernetes.io/name=clutta-scan --tail=50
```

If `scope.projectId` is empty, the installation appears in the workspace's
default project. Catalog rejects a project ID from another workspace.

## Public configuration

The chart renders a versioned `scan.yaml` contract:

```yaml
version: 2
scope:
  project_id: 11111111-1111-4111-8111-111111111111
  namespaces:
    exclude:
      - kube-system
      - kube-public
      - kube-node-lease
collection:
  mode: kubernetes
analysis:
  mode: manual
connection:
  mode: cloud
```

Use Helm values to change this contract. A `values.schema.json` file rejects
unknown fields and invalid modes before installation.

| Value | Default | Purpose |
| --- | --- | --- |
| `scope.projectId` | empty | Project that receives this installation; empty uses the workspace default |
| `scope.namespaces.exclude` | Kubernetes system namespaces | Namespaces Clutta must not observe |
| `collection.mode` | `kubernetes` | Evidence source: `kubernetes`, `host`, or `auto` |
| `analysis.mode` | `manual` | `manual` records evidence; `automatic` may invoke Analyze |
| `connection.mode` | `cloud` | `cloud` syncs evidence; `local` keeps the daemon offline |
| `connection.backendUrl` | `https://api.clutta.io` | Clutta API URL for a cloud connection |
| `telemetry.enabled` | `true` | Product telemetry switch |
| `persistence.enabled` | `false` | Preserve node-local Scan state across pod replacement |

Example:

```bash
helm upgrade --install clutta-scan clutta/clutta-scan \
  --namespace clutta \
  --set analysis.mode=automatic \
  --set persistence.enabled=true
```

## Collection modes

`kubernetes` is the default. It reads workload logs and state through the
Kubernetes API and does not mount the node's `/var/log` directory.

`host` reads `collection.hostLogs.path` and does not request Kubernetes API
access. The directory is mounted read-only and must already exist.

`auto` enables Kubernetes and host collection. Use it only when both sources
are intentionally required or while migrating an older deployment.

## Security model

The default pod runs as uid/gid 65532 with no Linux capabilities, no privilege
escalation, a read-only root filesystem, and the runtime-default seccomp
profile. The Kubernetes mode creates read-only cluster RBAC for namespaces,
pods, pod logs, and events. Host mode creates no Clutta ServiceAccount or RBAC
objects.

Set `rbac.create=false` only when equivalent access is managed separately, and
set `rbac.serviceAccountName` when the access belongs to a non-default account.
Credential values belong in the referenced Secret, never in `values.yaml` or
`extraEnv` literals.

## Persistent state

State is ephemeral by default for upgrade compatibility. To preserve local
queues, checkpoints, and installation identity across pod replacement, prepare
the directory on every selected node:

```bash
sudo install -d -o 65532 -g 65532 -m 0700 /var/lib/clutta-scan
```

Then set:

```yaml
persistence:
  enabled: true
  hostPath: /var/lib/clutta-scan
```

The chart uses `hostPath.type: Directory`, so a missing directory fails closed
instead of creating a root-owned path that the non-root process cannot use.

## Health and coverage

Startup and liveness probes verify that the daemon is publishing fresh state.
The readiness probe additionally requires realtime phase and complete source
coverage. Inspect rollout or source failures with:

```bash
kubectl -n clutta get pods -l app.kubernetes.io/name=clutta-scan
kubectl -n clutta logs -l app.kubernetes.io/name=clutta-scan --tail=100
```

## Migrating an existing installation

Existing Secrets containing `auth.json` continue to work through
`credentials.authJsonKey`. Replace them with project-bound `api-key` Secrets
when practical.

The deprecated `scanConfig` value accepts an existing unversioned runtime file
verbatim during migration:

```bash
helm upgrade --install clutta-scan clutta/clutta-scan \
  --namespace clutta \
  --set-file scanConfig=./scan.yaml
```

When `scanConfig` is set, the chart preserves the previous Kubernetes and host
collection behavior. Remove it after expressing the deployment with the typed
values above. The compatibility field is scheduled for removal in the next
major chart version.
