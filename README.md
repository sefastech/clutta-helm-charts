# Clutta Helm Charts

Public Helm chart repository for Clutta.

## Install

```
helm repo add clutta https://sefastech.github.io/clutta-helm-charts
helm repo update
helm search repo clutta
```

## Available charts

### clutta-scan

Continuous-mode Clutta daemon. Runs as a DaemonSet on every node in your cluster, watches pod logs and Kubernetes events, and ships pulse and candidate records to the Clutta backend.

Prerequisites:

1. Run `clutta login` on your laptop to generate `~/.clutta/auth.json`. The CLI is at https://clutta.io/install.
2. Make sure the Clutta image for your chart's appVersion exists publicly on Docker Hub. Chart appVersion `vX.Y.Z` resolves to `sefastech/clutta-scan:vX.Y.Z`. If you tagged a release but the image workflow has not finished publishing yet, `helm install` will fail with `ImagePullBackOff`. Wait for the image push, then install.

Install:

```
kubectl create secret generic clutta-scan-credentials \
  --namespace clutta-scan \
  --from-file=auth.json=$HOME/.clutta/auth.json \
  --dry-run=client -o yaml | kubectl apply -f -

helm install clutta-scan clutta/clutta-scan \
  --namespace clutta-scan \
  --create-namespace
```

The Secret step is idempotent: re-running it updates the auth.json content in place rather than erroring on `AlreadyExists`. The chart's default `credentials.existingSecretName` is `clutta-scan-credentials`, which matches the Secret you just created, so no override flag is needed.

Verify the daemon is running:

```
kubectl -n clutta-scan get pods -l app.kubernetes.io/name=clutta-scan
kubectl -n clutta-scan logs -l app.kubernetes.io/name=clutta-scan -f
```

Full values reference and tuning options are in the chart's own README under `clutta-scan/README.md`.

### Troubleshooting clutta-scan

**Pod runs but daemon logs report no input sources.** The chart mounts the node's `/var/log` directory by default, which is where pod logs live on standard kubelet setups. Some clusters write pod logs elsewhere, depending on the container runtime and node layout. If your cluster uses containerd with custom paths or has pod logs at `/var/log/pods/` exclusively, override the mount path:

```
helm install clutta-scan clutta/clutta-scan \
  --namespace clutta-scan \
  --create-namespace \
  --set hostLogPath=/var/log/pods
```

Verify the path on a node first with `ls /var/log/containers/` and `ls /var/log/pods/` from a debug pod or directly on the node.

**`ImagePullBackOff` immediately after install.** The image referenced by the chart has not been published to Docker Hub yet, or the Docker Hub repo is private. Confirm visibility at https://hub.docker.com/r/sefastech/clutta-scan and that a tag matching the chart's `appVersion` exists.

**`error: secret "clutta-scan-credentials" not found`.** The Secret creation step was skipped or used a different name. Re-run the kubectl create command, or override `credentials.existingSecretName` to match the Secret you actually created.

## Repository layout

```
README.md           This file
index.yaml          Helm catalogue, regenerated on every chart update
clutta-scan/        Chart source (for review and local builds)
charts/             Packaged chart .tgz files served by GitHub Pages
```

## Adding or updating a chart

From the chart source directory, package it and regenerate the index:

```
helm package ./clutta-scan --destination charts/
helm repo index . --url https://sefastech.github.io/clutta-helm-charts
git add charts/ index.yaml
git commit -m "Publish clutta-scan <version>"
git push origin HEAD
```

GitHub Pages serves `index.yaml` from the repo root within about a minute of the push. Using `HEAD` in the push avoids the assumption that your local branch is named `main`. If the remote is empty and you need to set the default branch name explicitly, run `git branch -M main` before the first push.

## Pinning the image

The chart defaults to `image.tag=""`, which resolves to the chart's `appVersion` (a pinned `vX.Y.Z`). That's the safe default: every release ships an immutable tag, the pull policy defaults to `IfNotPresent`, and your nodes cache the right thing.

Avoid `--set image.tag=latest` in production. `latest` is a mutable tag — each release overwrites its content — and a node that already pulled `:latest` once will silently keep running the old image under `IfNotPresent`. The chart's pullPolicy helper automatically switches to `Always` if you set `tag=latest`, but the right move is to pin a real version anyway. Use `latest` only for short-lived dev clusters where you intentionally want the freshest binary.

## Versioning

Two version numbers per chart:

`version` (chart SemVer) bumps when the chart shape changes: template edits, values schema changes, RBAC changes. A chart user pinning to a version pins this.

`appVersion` bumps when the underlying clutta binary version changes. It matches the image tag pushed to Docker Hub by the `release-clutta-scan-image` workflow in the main monorepo. Bump this in lockstep with the `clutta-incident-v*` git tag before tagging.

## Reporting issues

Charts mirror the upstream binary. Behaviour bugs go to the main repo. Chart packaging bugs (helm install fails, image pull errors, template rendering issues) belong here.
