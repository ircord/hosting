#!/bin/sh
set -eu

s3() {
  aws --endpoint-url "$S3_ENDPOINT" --cli-connect-timeout 4 --cli-read-timeout 12 s3api "$@"
}

attempt=0
until s3 list-buckets >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo 'The bundled S3 service did not become ready.' >&2
    exit 1
  fi
  sleep 2
done

if ! s3 head-bucket --bucket "$S3_BUCKET" 2>/tmp/bucket-error; then
  if ! grep -Eq 'NoSuchBucket|\(404\)' /tmp/bucket-error; then
    echo 'Could not inspect the media bucket.' >&2
    exit 1
  fi
  if [ "$AWS_DEFAULT_REGION" = us-east-1 ]; then
    s3 create-bucket --bucket "$S3_BUCKET"
  else
    s3 create-bucket --bucket "$S3_BUCKET" \
      --create-bucket-configuration "LocationConstraint=$AWS_DEFAULT_REGION"
  fi
fi

printf '{"Version":"2012-10-17","Statement":[{"Sid":"IRCordPublicMedia","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::%s/%s/*"}]}\n' \
  "$S3_BUCKET" "$MEDIA_PREFIX" >/tmp/bucket-policy.json
s3 put-bucket-policy --bucket "$S3_BUCKET" --policy file:///tmp/bucket-policy.json

if [ "$MEDIA_LIFECYCLE" = true ]; then
  /bin/sh /config/media-lifecycle.sh
fi
