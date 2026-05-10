# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=4.0.2
ARG CADDY_VERSION=2.8.4

# Caddy with caddy-dns/cloudflare baked in (DNS-01 for ACME).
# Passing v${CADDY_VERSION} explicitly to xcaddy pins the build — without it,
# xcaddy fetches Caddy latest, which can drift away from the builder image's
# Go toolchain and break in subtle ways (especially under QEMU multi-arch).
FROM caddy:${CADDY_VERSION}-builder AS caddy-builder
ARG CADDY_VERSION
RUN xcaddy build "v${CADDY_VERSION}" --with github.com/caddy-dns/cloudflare

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
WORKDIR /rails

# libcap2-bin lets us setcap on the Caddy binary so the non-root user can
# bind 80/443. ca-certificates lets Caddy reach Cloudflare and Let's Encrypt.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 sqlite3 ca-certificates libcap2-bin && \
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

# Caddy binary + bootstrap config. The setcap lets the non-root rails user
# bind 80/443 with no extra privileges in compose.
COPY --from=caddy-builder /usr/bin/caddy /usr/local/bin/caddy
RUN setcap cap_net_bind_service=+ep /usr/local/bin/caddy

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Bootstrap Caddyfile lives outside /rails so a stray bind-mount of the app
# dir doesn't shadow it.
COPY --chown=rails:rails caddy/Caddyfile /etc/caddy/Caddyfile

LABEL org.opencontainers.image.source="https://github.com/cupatea/online"
LABEL org.opencontainers.image.description="Caddy + a Rails admin UI in one image. Configure subdomains via the UI; the admin pushes Caddyfile updates to Caddy's admin API in-process."
LABEL org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
# 80/443 are Caddy's public ports; 3003 is the admin UI; 2019 is Caddy's
# admin API (loopback-only — listed for completeness, not for binding).
EXPOSE 80 443 3003
# Single state volume — NAS GUIs auto-detect this and pre-fill a mount for it.
VOLUME ["/rails/storage"]
CMD ["./bin/thrust", "./bin/rails", "server"]
