#!/bin/sh
set -eu

attempt=0
while [ "$attempt" -lt 90 ]; do
  status=$(kubectl -n "$POD_NAMESPACE" --cache-dir=/tmp/kubectl get deployment "$FRONTEND_DEPLOYMENT" -o json) || status=
  if [ -n "$status" ] && printf '%s\n' "$status" | jq -e --arg image "$EXPECTED_IMAGE" '
    .spec.replicas as $wanted |
    (.spec.template.spec.containers | any(.name == "frontend" and .image == $image)) and
    .metadata.generation == .status.observedGeneration and
    .status.updatedReplicas == $wanted and .status.readyReplicas == $wanted and
    .status.availableReplicas == $wanted and .status.replicas == $wanted
  ' >/dev/null && curl -fsS --max-time 5 "$FRONTEND_URL/" >/dev/null; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 3
done
if [ "$attempt" -ge 90 ]; then
  echo 'The frontend did not become ready for cache purge.' >&2
  exit 1
fi

payload=$(jq -nc --arg host "$PURGE_HOSTNAME" '{hosts: [$host]}')
curl -fsS --max-time 30 -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H 'Content-Type: application/json' --data "$payload" |
  jq -e '.success == true' >/dev/null
