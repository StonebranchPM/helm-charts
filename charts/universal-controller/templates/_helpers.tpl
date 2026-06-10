{{/* Platform detection */}}
{{- define "uc.isOpenShift" -}}
{{- or (eq .Values.platform "openshift") (.Capabilities.APIVersions.Has "route.openshift.io/v1") -}}
{{- end -}}

{{- define "uc.isAKS" -}}
{{- eq .Values.platform "aks" -}}
{{- end -}}

{{- define "uc.isNative" -}}
{{- eq .Values.platform "native" -}}
{{- end -}}

{{/* Effective namespace helpers (native supports per-component overrides) */}}
{{- define "oms.namespace" -}}
{{- default .Release.Namespace .Values.oms.namespace -}}
{{- end -}}

{{- define "uc.namespace" -}}
{{- default .Release.Namespace .Values.uc.namespace -}}
{{- end -}}

{{/* Name helpers */}}
{{- define "universal-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "universal-controller.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "universal-controller.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "universal-controller.nameLabel" -}}
{{- $raw := include "universal-controller.name" . -}}
{{- $s := $raw | lower | replace " " "-" -}}
{{- $s = $s | regexReplaceAll "[^a-z0-9._-]" "" -}}
{{- $s = $s | trimPrefix "-" | trimSuffix "-" | trimPrefix "_" | trimSuffix "_" | trimPrefix "." | trimSuffix "." -}}
{{- $s -}}
{{- end -}}

{{- define "universal-controller.labels" -}}
app.kubernetes.io/name: {{ include "universal-controller.nameLabel" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | replace " " "-" | regexReplaceAll "[^A-Za-z0-9._-]" "" }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "universal-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "universal-controller.nameLabel" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "universal-controller.serviceAccountName" -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}

{{/* Secret name: existingSecret > keyvault > chart-managed */}}
{{- define "uc.passwordSecretName" -}}
{{- if .Values.credentials.existingSecret -}}
{{- .Values.credentials.existingSecret -}}
{{- else if .Values.keyVault.enabled -}}
{{- printf "%s-keyvault-passwords" .Release.Name -}}
{{- else -}}
{{- printf "%s-passwords" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "uc.safeName" -}}
{{- $s := regexReplaceAll "[^a-z0-9-]" (lower .) "-" -}}
{{- $s | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uac.emitIfSet" -}}
{{- $v := .value -}}
{{- if not (kindIs "invalid" $v) -}}
  {{- if kindIs "string" $v -}}
    {{- if ne $v "" }}
  {{ .name }}: {{ $v | quote }}
    {{- end -}}
  {{- else if kindIs "bool" $v }}
  {{ .name }}: {{ ternary "true" "false" $v | quote }}
  {{- else -}}
    {{- if not (empty $v) }}
  {{ .name }}: {{ printf "%v" $v | quote }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
