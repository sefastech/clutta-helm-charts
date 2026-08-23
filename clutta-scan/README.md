# Clutta Scan Helm chart

The official Helm chart for running Clutta Scan on Kubernetes. It deploys one
least-privileged Scan pod per eligible node and connects the installation to a
project in [Clutta Cloud](https://app.clutta.io).

Scan observes the evidence your workloads already produce. The public
configuration stays intentionally small: what Scan may collect, whether
Analyze may run automatically, and whether evidence may sync to Clutta Cloud.

## Prerequisites

- A Kubernetes cluster
- Helm 3 or Helm 4
- A Clutta workspace, project, and API key

Open the project in Clutta Cloud and select **Scan > Connections > Kubernetes**
to generate a setup command with the correct workspace, project, key, and
current Scan image.

## Install

The generated setup follows this structure. Keep credentials in a Kubernetes
Secret, not in Helm values or a values file.

```bash
kubectl create namespace clutta --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic clutta-scan-credentials \
  --namespace clutta \
  --from-literal=api-key="$CLUTTA_API_KEY" \
  --from-literal=workspace-id="$CLUTTA_WORKSPACE_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add clutta https://sefastech.github.io/clutta-helm-charts --force-update
helm repo update clutta
helm upgrade --install clutta-scan clutta/clutta-scan \
  --namespace clutta \
  --set-string scope.projectId="$CLUTTA_PROJECT_ID"

kubectl -n clutta rollout status daemonset/clutta-scan
kubectl -n clutta logs -l app.kubernetes.io/name=clutta-scan --tail=50
```

Clutta Cloud resolves the workspace from the API key and verifies the supplied
workspace and project boundaries. If `scope.projectId` is empty, the
installation uses the workspace's default project.

The published Scan image supports both `linux/amd64` and `linux/arm64`. Docker
chooses the matching image automatically on Intel, AMD, and ARM64 hosts. If a
private registry mirror is used, mirror both platforms for each image tag.

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
| `connection.proxy.httpsProxy` | empty | Optional HTTPS proxy for outbound Clutta Cloud traffic |
| `connection.proxy.noProxy` | empty | Optional hosts that bypass the HTTPS proxy |
| `telemetry.enabled` | `true` | Product telemetry switch |
| `persistence.enabled` | `false` | Preserve node-local Scan state across pod replacement |

Show all supported values and defaults:

```bash
helm show values clutta/clutta-scan
```

Example override:

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
are intentionally required.

## Security model

The default pod runs as uid/gid 65532 with no Linux capabilities, no privilege
escalation, a read-only root filesystem, and the runtime-default seccomp
profile. The Kubernetes mode creates read-only cluster RBAC for namespaces,
pods, pod logs, and events. Host mode creates no Clutta ServiceAccount or RBAC
objects.

Set `rbac.create=false` only when equivalent access is managed separately, and
set `rbac.serviceAccountName` when the access belongs to a non-default account.
The chart fails rendering when Kubernetes collection uses external RBAC without
a ServiceAccount name.

The container reads only the `api-key` and `workspace-id` entries from the
referenced Secret. It does not mount the complete Secret into the filesystem.

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

## Upgrade from chart 0.2

Chart 0.3 removes the deprecated `auth.json`, `scanConfig`, `hostLogPath`,
`env`, and `extraEnv` compatibility values. Before upgrading, recreate the
credential Secret with the API key and workspace ID shown in Clutta Cloud:

```bash
kubectl create secret generic clutta-scan-credentials \
  --namespace clutta \
  --from-literal=api-key="$CLUTTA_API_KEY" \
  --from-literal=workspace-id="$CLUTTA_WORKSPACE_ID" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Express Scan behavior through the typed values documented above, then run the
normal `helm upgrade --install` command.

## Uninstall

```bash
helm uninstall clutta-scan --namespace clutta
```

Helm removes the DaemonSet and chart-managed RBAC. The credential Secret and
any host persistence directory remain under your control.

## Support

- [Clutta documentation](https://docs.clutta.io)
- [Open an issue](https://github.com/sefastech/clutta-helm-charts/issues)
- Security reports: [support@clutta.io](mailto:support@clutta.io)
