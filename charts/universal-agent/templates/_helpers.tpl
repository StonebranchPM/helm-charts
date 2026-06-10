{{/* ============================================================================
   Platform detection helpers
   ============================================================================ */}}

{{/* True when running on OpenShift (explicit platform flag OR Route API present) */}}
{{- define "ua.isOpenShift" -}}
{{- or (eq .Values.platform "openshift") (.Capabilities.APIVersions.Has "route.openshift.io/v1") -}}
{{- end -}}

{{/* True when running on AKS */}}
{{- define "ua.isAKS" -}}
{{- eq .Values.platform "aks" -}}
{{- end -}}

{{/* ============================================================================
   Basic name helpers
   ============================================================================ */}}

{{- define "universal-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "universal-agent.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "universal-agent.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "universal-agent.nameLabel" -}}
{{- $raw := include "universal-agent.name" . -}}
{{- $s := $raw | lower | replace " " "-" -}}
{{- $s = $s | regexReplaceAll "[^a-z0-9._-]" "" -}}
{{- $s = $s | trimPrefix "-" | trimSuffix "-" | trimPrefix "_" | trimSuffix "_" | trimPrefix "." | trimSuffix "." -}}
{{- $s -}}
{{- end -}}

{{/* ============================================================================
   Label helpers
   ============================================================================ */}}

{{- define "universal-agent.labels" -}}
app.kubernetes.io/name: {{ include "universal-agent.nameLabel" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | replace " " "-" | regexReplaceAll "[^A-Za-z0-9._-]" "" }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "universal-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "universal-agent.nameLabel" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* ============================================================================
   Utility helpers
   ============================================================================ */}}

{{- define "uc.safeName" -}}
{{- $s := regexReplaceAll "[^a-z0-9-]" (lower .) "-" -}}
{{- $s | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uac.emitIfSet" -}}
{{- $v := .value -}}
{{- if not (kindIs "invalid" $v) -}}
  {{- if kindIs "string" $v -}}
    {{- if ne $v "" -}}
{{ .name }}: {{ $v | quote }}
    {{- end -}}
  {{- else if kindIs "bool" $v -}}
{{ .name }}: {{ ternary "true" "false" $v | quote }}
  {{- else -}}
    {{- if not (empty $v) -}}
{{ .name }}: {{ printf "%v" $v | quote }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
