#!/bin/sh
set -eu

# Hash the moderation operator password for the operator in the bundled config.
password=/etc/ircord/moderation/password
[ -s "$password" ] || { echo 'Missing moderation operator password.' >&2; exit 1; }
hash=$(/ircd-bin/ergo genpasswd < "$password")
name=$(printf '%s' "$ERGO_MODERATION_OPERATOR" | tr 'a-z-' 'A-Z_')
export "ERGO__OPERS__${name}__PASSWORD=$hash"
unset ERGO_MODERATION_OPERATOR hash name password
exec /bin/sh /scripts/run.sh
