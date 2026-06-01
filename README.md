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

- Docker on the host.
- Your domain's DNS hosted on **Cloudflare** (any registrar — the nameservers
  just need to point at Cloudflare's).
- A wildcard A record in Cloudflare for your zone, pointing at the host's
  reachable IP (proxy off / DNS only):

  | Type | Name | Content | Proxy |
  |------|------|---------|-------|
  | `A`  | `*`  | `<your-host-IP>` | DNS only (gray cloud) |

  For a Tailscale-only host: use the host's Tailscale CGNAT IP (`tailscale ip`
  on the host — something like `100.x.y.z`). For a LAN-only host: use its LAN
  IP. **Don't** point to a Tailscale name like `nas.<tailnet>.ts.net` —
  public DNS resolvers can't follow the chain into Tailscale's namespace
  (split-horizon hits NXDOMAIN).
- A Cloudflare API token created from the **"Edit zone DNS"** template
  (<https://dash.cloudflare.com/profile/api-tokens>). The template grants
  both permissions DNS-01 needs: `Zone → Zone → Read` (to look up the zone
  ID) **and** `Zone → DNS → Edit` (to write the `_acme-challenge` TXT). A
  hand-rolled token with only `DNS:Edit` will fail with "expected 1 zone,
  got 0".

## Run it

The image bakes in every sensible default — you only need to provide a
volume and host networking. Pick whichever you like.

### Plain `docker run`

```bash
docker run -d \
  --name online \
  --restart unless-stopped \
  -p 80:80 -p 443:443 -p 3003:3003 \
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
    ports:
      - "80:80"
      - "443:443"
      - "3003:3003"
    volumes:
      - online_data:/rails/storage

volumes:
  online_data:
```

> **Linux host?** You can swap the `ports:` block for `network_mode: host` for
> a tiny perf win and to skip the per-port mapping. Don't do this on Docker
> Desktop (macOS/Windows) — host networking there lives in a hidden Linux VM
> and isn't reachable from the host OS.

Or fetch it: `curl -O https://raw.githubusercontent.com/cupatea/online/main/docker-compose.yml`

Then `docker compose up -d`.

### NAS web UIs (Synology, UGOS, Portainer, etc.)

The image declares `VOLUME ["/rails/storage"]` and `EXPOSE 80 443 3003 3004`,
so most NAS container UIs auto-detect them. In those UIs:

- Pull `ghcr.io/cupatea/online:latest`
- Map ports: `80 → 80`, `443 → 443`, `3003 → 3003`
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
   upstream host, upstream port → Save.
   - On Docker Desktop (macOS/Windows): use `host.docker.internal` to reach
     services running on the host machine.
   - On Linux host with `network_mode: host`: use `localhost`.
3. The admin pushes the new Caddyfile to Caddy in-process. The first request
   to the new hostname triggers cert issuance (DNS-01 takes ~30 seconds
   end-to-end).

That's it. No Caddyfile editing. No SSH. No restarts.

## Dashboard

Alongside the admin UI, the app serves a read-only **dashboard** — a launcher
that shows each enabled service as a clickable tile (icon, name, description)
that opens `https://<hostname>` in a new tab. It has no admin or settings
chrome, and admin routes are unreachable on it.

The dashboard listens on its own port (`DASHBOARD_PORT`, default `3004`) so you
can publish it while keeping the admin port (`3003`) private. To give it a
public hostname, just add a normal service in the admin UI:

- **Hostname**: e.g. `home.example.com`
- **Upstream host**: `localhost`
- **Upstream port**: `3004`

Caddy and Rails share the container, so it reaches `localhost:3004` over the
in-container loopback — you don't need to publish port 3004 on the host for
this. (Publishing `3004:3004` is only for reaching the dashboard *directly* at
`http://<host>:3004`, without going through Caddy.)

The per-service **icon** (an emoji like `🌮` or an image URL) and
**description** fields are what show up on each tile.

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

Builds happen locally — no CI. Two pinned-version files at the repo root:

- `VERSION` — this app's version (`vMAJOR.MINOR.PATCH`). Auto-bumped on
  `--publish` (PATCH+1) and committed as `vX.Y.Z`.
- `.caddy-version` — the Caddy version baked into the image. Edit by hand
  when you want to upgrade.

```bash
# One-time auth (token needs the write:packages scope)
gh auth token | docker login ghcr.io -u cupatea --password-stdin

# Local test build (native arch, no commit, no push)
bin/build

# Bump VERSION, commit, build linux/amd64, push :latest + :vX.Y.Z to GHCR
bin/build --publish
```

The publish path tags both `:latest` and the new `:vX.Y.Z` from VERSION. Set
`PLATFORMS=linux/amd64,linux/arm64` if you also need arm64 (slow on x86
hosts — uses QEMU emulation).

To bump Caddy: edit `.caddy-version`, commit, then `bin/build --publish`.

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
  with `sudo ss -ltnp | grep -E ':(80|443)\b'` on Linux, or
  `sudo lsof -nP -iTCP:80,443 -sTCP:LISTEN` on macOS.
- **Port 3003 already in use.** Pick a different port: change `PORT: "3003"`
  in the compose file. The admin app listens on whatever `PORT` is set to.
- **`tls: failed to obtain certificate` / DNS-01 errors.** The token is
  almost always the cause. Look at `docker logs online | grep cupatea` for
  the actual error:
  - `expected 1 zone, got 0` → token is missing `Zone:Zone:Read`. Recreate
    using the "Edit zone DNS" template.
  - `403 Forbidden` → token doesn't have `Zone:DNS:Edit` for the zone, or
    the wrong zone is selected.

  Test the token directly:
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
  the host is on, or your DNS isn't reaching the right place.
  - Skip DNS to isolate: `curl -vk --resolve <host>:443:<your-host-IP> https://<host>`
  - Confirm Cloudflare side: `dig +short @1.1.1.1 <host>` should return
    your host IP. If it returns blank, the wildcard A record isn't live.
  - On Tailscale, MagicDNS may be caching an earlier NXDOMAIN response.
    Wait the SOA negative-cache TTL (default 1800s) or toggle MagicDNS off
    and back on at <https://login.tailscale.com/admin/dns> to force a
    re-fetch.
- **I want to nuke and start over.** `docker compose down -v` removes
  `online_data` (cert data + admin SQLite + auto-generated secret). You'll
  re-issue certs from scratch on the next boot.

## Security notes

- The admin UI has no auth. The boundary is your private network — anyone
  who can reach `<host>:3003` can edit settings. If that's not OK, restrict
  network access (Tailscale ACLs, firewall) or front the admin app with
  HTTP basic auth.
- The dashboard (`<host>:3004`) is the surface that's safe to expose publicly:
  it only links out to your services and can't reach any admin or settings
  route. Keep the admin port (`3003`) off any public hostname.
- The Cloudflare token grants edit access to one DNS zone. Scope it tightly
  and rotate it if compromised.
- `online_data` (issued certs + ACME account key + SQLite with the token +
  the generated session secret) is sensitive. Back it up; protect it like
  passwords.
