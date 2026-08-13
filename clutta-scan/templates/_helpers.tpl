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

{{/* True when the deprecated raw runtime configuration is in use. */}}
{{- define "clutta-scan.legacyConfig" -}}
{{- if ne (trim .Values.scanConfig) "" -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/* Kubernetes access remains enabled for legacy configurations. */}}
{{- define "clutta-scan.kubernetesEnabled" -}}
{{- if eq (include "clutta-scan.legacyConfig" .) "true" -}}
true
{{- else if or (eq .Values.collection.mode "kubernetes") (eq .Values.collection.mode "auto") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/* Host logs remain mounted for legacy configurations and explicit modes. */}}
{{- define "clutta-scan.hostLogsEnabled" -}}
{{- if eq (include "clutta-scan.legacyConfig" .) "true" -}}
true
{{- else if or (eq .Values.collection.mode "host") (eq .Values.collection.mode "auto") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/* A legacy hostLogPath override wins during upgrades. */}}
{{- define "clutta-scan.hostLogPath" -}}
{{- if .Values.hostLogPath -}}
{{- .Values.hostLogPath -}}
{{- else -}}
{{- .Values.collection.hostLogs.path -}}
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
Resolved imagePullPolicy. Picks the safe default for the tag the chart
will actually deploy, while letting an operator override either way.

  values.image.pullPolicy explicit     -> use it verbatim
  resolved tag == "latest"             -> Always (re-pull every restart)
  any other resolved tag (pinned semver, immutable by convention)
                                       -> IfNotPresent (skip the registry round-trip)

Lab caught this: with the chart defaulting to IfNotPresent AND a node
already cached :latest, an "upgrade" silently kept running the old image
because the new :latest content was never fetched. Letting the helper
pick "Always" whenever the tag is mutable closes that loophole at the
template layer rather than asking every operator to remember the rule.
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
