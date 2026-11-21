# Host IRCord

Run IRCord with Docker Compose or Kubernetes. Both configurations use published
component images and keep the backend database on persistent storage.

Report hosting problems in the [IRCord issue tracker](https://github.com/ircord/issues/issues).

## Docker Compose

Clone this repository and start the backend and frontend.

```sh
git clone https://github.com/ircord/hosting.git
cd hosting
docker compose up -d --wait
```

Open [localhost:3000](http://localhost:3000). Compose publishes only the frontend
port. To serve IRCord over Hypertext Transfer Protocol Secure (HTTPS), put a
reverse proxy in front of it and set `IRCORD_PUBLIC_URL` to the exact public
origin. Enable WebSocket upgrades and let long-lived connections stay open.

Copy `.env.example` to `.env` to change the port, bind address, or Compose
network. Set `IRCORD_BACKEND_IMAGE` and `IRCORD_FRONTEND_IMAGE` to pick image tags
or digests independently. If the default subnet overlaps an existing network,
change `IRCORD_NETWORK_SUBNET`. To trust an external reverse proxy, set
`IRCORD_TRUSTED_PROXIES` to the Compose subnet and the proxy's address range.
The proxy must append the client address to `X-Forwarded-For`.

Put additional backend settings in the ignored `backend.env` file. Use
`frontend.env` for frontend settings. For the available settings, see the
[backend configuration example](https://github.com/ircord/backend/blob/main/.env.example).

Back up the `backend-data` volume. It contains the database, encryption key,
and local files. Use `docker compose pull` followed by
`docker compose up -d --wait` to update. Use `docker compose down` to stop.

## Kubernetes

Use Helm and a cluster with a default StorageClass. The example install runs
one backend and one frontend, with a persistent volume for the backend.

```sh
helm upgrade --install ircord ./charts/ircord --namespace ircord --create-namespace --wait
kubectl -n ircord port-forward service/ircord-frontend 3000:3000
```

Open [localhost:3000](http://localhost:3000). See
[`examples/full-values.yaml`](examples/full-values.yaml) for an installation with
three hosts, bundled media storage, and an associated Ergo server.

### Routing and images

- Set `publicUrl` to the exact public app origin and enable `ingress.app` to
  expose the frontend. The backend service stays internal.
- Set `website.enabled=true` to run the public website. Use `ingress.website`
  to give it a separate host.
- Each ingress accepts a class, annotations, and a TLS Secret name. Set the
  annotations required by your ingress controller or certificate issuer.
- Use `backend.trustedProxies` to trust only the frontend and your reverse proxy
  addresses. Configure your proxy to append the original client address.
- Set an image repository and tag for each component. Set its optional
  `digest` to pin an exact image. The website defaults to its existing
  published image.

### Storage and credentials

- The backend, bundled media storage, and Ergo have individual volume settings.
  Set `storageClass` and `size`, or set `existingClaim` to use an existing
  claim in the release namespace.
- Helm retains the claims it creates. To reuse a retained claim after a fresh
  install, set `existingClaim` to its name.
- The backend uses SQLite and requires exclusive access to its data directory.
  The chart runs one replica and recreates it during upgrades.
- Set non-secret options in `backend.env` and `frontend.env`. Use `envFrom`
  for Secrets and ConfigMaps. Use `backend.extraVolumes` and
  `backend.extraVolumeMounts` for options that require files.
- Back up the backend, RustFS, and Ergo volumes independently.

### Media CDN

Set `media.mode=external` to use existing S3-compatible storage. Set its
private endpoint, public media origin, bucket, region, and prefix. Provide an
existing Secret with keys `access-key` and `secret-key`. If the credentials
use a session token, set `media.credentials.sessionTokenKey`.

Set `media.mode=bundled` to run RustFS and a public media gateway. Provide the
same Secret and a public origin in `media.publicUrl`. Enable `ingress.media`
or configure another route to the gateway Service. Install with
`--wait --wait-for-jobs` to wait until the bucket and its read policy exist.

The gateway serves only hashed media paths with GET, HEAD, and OPTIONS. Keep
the RustFS service internal. The chart manages the bundled bucket's public
media policy. Enable `media.lifecycle.enabled` to expire linked-media objects
after 90 days by default. The lifecycle job preserves unrelated bucket rules.
Set the two lifecycle rule IDs to adopt existing IRCord rules during migration.
To keep private hosted files in object storage, set `backend.fileStorage=s3`.
Use a separate private bucket. Set `IRCORD_S3_ENDPOINT` (host and optional port),
`IRCORD_S3_BUCKET`, and `IRCORD_S3_REGION` under `backend.env`. Supply
`IRCORD_S3_ACCESS_KEY` and `IRCORD_S3_SECRET_KEY` through `backend.envFrom`.

### Associated Ergo server

Enable `ergo.enabled` and set `ergo.hostname` to the DNS name IRC clients use.
Provide an existing TLS Secret for that name and an existing Secret with a
64-character hexadecimal `api-token`. The chart gives the IRCord backend and
Ergo the same API token. The private API stays on a separate internal Service.

Use `ergo.service.type=LoadBalancer` or route TCP traffic to the IRC Service.
For a private certificate authority, set `ergo.caSecret`. The bundled
configuration enables TLS, account authentication, channel registration, and
persistent history. To use your own configuration, set
`ergo.existingConfigMap` and provide `ircd.yaml`.

### Cloudflare

Enable `cachePurge.enabled` if the app host uses Cloudflare. Reference an
existing Secret with `api-token` and `zone-id`. Give the token permission to
purge the relevant zone. The hook waits for the targeted frontend image to be
ready before purging the configured hostname.

### Validate before deploying

```sh
docker compose config --quiet
helm lint --strict ./charts/ircord
helm lint --strict ./charts/ircord -f ./examples/full-values.yaml
helm template ircord ./charts/ircord -f ./examples/full-values.yaml
```
