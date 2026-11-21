{{- define "ircord.mediaGatewayConfig" -}}
server {
    listen 8080;
    server_name _;
    server_tokens off;

    location = /health { return 204; }
    location / { return 404; }

    location ~ "^/{{ .Values.media.prefix }}/(link-media/)?[a-f0-9]{64}$" {
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Range" always;
        add_header Access-Control-Max-Age "600" always;
        add_header X-Content-Type-Options nosniff always;
        add_header Content-Security-Policy "default-src 'none'; sandbox" always;
        add_header Cross-Origin-Resource-Policy cross-origin always;
        add_header Cache-Control "public, max-age=0, must-revalidate" always;
        proxy_hide_header Cache-Control;

        if ($request_method = OPTIONS) { return 204; }
        if ($request_method !~ ^(GET|HEAD)$) { return 403; }
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header Authorization "";
        proxy_set_header Cookie "";
        rewrite ^/(.*)$ /{{ .Values.media.bucket }}/$1? break;
        proxy_pass {{ include "ircord.mediaEndpoint" . }};
    }
}
{{- end -}}

{{- define "ircord.mediaToolPod" -}}
{{- $root := .root -}}
{{- $media := $root.Values.media -}}
metadata:
  labels:
    {{- include "ircord.labels" (dict "root" $root "component" (printf "media-%s" .task)) | nindent 4 }}
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  enableServiceLinks: false
  {{- include "ircord.pullSecrets" $root | nindent 2 }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: media
      image: {{ include "ircord.image" $media.toolingImage | quote }}
      securityContext: {{- include "ircord.security" $root | nindent 8 }}
      command: [/bin/sh, /config/media-{{ .task }}.sh]
      env:
        - {name: S3_ENDPOINT, value: {{ include "ircord.mediaEndpoint" $root | quote }}}
        - {name: S3_BUCKET, value: {{ $media.bucket | quote }}}
        - {name: MEDIA_PREFIX, value: {{ $media.prefix | quote }}}
        - {name: MEDIA_LIFECYCLE, value: {{ $media.lifecycle.enabled | quote }}}
        - {name: LIFECYCLE_DAYS, value: {{ $media.lifecycle.days | quote }}}
        - {name: EXPIRATION_RULE_ID, value: {{ $media.lifecycle.expirationRuleID | quote }}}
        - {name: DELETE_MARKER_RULE_ID, value: {{ $media.lifecycle.deleteMarkerRuleID | quote }}}
        - {name: AWS_DEFAULT_REGION, value: {{ $media.region | quote }}}
        - {name: AWS_EC2_METADATA_DISABLED, value: "true"}
        - {name: AWS_PAGER, value: ""}
        - {name: AWS_CLI_AUTO_PROMPT, value: "off"}
        {{- include "ircord.mediaCredentials" (dict "root" $root "accessEnv" "AWS_ACCESS_KEY_ID" "secretEnv" "AWS_SECRET_ACCESS_KEY") | nindent 8 }}
        {{- with $media.credentials.sessionTokenKey }}
        - name: AWS_SESSION_TOKEN
          valueFrom:
            secretKeyRef:
              name: {{ $media.credentials.existingSecret | quote }}
              key: {{ . | quote }}
        {{- end }}
      volumeMounts:
        - {name: config, mountPath: /config, readOnly: true}
        - {name: tmp, mountPath: /tmp}
  volumes:
    - name: config
      configMap:
        name: {{ include "ircord.name" $root }}-media-tools
    - name: tmp
      emptyDir: {}
{{- end -}}
