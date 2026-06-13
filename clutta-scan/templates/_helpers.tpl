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
