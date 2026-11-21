{{- define "ircord.name" -}}
{{- if gt (len .Release.Name) 38 -}}
{{- printf "%s-%s" (.Release.Name | trunc 30 | trimSuffix "-") (.Release.Name | sha256sum | trunc 7) -}}
{{- else -}}
{{- .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "ircord.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}

{{- define "ircord.labels" -}}
app.kubernetes.io/name: ircord
app.kubernetes.io/instance: {{ .root.Release.Name | quote }}
app.kubernetes.io/component: {{ .component | quote }}
{{- end -}}

{{- define "ircord.security" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
{{- end -}}

{{- define "ircord.claimName" -}}
{{- default (printf "%s-%s-data" (include "ircord.name" .root) .component) .persistence.existingClaim -}}
{{- end -}}

{{- define "ircord.mediaEndpoint" -}}
{{- if eq .Values.media.mode "bundled" -}}
{{- printf "http://%s-rustfs:9000" (include "ircord.name" .) -}}
{{- else -}}
{{- required "media.endpoint is required with external media" .Values.media.endpoint -}}
{{- end -}}
{{- end -}}

{{- define "ircord.mediaCredentials" -}}
- name: {{ .accessEnv }}
  valueFrom:
    secretKeyRef:
      name: {{ required "media.credentials.existingSecret is required with media storage" .root.Values.media.credentials.existingSecret | quote }}
      key: {{ .root.Values.media.credentials.accessKey | quote }}
- name: {{ .secretEnv }}
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.media.credentials.existingSecret | quote }}
      key: {{ .root.Values.media.credentials.secretKey | quote }}
{{- end -}}

{{- define "ircord.pullSecrets" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
