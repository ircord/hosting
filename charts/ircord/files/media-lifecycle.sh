#!/bin/sh
set -eu

s3() {
  aws --endpoint-url "$S3_ENDPOINT" --cli-connect-timeout 5 --cli-read-timeout 25 s3api "$@"
}

rules=$(printf '[{"ID":"%s","Status":"Enabled","Filter":{"Prefix":"%s/link-media/"},"Expiration":{"Days":%s},"NoncurrentVersionExpiration":{"NoncurrentDays":1}},{"ID":"%s","Status":"Enabled","Filter":{"Prefix":"%s/link-media/"},"Expiration":{"ExpiredObjectDeleteMarker":true}}]' \
  "$EXPIRATION_RULE_ID" "$MEDIA_PREFIX" "$LIFECYCLE_DAYS" "$DELETE_MARKER_RULE_ID" "$MEDIA_PREFIX")
query="{Rules: [Rules[?ID != '$EXPIRATION_RULE_ID' && ID != '$DELETE_MARKER_RULE_ID'], \`$rules\`][]}"

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
