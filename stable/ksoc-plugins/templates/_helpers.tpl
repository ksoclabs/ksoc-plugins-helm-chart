{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ksoc-plugins.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ksoc-plugins.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ksoc-plugins.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
KSOC API access key env secret
*/}}
{{- define "ksoc-plugins.access-key-env-secret" -}}
- name: KSOC_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      {{ if .Values.ksoc.accessKeySecretNameOverride -}}
      name: {{ .Values.ksoc.accessKeySecretNameOverride }}
      {{ else -}}
      name: ksoc-access-key
      {{ end -}}
      key: access-key-id
- name: KSOC_SECRET_KEY
  valueFrom:
    secretKeyRef:
      {{ if .Values.ksoc.accessKeySecretNameOverride -}}
      name: {{ .Values.ksoc.accessKeySecretNameOverride }}
      {{ else -}}
      name: ksoc-access-key
      {{ end -}}
      key: secret-key
{{- end -}}

{{/*
ksoc-bootstrap initContainer
*/}}
{{- define "ksoc-plugins.bootstrap-initcontainer" -}}
- name: ksoc-bootstrapper
  image: {{ .Values.ksocBootstrapper.image.repository }}:{{ .Values.ksocBootstrapper.image.tag }}
  imagePullPolicy: Always
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
    capabilities:
      drop:
        - ALL
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
  env:
    - name: AGENT_VERSION
      value: {{ .Values.ksocBootstrapper.image.tag | quote }}
    - name: CHART_VERSION
      value: {{ .Chart.Version }}
    - name: KSOC_API_URL
      value: {{ .Values.ksoc.apiUrl}}
    - name: KSOC_CLUSTER_NAME
      value: {{ .Values.ksoc.clusterName }}
    - name: KSOC_NAMESPACE
      value: {{ .Release.Namespace }}
{{ include "ksoc-plugins.access-key-env-secret" . | indent 4 }}
  volumeMounts:
  - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
    name: api-token
    readOnly: true
  resources:
{{ toYaml .Values.ksocBootstrapper.resources | indent 4 }}
{{- end -}}
