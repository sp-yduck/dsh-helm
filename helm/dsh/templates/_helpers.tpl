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
{{- define "dsh.tailscaleFQDN" -}}
{{- if and .Values.tailscale.enabled .Values.tailscale.tailnet }}{{ printf "%s.%s" .Values.tailscale.hostname .Values.tailscale.tailnet }}{{ end }}
{{- end }}
{{/* Every Host header that browsers may send: explicit values plus the hosts of each enabled access path. */}}
{{- define "dsh.trustedHosts" -}}
{{- $hosts := list }}
{{- range .Values.trustedHosts }}{{ $hosts = append $hosts . }}{{ end }}
{{- if .Values.ingress.enabled }}{{ range .Values.ingress.hosts }}{{ if .host }}{{ $hosts = append $hosts .host }}{{ end }}{{ end }}{{ end }}
{{- with include "dsh.tailscaleFQDN" . }}{{ $hosts = append $hosts . }}{{ end }}
{{- if .Values.cloudflared.enabled }}{{ range .Values.cloudflared.hostnames }}{{ $hosts = append $hosts . }}{{ end }}{{ end }}
{{- toYaml ($hosts | uniq) }}
{{- end }}
{{- define "dsh.publicUrl" -}}
{{- if .Values.publicUrl }}{{ .Values.publicUrl }}
{{- else if and .Values.cloudflared.enabled .Values.cloudflared.hostnames }}{{ printf "https://%s/" (first .Values.cloudflared.hostnames) }}
{{- else if include "dsh.tailscaleFQDN" . }}{{ printf "https://%s/" (include "dsh.tailscaleFQDN" .) }}
{{- end }}
{{- end }}
