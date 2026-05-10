# nas reverse proxy

Caddy reverse proxy with a tiny Rails admin UI for managing it. Two prebuilt
images, one compose file, no config files. Pull, start, open the UI, add your
services. Caddy reloads itself.

Each service you add gets:

- A real Let's Encrypt certificate, obtained via the ACME DNS-01 challenge
  through Cloudflare (works even when the host has no public ingress).
- A reverse proxy from `https://<your-hostname>` to `localhost:<port>` on the
  host.
- Live reload — no container restarts, no dropped connections.

## Architecture

```
                   ┌──────────────────────────────────────┐
                   │ private network (e.g. tailnet, LAN)  │
                   │                                      │
   you ─tailnet─►  │   ┌────────────────────┐             │
                   │   │ admin (Rails, :3003)│            │
                   │   │  - SQLite           │            │
                   │   │  - Settings + CRUD  │            │
                   │   └────────┬───────────┘             │
                   │            │ POST /load              │
                   │            ▼ (text/caddyfile)        │
                   │   ┌────────────────────┐             │
                   │   │ caddy              │             │
                   │   │  - admin :2019     │             │
   user ─HTTPS──►  │   │  - serves :80/:443 │ ─►  localhost:<port>
                   │   └────────┬───────────┘             │  (your services
                   │            │                         │   on the host)
                   └────────────┼─────────────────────────┘
                                │
   Public internet ◄─ DNS-01 ──┘
   (Cloudflare API + Let's Encrypt validation lookups only —
    the host is never reached from outside the private network)
```

The host typically isn't publicly reachable (Tailscale tailnet, LAN, etc.).
That makes HTTP-01 (where Let's Encrypt hits port 80 from the public
internet) impossible, so we use DNS-01 instead: Caddy proves domain ownership
by writing a TXT record into Cloudflare DNS, which Let's Encrypt then reads
over the public internet. The host is never contacted from outside.

## Prerequisites

- Docker + the Compose plugin on the host.
- Your domain's DNS hosted on **Cloudflare** (any registrar is fine — the
  nameservers just need to point at Cloudflare's).
- For each subdomain you'll expose: a CNAME (or A record) in Cloudflare
  pointing to your host's private name (e.g. `nas.<tailnet>.ts.net` for
  Tailscale, or your LAN IP/hostname).
- A Cloudflare API token with **Zone → DNS → Edit** scoped to your zone.
  Create it at <https://dash.cloudflare.com/profile/api-tokens>.

## Run it

Save this as `docker-compose.yml`:

```yaml
services:
  caddy:
    image: ghcr.io/cupatea/nas-caddy:latest
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - caddy_data:/data
      - caddy_config:/config

  admin:
    image: ghcr.io/cupatea/nas-admin:latest
    container_name: nas-admin
    restart: unless-stopped
    network_mode: host
    depends_on: [caddy]
    environment:
      RAILS_ENV: production
      PORT: "3003"
      CADDY_ADMIN_URL: "http://localhost:2019"
      RAILS_LOG_TO_STDOUT: "1"
      RAILS_SERVE_STATIC_FILES: "1"
    volumes:
      - admin_data:/rails/storage

volumes:
  caddy_data:
  caddy_config:
  admin_data:
```

Or fetch the same file from the repo:

```bash
curl -O https://raw.githubusercontent.com/cupatea/nas/main/docker-compose.yml
```

Then:

```bash
docker compose up -d
```

That's the whole install. No `.env` file. No clone. No build. The admin
container generates its own `SECRET_KEY_BASE` on first boot and persists it in
the `admin_data` volume.

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
3. The admin app pushes the new Caddyfile to Caddy. The first request to the
   new hostname triggers cert issuance (DNS-01 takes ~30 seconds end-to-end).

That's it. No Caddyfile editing. No SSH. No restarts.

## Verifying it works

```bash
docker compose ps
docker compose logs -f caddy   # watch for "certificate obtained successfully"
docker compose logs -f admin   # every save logs an "applied config" line
curl -v https://<your-hostname>
```

## Updating

```bash
docker compose pull
docker compose up -d
```

Service rows + the auto-generated `SECRET_KEY_BASE` survive image upgrades
(both live in the `admin_data` volume).

## How the admin pushes config

`CaddyPublisher` (the only meaningful service object in the Rails app)
renders a Caddyfile from the `Setting` row plus all enabled `Service` rows
and POSTs it to `http://localhost:2019/load` with `Content-Type:
text/caddyfile`. Caddy parses, validates, and applies the new config
atomically. If validation fails, the running config keeps serving traffic and
the UI surfaces the error.

Triggers:

- Every settings/service save in the UI (synchronous — failures show up next
  to the success flash).
- App boot (so a Caddy restart re-syncs from the database).
- The "Republish" button in the UI (manual retry).

The Cloudflare token is inlined into the Caddyfile that's sent to Caddy. It
sits in Caddy's running config and the `caddy_config` volume — the same trust
boundary as the SQLite DB it came from.

## Troubleshooting

- **Port 80/443 already in use.** Some NAS web UIs bind these by default.
  Move the admin UI to other ports **before** running `docker compose up`.
  Confirm with `sudo ss -ltnp | grep -E ':(80|443)\b'`.
- **Port 3003 already in use.** Pick a different port: change `PORT: "3003"`
  in the compose file. The admin app listens on whatever `PORT` is set to.
- **Admin UI shows "Couldn't reach Caddy at http://localhost:2019".** Caddy
  isn't running or didn't bind the admin API. `docker compose ps`,
  `docker compose logs caddy`. Once Caddy is up, hit "Republish" in the UI.
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
  nameservers must point at Cloudflare. Until that's true, DNS-01 will fail.
  Check with `dig +trace <hostname>` — the authoritative answer should come
  from Cloudflare.
- **Let's Encrypt rate limits.** 5 duplicate certs per week per domain, 50
  certs per registered domain per week. If you're iterating, stop and let
  Caddy back off — it auto-retries with exponential backoff.
- **Hostname doesn't resolve from your laptop.** You're not on the network
  the host is on, or your DNS isn't reaching the right place. On Tailscale,
  check `tailscale status` and that MagicDNS is enabled on your client.
- **I want to nuke and start over.** `docker compose down -v` removes the
  volumes (cert data + admin SQLite + auto-generated secret). You'll
  re-issue certs from scratch on the next boot.

## Security notes

- The admin UI has no auth. The boundary is your private network — anyone
  who can reach `<host>:3003` can edit settings. If that's not OK, restrict
  network access (Tailscale ACLs, firewall) or front the admin app with
  HTTP basic auth.
- The Cloudflare token grants edit access to one DNS zone. Scope it tightly
  and rotate it if compromised.
- `caddy_data` (issued certs + ACME account key) and `admin_data` (SQLite
  with the token + the generated session secret) are sensitive. Back them
  up; protect them like passwords.
