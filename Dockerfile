# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom;error=true

# Skip rationale: RUBY_VERSION + CADDY_VERSION are sourced from
# .ruby-version and .caddy-version at build time (bin/build passes them via
# --build-arg). Single source of truth — no Dockerfile defaults to drift.
# Parser directives must be contiguous at the very top, before any plain
# comment, hence the awkward placement above.

ARG RUBY_VERSION
ARG CADDY_VERSION

# Caddy with caddy-dns/cloudflare baked in (DNS-01 for ACME).
# Passing v${CADDY_VERSION} explicitly to xcaddy pins the build — without it,
# xcaddy fetches Caddy latest, which can drift away from the builder image's
# Go toolchain and break in subtle ways (especially under QEMU multi-arch).
FROM caddy:${CADDY_VERSION}-builder AS caddy-builder
ARG CADDY_VERSION
RUN xcaddy build "v${CADDY_VERSION}" --with github.com/caddy-dns/cloudflare

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
WORKDIR /rails

# ca-certificates lets Caddy reach Cloudflare and Let's Encrypt.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 sqlite3 ca-certificates && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    PORT="3003" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1" \
    CADDY_ADMIN_URL="http://localhost:2019"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

# Container runs as root so Caddy can bind 80/443 directly with no setcap
# /capability dance — file capabilities don't survive QEMU multi-arch builds
# reliably, and on a single-tenant NAS deployment the security delta of
# rails-user-vs-root inside the container is negligible.
COPY --from=caddy-builder /usr/bin/caddy /usr/local/bin/caddy
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Bootstrap Caddyfile lives outside /rails so a stray bind-mount of the app
# dir doesn't shadow it.
COPY caddy/Caddyfile /etc/caddy/Caddyfile

LABEL org.opencontainers.image.source="https://github.com/cupatea/online"
LABEL org.opencontainers.image.description="Caddy + a Rails admin UI in one image. Configure subdomains via the UI; the admin pushes Caddyfile updates to Caddy's admin API in-process."
LABEL org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
# 80/443 are Caddy's public ports; 3003 is the admin UI; 2019 is Caddy's
# admin API (loopback-only — listed for completeness, not for binding).
EXPOSE 80 443 3003
# Single state volume — NAS GUIs auto-detect this and pre-fill a mount for it.
VOLUME ["/rails/storage"]
CMD ["./bin/rails", "server"]
