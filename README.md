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
- Add host aliases to a route with `ingress.<route>.aliases`. Set
  `ingress.app.directBackend` to route HTTP API and WebSocket paths to the backend.
- Set `ingress.certificates.issuerRef` to let the chart create cert-manager
  certificates for the routes. Set each route's `tlsSecret` to name its Secret.
- Set `ingress.driver=traefik` to use Traefik IngressRoutes and HTTP redirects.
  This option requires the Traefik custom resource definitions.
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
  for Secrets and ConfigMaps or `envRefs` for individual values. Use
  `backend.extraVolumes` and
  `backend.extraVolumeMounts` for options that require files.
- Set `infisical.paths` to let an installed Infisical operator populate Secrets.
  Supply the API host, project, environment, and Universal Auth reference.
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

## Voice channels

Voice requires compatible backend and frontend builds. Server owners can create voice channels
that all signed-in accounts on the IRCord server can join.

With Helm, set `voice.enabled` and reference a Secret in `voice.credentials.existingSecret`.
The Secret must contain `IRCORD_VOICE_API_KEY` and `IRCORD_VOICE_API_SECRET`.
Use a random API secret of at least 32 characters.
The chart restricts LiveKit signaling and administration to backend pods.
With `voice.channels` empty and `voice.media.enabled` off, only the private service runs.

To seed rooms when the backend first creates its catalog, list the initial names in
`voice.channels` using the lowercase `#channel` format. Create, edit, and remove rooms in
IRCord after startup. Existing IRC-linked rooms migrate to server-wide voice channels.
Set `voice.media.enabled` and set `voice.media.address` to the IP clients can reach on UDP port 7882.
Forward that port to the media load balancer if your router uses network address translation.
Clients use the existing IRCord HTTPS host for signaling and WebRTC for audio.
Exclude signaling query strings from reverse proxy logs because they contain room credentials.

With Compose, put the same key and secret in `backend.env` using the names above.
Set `IRCORD_VOICE_URL=http://livekit:7880`. Optionally set `IRCORD_VOICE_CHANNELS` to a
comma-separated list of channels to import when the backend first creates its catalog.
Set `LIVEKIT_KEYS` in `voice.env` to a mapping in the form `api-key: api-secret`.
Start with `docker compose --profile voice up -d --wait`.
The default bind and advertised media address are loopback for local testing.

## Server-owner moderation

Server owners can delete other people's messages and mark people as bots on
the associated Ergo server. The backend does this through an Ergo operator
login. Moderation stays off until you configure that operator.

Generate a password without spaces, and the bcrypt hash Ergo expects. Run the
same Ergo version as your server.

```sh
openssl rand -hex 32 > ergo-moderation-password
docker run --rm -i --entrypoint /ircd-bin/ergo ghcr.io/ergochat/ergo:v2.19.1 \
  genpasswd < ergo-moderation-password
```

Add the operator to the Ergo configuration. Use the printed hash as its
password. The class needs exactly these capabilities: `history` and
`nofakelag` to delete messages, and `samode` to mark bots.

```yaml
oper-classes:
  ircord-moderation:
    title: IRCord moderation
    capabilities: [history, nofakelag, samode]
opers:
  ircord-moderation:
    class: ircord-moderation
    hidden: true
    password: "$2a$04$..."
```

Moderation also requires an associated Ergo server with accounts enabled.
After you enable moderation, the backend log reports that server-owner
moderation is on.

### With Docker Compose

Compose does not run Ergo. Add the operator to your Ergo server, and point the
backend at that server in `backend.env`. Keep the password file next to `compose.yaml`, or set
`IRCORD_ERGO_MODERATION_PASSWORD_PATH` to its path. The backend runs as user
65532, so that user must be able to read the file. Add the moderation file
in `.env` and recreate the backend:

```sh
chmod 0400 ergo-moderation-password
sudo chown 65532:65532 ergo-moderation-password
echo 'COMPOSE_FILE=compose.yaml:compose.moderation.yaml' >> .env
docker compose up -d --wait
```

Set `IRCORD_ERGO_MODERATION_OPERATOR` in `.env` if your operator has
another name.

### With Helm

Store the password in a Secret and enable moderation:

```sh
kubectl -n ircord create secret generic ircord-moderation \
  --from-file=password=ergo-moderation-password
helm upgrade ircord ./charts/ircord --namespace ircord --reuse-values \
  --set moderation.enabled=true --set moderation.existingSecret=ircord-moderation
```

With the bundled Ergo configuration, the chart adds the operator and hashes
the password when Ergo starts. You don't need to hash it. With
`ergo.existingConfigMap` or an external Ergo server, add the operator entry
yourself. `moderation.operator` sets the operator name. It uses lowercase
letters, digits, and hyphens. After you change the password, restart the
backend and Ergo.
