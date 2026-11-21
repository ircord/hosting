{{- define "ircord.ergoConfig" -}}
allow-environment-overrides: true
network:
  name: IRCord
server:
  name: {{ .Values.ergo.hostname | quote }}
  listeners:
    ":6697":
      min-tls-version: "1.2"
      tls: {cert: /tls/tls.crt, key: /tls/tls.key}
  max-sendq: 96k
  enforce-utf8: true
  ip-cloaking:
    enabled: true
    netname: ircord
    num-bits: 64
  ip-limits:
    count: true
    throttle: true
    max-concurrent-connections: 16
    max-connections-per-window: 32
    window: 10m
api:
  enabled: true
  listener: "0.0.0.0:8089"
  tls: {cert: /tls/tls.crt, key: /tls/tls.key}
  bearer-tokens: []
accounts:
  authentication-enabled: true
  default-user-modes: +i
  multiclient:
    enabled: true
    allowed-by-default: true
    always-on: opt-in
  nick-reservation:
    enabled: true
    method: strict
    force-nick-equals-account: true
  registration:
    enabled: false
    bcrypt-cost: 4
  require-sasl:
    enabled: true
  login-throttling:
    enabled: true
    duration: 1m
    max-attempts: 3
channels:
  default-modes: +ntC
  max-channels-per-client: 100
  registration:
    enabled: true
    max-channels-per-account: 50
datastore:
  autoupgrade: true
  path: /ircd/ircd.db
  sqlite:
    enabled: true
    database-path: /ircd/history.db
    max-conns: 1
history:
  enabled: true
  channel-length: 2048
  client-length: 256
  chathistory-maxmessages: 1000
  persistent:
    enabled: true
    unregistered-channels: true
    registered-channels: opt-out
    direct-messages: opt-out
  restrictions:
    expire-time: 1w
    query-cutoff: none
  retention:
    allow-individual-delete: true
    enable-account-indexing: true
  tagmsg-storage:
    whitelist: ["+draft/react", "+draft/unreact", "+react", "+unreact"]
metadata:
  enabled: true
  max-keys: 100
  max-subs: 100
limits:
  nicklen: 32
  identlen: 20
  channellen: 64
  awaylen: 390
  kicklen: 390
  topiclen: 390
  monitor-entries: 100
  whowas-entries: 100
  multiline: {max-bytes: 4096, max-lines: 100}
{{- if .Values.moderation.enabled }}
# Ergo starts with the hashed moderation password from the mounted Secret.
oper-classes:
  ircord-moderation:
    title: IRCord moderation
    capabilities: [history, nofakelag, samode]
opers:
  {{ include "ircord.moderationOperator" . }}:
    class: ircord-moderation
    hidden: true
{{- end }}
logging:
  - {method: stderr, level: info, type: "* -userinput -useroutput"}
{{- end -}}
