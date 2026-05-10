# online

Caddy reverse proxy with a tiny Rails admin UI for managing it. One Docker
image, one container, one volume. Pull and run.

Each service you add through the UI gets:

- A real Let's Encrypt certificate, obtained via the ACME DNS-01 challenge
  through Cloudflare (works even when the host has no public ingress).
- A reverse proxy from `https://<your-hostname>` to `localhost:<port>` on the
  host.
- Live reload — no restarts, no dropped connections.

## Architecture

```
                   ┌──────────────────────────────────────┐
                   │ private network (e.g. tailnet, LAN)  │
                   │                                      │
   you ─tailnet─►  │   ┌─ container (one image) ──────┐   │
                   │   │ Rails admin (:3003)          │   │
                   │   │       │ in-process push      │   │
                   │   │       ▼ (text/caddyfile      │   │
                   │   │         to :2019/load)       │   │
                   │   │ Caddy                        │   │
   user ─HTTPS──►  │   │  - admin :2019 (loopback)    │   │
                   │   │  - serves :80/:443           │ ─►  localhost:<port>
                   │   └──────────┬───────────────────┘   │  (services on host)
                   │              │                       │
                   └──────────────┼───────────────────────┘
                                  │
   Public internet ◄──── DNS-01 ──┘
   (Cloudflare API + Let's Encrypt validation lookups only —
    the host is never reached from outside the private network)
```

Both processes (Caddy + Rails) run inside the single container. The entrypoint
spawns Caddy in the background, then runs Rails. Rails publishes Caddyfile
updates over loopback to Caddy's admin API on port 2019.

DNS-01 is required because the host typically isn't publicly reachable
(Tailscale tailnet, LAN, etc.). Caddy proves domain ownership by writing a
TXT record into Cloudflare DNS, which Let's Encrypt then reads from the
public internet. Nothing inbound to the host.

## Prerequisites

- Docker + the Compose plugin on the host.
- Your domain's DNS hosted on **Cloudflare** (any registrar — the nameservers
  just need to point at Cloudflare's).
- For each subdomain you'll expose: a CNAME (or A record) in Cloudflare
  pointing to your host's private name (e.g. `nas.<tailnet>.ts.net` for
  Tailscale, or your LAN IP/hostname).
- A Cloudflare API token with **Zone → DNS → Edit** scoped to your zone.
  Create it at <https://dash.cloudflare.com/profile/api-tokens>.

## Run it

The image bakes in every sensible default — you only need to provide a
volume and host networking. Pick whichever you like.

### Plain `docker run`

```bash
docker run -d \
  --name online \
  --restart unless-stopped \
  --network host \
  -v online_data:/rails/storage \
  ghcr.io/cupatea/online:latest
```

### Compose

Save this as `docker-compose.yml`:

```yaml
services:
  app:
    image: ghcr.io/cupatea/online:latest
    container_name: online
    restart: unless-stopped
    network_mode: host
    volumes:
      - online_data:/rails/storage

volumes:
  online_data:
```

Or fetch it: `curl -O https://raw.githubusercontent.com/cupatea/online/main/docker-compose.yml`

Then `docker compose up -d`.

### NAS web UIs (Synology, UGOS, Portainer, etc.)

The image declares `VOLUME ["/rails/storage"]` and `EXPOSE 80 443 3003`, so
most NAS container UIs auto-detect them. In those UIs:

- Pull `ghcr.io/cupatea/online:latest`
- Network mode: **host**
- Mount a named volume to `/rails/storage`
- Start

That's it. The container creates its SQLite DB on first boot, runs all
migrations, generates a `SECRET_KEY_BASE` and stores it in the volume.
Subsequent boots reuse what's there.

## Configure it

Open the admin UI from any device on the same private network:

```
http://<host>:3003
```

Where `<host>` is whatever resolves to your machine — `nas.<tailnet>.ts.net`
on Tailscale, the host's LAN IP, etc.

1. **Settings** → enter your ACME email and Cloudflare API token → Save.
2. **+ Add service** → display name, hostname (e.g. `caramba.example.com`),
   upstream host (default `localhost`), upstream port → Save.
