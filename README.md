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

Quick install:

```
kubectl create namespace clutta-scan
kubectl -n clutta-scan create secret generic clutta-scan-credentials \
  --from-file=auth.json=$HOME/.clutta/auth.json

helm install clutta-scan clutta/clutta-scan \
  --namespace clutta-scan \
  --set credentials.existingSecretName=clutta-scan-credentials
```

The Secret holds the auth.json file you get from running `clutta login` on your laptop. The CLI is at https://clutta.io/install.

Full values reference and tuning options are in the chart's own README under `clutta-scan/README.md`.

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
git push
```

GitHub Pages serves `index.yaml` from the repo root within about a minute of the push.

## Versioning

Two version numbers per chart:

`version` (chart SemVer) bumps when the chart shape changes: template edits, values schema changes, RBAC changes. A chart user pinning to a version pins this.

`appVersion` bumps when the underlying clutta binary version changes. It matches the image tag pushed to Docker Hub by the `release-clutta-scan-image` workflow in the main monorepo. Bump this in lockstep with the `clutta-incident-v*` git tag before tagging.

## Reporting issues

Charts mirror the upstream binary. Behaviour bugs go to the main repo. Chart packaging bugs (helm install fails, image pull errors, template rendering issues) belong here.
