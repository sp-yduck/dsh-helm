{{- define "dsh.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}{{ .Release.Name | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}{{ end }}
{{- end }}
{{- define "dsh.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "dsh.labels" -}}
{{ include "dsh.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- define "dsh.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ .Values.serviceAccount.name | default (include "dsh.fullname" .) }}{{ else }}{{ .Values.serviceAccount.name | default "default" }}{{ end }}
{{- end }}
{{- define "dsh.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.Version }}
{{- end }}
{{/* Every Host header that browsers may send: trustedHosts plus the Ingress hosts. */}}
{{- define "dsh.trustedHosts" -}}
{{- $hosts := list }}
{{- range .Values.trustedHosts }}{{ $hosts = append $hosts . }}{{ end }}
{{- if .Values.ingress.enabled }}{{ range .Values.ingress.hosts }}{{ if .host }}{{ $hosts = append $hosts .host }}{{ end }}{{ end }}{{ end }}
{{- toYaml ($hosts | uniq) }}
{{- end }}
{{- define "dsh.publicUrl" -}}
{{- .Values.publicUrl }}
{{- end }}