3. The admin pushes the new Caddyfile to Caddy in-process. The first request
   to the new hostname triggers cert issuance (DNS-01 takes ~30 seconds
   end-to-end).

That's it. No Caddyfile editing. No SSH. No restarts.

## Verifying it works

```bash
docker compose ps
docker compose logs -f          # Caddy + Rails interleave on stdout
curl -v https://<your-hostname>
```

Look for `certificate obtained successfully` after you add your first
service.

## Updating

On the host running the image:

```bash
docker compose pull
docker compose up -d
```

The volume survives upgrades, so settings, services, the auto-generated
`SECRET_KEY_BASE`, and issued certificates all carry over.

## Releasing a new image

Builds happen locally — no CI. To cut a release:

```bash
# One-time auth (token needs the write:packages scope)
gh auth token | docker login ghcr.io -u cupatea --password-stdin

# Build amd64 (NAS arch) and push
script/release             # tags :latest
script/release v0.1.0      # also tags :v0.1.0
```

The script runs `docker buildx build --platform linux/amd64 --push`. Set
`PLATFORMS=linux/amd64,linux/arm64` if you also need arm64 (slow on x86
hosts — uses QEMU emulation).

## How the admin pushes config

`CaddyPublisher` (in `app/models/caddy_publisher.rb`) renders a
Caddyfile from the `Setting` row plus all enabled `Service` rows and POSTs
it to `http://localhost:2019/load` with `Content-Type: text/caddyfile`. Caddy
parses, validates, and applies the new config atomically. If validation
fails, the running config keeps serving traffic and the UI surfaces the
error.

Triggers:

- Every settings/service save in the UI (synchronous — failures show up next
  to the success flash).
- App boot (so a Caddy restart re-syncs from the database).
- The "Republish" button in the UI (manual retry).

The Cloudflare token is inlined into the Caddyfile that's sent to Caddy. It
sits in Caddy's running config and `online_data/caddy/` — the same trust
boundary as the SQLite DB it came from.

## Troubleshooting

- **Port 80/443 already in use.** Some NAS web UIs bind these by default.
  Move the admin UI off them **before** running `docker compose up`. Confirm
  with `sudo ss -ltnp | grep -E ':(80|443)\b'`.
- **Port 3003 already in use.** Pick a different port: change `PORT: "3003"`
  in the compose file. The admin app listens on whatever `PORT` is set to.
- **`tls: failed to obtain certificate` / DNS-01 errors.** The token is
  almost always the cause. Re-check it has `Zone:DNS:Edit` scoped to the
  right zone. Test it with:
  ```bash
  curl -H "Authorization: Bearer $YOUR_TOKEN" \
       https://api.cloudflare.com/client/v4/user/tokens/verify
  ```
  Should return `"status":"active"`. Update the token in **Settings** and
  click Republish.
- **DNS not on Cloudflare yet.** The TXT records this proxy writes have to
  land on Cloudflare's authoritative nameservers, so your domain's
  nameservers must point at Cloudflare. `dig +trace <hostname>` should show
  Cloudflare as authoritative.
- **Let's Encrypt rate limits.** 5 duplicate certs per week per domain, 50
  certs per registered domain per week. If you're iterating, stop and let
  Caddy back off — it auto-retries with exponential backoff.
- **Hostname doesn't resolve from your laptop.** You're not on the network
  the host is on, or your DNS isn't reaching the right place. On Tailscale,
  check `tailscale status` and that MagicDNS is enabled on your client.
- **I want to nuke and start over.** `docker compose down -v` removes
  `online_data` (cert data + admin SQLite + auto-generated secret). You'll
  re-issue certs from scratch on the next boot.

## Security notes

- The admin UI has no auth. The boundary is your private network — anyone
  who can reach `<host>:3003` can edit settings. If that's not OK, restrict
  network access (Tailscale ACLs, firewall) or front the admin app with
  HTTP basic auth.
- The Cloudflare token grants edit access to one DNS zone. Scope it tightly
  and rotate it if compromised.
- `online_data` (issued certs + ACME account key + SQLite with the token +
  the generated session secret) is sensitive. Back it up; protect it like
  passwords.
