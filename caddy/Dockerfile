# syntax=docker/dockerfile:1

ARG CADDY_VERSION=2.8.4

# Stage 1: build a custom Caddy binary that includes the Cloudflare DNS module
# (required for ACME DNS-01 — see README for why).
FROM caddy:${CADDY_VERSION}-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

# Stage 2: minimal runtime image. Replaces the stock Caddy binary with ours
# and bakes in a bootstrap Caddyfile that just enables the admin API.
FROM caddy:${CADDY_VERSION}

LABEL org.opencontainers.image.source="https://github.com/cupatea/nas"
LABEL org.opencontainers.image.description="Caddy with caddy-dns/cloudflare. Configured at runtime by the nas-admin Rails app via the admin API (:2019)."
LABEL org.opencontainers.image.licenses="MIT"

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
