{{/*
Common labels for every clutta-scan resource.
*/}}
{{- define "clutta-scan.labels" -}}
app.kubernetes.io/name: clutta-scan
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* True when Kubernetes collection is enabled. */}}
{{- define "clutta-scan.kubernetesEnabled" -}}
{{- if or (eq .Values.collection.mode "kubernetes") (eq .Values.collection.mode "auto") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/* True when host log collection is enabled. */}}
{{- define "clutta-scan.hostLogsEnabled" -}}
{{- if or (eq .Values.collection.mode "host") (eq .Values.collection.mode "auto") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Selector labels (subset of full labels; immutable on existing DaemonSets).
*/}}
{{- define "clutta-scan.selectorLabels" -}}
app.kubernetes.io/name: clutta-scan
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Cluster-scoped RBAC names include the release namespace so installations with
the same release name in different namespaces do not collide.
*/}}
{{- define "clutta-scan.clusterRoleName" -}}
{{- $name := printf "%s-%s" .Release.Namespace .Release.Name -}}
{{- if le (len $name) 63 -}}
{{- $name -}}
{{- else -}}
{{- printf "%s-%s" (trimSuffix "-" (trunc 54 $name)) (trunc 8 (sha256sum $name)) -}}
{{- end -}}
{{- end -}}

{{/*
Resolved image tag: explicit values.image.tag wins, else Chart.appVersion.
*/}}
{{- define "clutta-scan.imageTag" -}}
{{- if .Values.image.tag -}}
{{- .Values.image.tag -}}
{{- else -}}
{{- .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{/*
Resolved imagePullPolicy picks the safe default for the image tag while still
allowing an explicit operator choice.

  values.image.pullPolicy explicit     -> use it verbatim
  resolved tag == "latest"             -> Always (re-pull every restart)
  any other resolved tag (pinned semver, immutable by convention)
                                       -> IfNotPresent (skip the registry round-trip)

Mutable tags must always be pulled. Immutable version tags can use the node
cache.
*/}}
{{- define "clutta-scan.imagePullPolicy" -}}
{{- $tag := include "clutta-scan.imageTag" . -}}
{{- if .Values.image.pullPolicy -}}
{{- .Values.image.pullPolicy -}}
{{- else if eq $tag "latest" -}}
Always
{{- else -}}
IfNotPresent
{{- end -}}
{{- end -}}
