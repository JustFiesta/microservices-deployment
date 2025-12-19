{{/*
Expand the name of the chart.
*/}}
{{- define "microservices-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "microservices-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservices-demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservices-demo.labels" -}}
helm.sh/chart: {{ include "microservices-demo.chart" . }}
{{ include "microservices-demo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: microservices-demo
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservices-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservices-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service-specific labels
*/}}
{{- define "microservices-demo.service.labels" -}}
app: {{ .serviceName }}
app.kubernetes.io/name: {{ .serviceName }}
app.kubernetes.io/component: {{ .component | default "backend" }}
{{ include "microservices-demo.labels" .context }}
{{- end }}

{{/*
Service-specific selector labels
*/}}
{{- define "microservices-demo.service.selectorLabels" -}}
app: {{ .serviceName }}
{{- end }}

{{/*
Generate full image name for a service
*/}}
{{- define "microservices-demo.image" -}}
{{- $registry := .context.Values.global.image.registry -}}
{{- $project := .context.Values.global.image.project -}}
{{- $name := .service.image.name -}}
{{- $tag := .service.image.tag | default .context.Values.global.image.tag -}}
{{- printf "%s/%s/%s:%s" $registry $project $name $tag }}
{{- end }}

{{/*
Generate Redis image name
*/}}
{{- define "microservices-demo.redis.image" -}}
{{- $repository := .Values.redis.image.repository -}}
{{- $tag := .Values.redis.image.tag -}}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
