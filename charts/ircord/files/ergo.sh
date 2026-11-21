#!/bin/sh
set -eu

case "${ERGO_API_TOKEN:-}" in
  ''|*[!0-9a-fA-F]*) echo 'Invalid Ergo API token.' >&2; exit 1 ;;
esac
[ "${#ERGO_API_TOKEN}" -eq 64 ] || { echo 'Invalid Ergo API token length.' >&2; exit 1; }
export ERGO__API__BEARER_TOKENS="[\"$ERGO_API_TOKEN\"]"
unset ERGO_API_TOKEN

cd /ircd
config=/etc/ergo/ircd.yaml
if [ ! -f ircd.db ]; then
  /ircd-bin/ergo initdb --conf "$config" --quiet
fi

/ircd-bin/ergo run --conf "$config" &
server=$!
watcher=
shutdown() {
  trap - TERM INT
  [ -z "$watcher" ] || kill "$watcher" 2>/dev/null || true
  kill -TERM "$server" 2>/dev/null || true
  wait "$server"
}
trap shutdown TERM INT

(
  previous=$(cksum /tls/tls.crt /tls/tls.key)
  while kill -0 "$server" 2>/dev/null; do
    sleep 30
    current=$(cksum /tls/tls.crt /tls/tls.key) || continue
    if [ "$current" != "$previous" ]; then
      kill -HUP "$server"
      previous=$current
    fi
  done
) &
watcher=$!

result=0
wait "$server" || result=$?
kill "$watcher" 2>/dev/null || true
exit "$result"
