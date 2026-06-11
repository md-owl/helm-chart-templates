{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "deploy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "deploy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- if .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "deploy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "deploy.labels" -}}
app.kubernetes.io/name: {{ include "deploy.name" . }}
helm.sh/chart: {{ include "deploy.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.extraLabels }}
{{ toYaml .Values.extraLabels }}
{{- end }}
{{- end }}

{{- define "deploy.annotations" -}}
{{- if .Values.extraAnnotations }}
{{- toYaml .Values.extraAnnotations }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "deploy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "deploy.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

/*{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.imageCredentials.registry .Values.imageCredentials.username .Values.imageCredentials.password | b64enc }}*/

{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end -}}

{{- define "slugify" -}}
{{- regexReplaceAll "-+" (regexReplaceAll "[^A-Za-z0-9-]" . "-") "-" | trimAll "-" | trunc 63 | lower -}}
{{- end -}}

{{- define "csivolume" -}}

{{- if .Values.csiVault.csivolume }}
{{- range .Values.csiVault.csivolume }}
{{- if .enabled -}}
- name: {{ .name }}
{{- toYaml .volume | nindent 2 }}
{{ end }}
{{ end }}
{{ end }}

{{ end }}

{{- define "volumes" -}}

{{ if .Values.persistence.volumes -}}
{{ range .Values.persistence.volumes }}
{{- if .enabled -}}
- name: {{ .name }}
{{- toYaml .volume | nindent 2 -}}
{{ end }}
{{ end }}
{{ end }}

{{- if .Values.confFiles  }}
{{- range .Values.confFiles.mounts }}
- name: conffiles-{{ include "slugify" .mountPath }}
  secret:
    {{- if .secretName }}
    secretName: {{ .secretName }}
    {{- else }}
    secretName: {{ include "deploy.fullname" $ }}-conffiles
    {{- end }}
    {{- if .items }}
    items:
        {{- range .items }}
        - key: {{ .key | quote }}
        path: {{ .path | quote }}
        {{- if .mode }}
        mode: {{ .mode | quote }}
        {{- end }}
        {{- end }}
    {{- end }}
{{- end }}
{{- if .Values.sidecars }}
{{- range $sidecarname, $sidecar := .Values.sidecars }}
{{- if $sidecar.confFileMounts }}
{{- range $sidecar.confFileMounts }}
- name: conffiles-{{ include "slugify" (printf "%s-%s" $sidecarname .mountPath) }}
  secret:
    {{- if .secretName }}
    secretName: {{ .secretName }}
    {{- else }}
    secretName: {{ include "deploy.fullname" $ }}-conffiles
    {{- end }}
    {{- if .items }}
    items:
        {{- range .items }}
        - key: {{ . | quote }}
        path: {{ . | quote }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- if .Values.persistence.extraVolumes }}
{{- with .Values.persistence.extraVolumes -}}
{{- toYaml . }}
{{- end }}
{{- end }}
{{- end }}


{{- define "mounts" -}}

{{- if .Values.persistence.VolumeMounts }}
{{- toYaml .Values.persistence.VolumeMounts }}
{{- end }}


{{- if .Values.persistence.extraVolumeMounts }}
{{- with .Values.persistence.extraVolumeMounts -}}
{{- toYaml . }}
{{- end }}
{{- end }}


{{- if .Values.confFiles  -}}
{{- range .Values.confFiles.mounts }}
- name: conffiles-{{ include "slugify" .mountPath }}
  mountPath: {{ .mountPath }}
  {{- if .subPath }}
  subPath: "{{ .subPath }}"
  {{- end }}
{{- end -}}
{{- end -}}

{{- end -}}

{{- define "csiVolumeMount" -}}

{{- if .Values.csiVault.VolumeMounts }}
{{- toYaml .Values.csiVault.VolumeMounts }}
{{- end }}

{{- end }}


{{- define "extramanifests" -}}
{{ if .Values.renderExtraManifests }}
{{- range $path, $_ :=  .Files.Glob  "files/extramanifests/*.yaml" }}
---
      {{ $.Files.Get $path }}
{{- end }}
{{- end }}
{{- end }}

{{/*
VaultStaticSecret function
*/}}
{{- define "VaultStaticSecret" }}
{{- with .Values.vault.staticsecret -}}
  {{- toYaml . | nindent 2 }}
{{- end }}
  vaultAuthRef: {{ include "deploy.fullname" $ }}-auth
  destination:
    name: {{ include "deploy.fullname" $ }}-secret
    create: true
{{- end }}

{{/*
VaultAuth function
*/}}
{{- define "VaultAuth" }}
{{- with .Values.vault.auth -}}
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if eq .Values.vault.auth.method "kubernetes" }}
  kubernetes:
    role: {{ .Values.vault.vaultrole }}
    serviceAccount: {{ include "deploy.fullname" $ }}-sa
{{- end }}
{{- end }}