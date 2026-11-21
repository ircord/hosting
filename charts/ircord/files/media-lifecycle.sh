#!/bin/sh
set -eu

s3() {
  aws --endpoint-url "$S3_ENDPOINT" --cli-connect-timeout 5 --cli-read-timeout 25 s3api "$@"
}

rules=$(printf '[{"ID":"ircord-linked-media-expiry","Status":"Enabled","Filter":{"Prefix":"%s/link-media/"},"Expiration":{"Days":%s},"NoncurrentVersionExpiration":{"NoncurrentDays":1}},{"ID":"ircord-linked-media-delete-markers","Status":"Enabled","Filter":{"Prefix":"%s/link-media/"},"Expiration":{"ExpiredObjectDeleteMarker":true}}]' \
  "$MEDIA_PREFIX" "$LIFECYCLE_DAYS" "$MEDIA_PREFIX")
query="{Rules: [Rules[?ID != 'ircord-linked-media-expiry' && ID != 'ircord-linked-media-delete-markers'], \`$rules\`][]}"

if s3 get-bucket-lifecycle-configuration --bucket "$S3_BUCKET" --query "$query" --output json >/tmp/lifecycle.json 2>/tmp/lifecycle-error; then
  :
elif grep -q NoSuchLifecycleConfiguration /tmp/lifecycle-error; then
  printf '{"Rules":%s}\n' "$rules" >/tmp/lifecycle.json
else
  echo 'Could not inspect the current bucket lifecycle rules.' >&2
  exit 1
fi

s3 put-bucket-lifecycle-configuration --bucket "$S3_BUCKET" \
  --lifecycle-configuration file:///tmp/lifecycle.json
