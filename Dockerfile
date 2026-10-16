# Supabase (self-hosted) in a single container for Pterodactyl / Pelican / Calagopus.
#
# Every service is copied from its official image. Versions follow
# https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml
ARG POSTGRES_IMAGE=supabase/postgres:17.6.1.136
ARG AUTH_IMAGE=supabase/gotrue:v2.196.0
ARG REST_IMAGE=postgrest/postgrest:v14.17
ARG REALTIME_IMAGE=supabase/realtime:v2.134.10
ARG STORAGE_IMAGE=supabase/storage-api:v1.74.0
ARG META_IMAGE=supabase/postgres-meta:v0.99.0
ARG STUDIO_IMAGE=supabase/studio:2026.09.07-sha-7996410
ARG ENVOY_IMAGE=envoyproxy/envoy:v1.39.1

FROM ${POSTGRES_IMAGE} AS postgres
FROM ${AUTH_IMAGE} AS auth
FROM ${REST_IMAGE} AS rest
FROM ${REALTIME_IMAGE} AS realtime
FROM ${STORAGE_IMAGE} AS storage
FROM ${META_IMAGE} AS meta
FROM ${STUDIO_IMAGE} AS studio
FROM ${ENVOY_IMAGE} AS envoy

# The official storage image is Alpine (musl); its native modules are rebuilt
# here for glibc. The compiled JavaScript (dist) is copied as is.
FROM node:24-trixie AS storage-deps
WORKDIR /app
COPY --from=storage /app/package.json /app/package-lock.json ./
COPY --from=storage /app/scripts ./scripts
RUN npm ci --omit=dev --ignore-scripts=false && npm cache clean --force

FROM node:24-trixie-slim

ARG TARGETARCH
ARG CLOUDFLARED_VERSION=2026.10.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl openssl tini tzdata locales iproute2 \
        libstdc++6 libncurses6 xz-utils procps \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/* \
    # Pterodactyl runs containers as uid 988 with /home/container as the only writable path
    && useradd -m -d /home/container -u 988 -s /bin/bash container

# ---------- Postgres (self-contained Nix closure) ----------
COPY --from=postgres /nix /nix
COPY --from=postgres /usr/lib/postgresql /usr/lib/postgresql
COPY --from=postgres /usr/share/postgresql /usr/share/postgresql
COPY --from=postgres /usr/lib/groonga /usr/lib/groonga
COPY --from=postgres /etc/postgresql /etc/postgresql
COPY --from=postgres /etc/postgresql-custom /etc/postgresql-custom
COPY --from=postgres /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

# ---------- Auth, PostgREST, Envoy (single binaries) ----------
COPY --from=auth /usr/local/bin/auth /usr/local/bin/auth
COPY --from=auth /usr/local/etc/auth/migrations /usr/local/etc/auth/migrations
COPY --from=rest /bin/postgrest /usr/local/bin/postgrest
COPY --from=envoy /usr/local/bin/envoy /usr/local/bin/envoy

# ---------- Realtime (Elixir release built on Debian trixie) ----------
COPY --from=realtime /app /opt/realtime
COPY --from=realtime /usr/local/share/pgdelta /usr/local/share/pgdelta
COPY --from=realtime /build /build
# pgdelta unpacks itself on first use, but the root filesystem is read-only at runtime
RUN mkdir -p /opt/realtime/.pgdelta-cache \
    && xz -dc /usr/local/share/pgdelta/pgdelta.xz > /opt/realtime/.pgdelta-cache/pgdelta \
    && chmod +x /opt/realtime/.pgdelta-cache/pgdelta \
    && printf '#!/bin/sh\nexec /opt/realtime/.pgdelta-cache/pgdelta "$@"\n' > /usr/local/bin/pgdelta \
    && chmod +x /usr/local/bin/pgdelta

# ---------- Node services ----------
COPY --from=storage /app/dist /opt/storage/dist
COPY --from=storage /app/migrations /opt/storage/migrations
COPY --from=storage /app/package.json /app/watt.json /app/watt.storage.json /opt/storage/
COPY --from=storage-deps /app/node_modules /opt/storage/node_modules
COPY --from=meta /usr/src/app /opt/meta
COPY --from=studio /app /opt/studio
# Next.js writes its cache next to the app; point it to the tmpfs
RUN rm -rf /opt/studio/apps/studio/.next/cache && ln -s /tmp/supabase/studio-cache /opt/studio/apps/studio/.next/cache

# ---------- Cloudflared ----------
RUN curl -fsSL -o /usr/local/bin/cloudflared \
        "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${TARGETARCH}" \
    && chmod +x /usr/local/bin/cloudflared

# ---------- Our scripts and config ----------
COPY rootfs/ /
RUN cp /opt/supabase/db/init-scripts/*.sql /docker-entrypoint-initdb.d/init-scripts/ \
    && cp /opt/supabase/db/migrations/*.sql /docker-entrypoint-initdb.d/migrations/ \
    && cp /opt/supabase/postgres/pg_hba.conf /etc/postgresql/pg_hba.conf \
    && cp /opt/supabase/postgres/pgsodium_getkey.sh /usr/lib/postgresql/bin/pgsodium_getkey.sh \
    && chmod +x /opt/supabase/bin/* /usr/lib/postgresql/bin/pgsodium_getkey.sh /docker-entrypoint-initdb.d/migrate.sh

# Sanity checks: every binary must run on this base
RUN /usr/lib/postgresql/bin/postgres --version \
    && auth version \
    && postgrest --version \
    && envoy --version \
    && cloudflared --version \
    && /opt/realtime/bin/realtime version \
    && node -e "require('/opt/storage/node_modules/pg')" \
    && test -f /opt/studio/apps/studio/server.js \
    && test -f /opt/meta/dist/server/server.js

ENV PATH="/nix/var/nix/profiles/default/bin:/usr/lib/postgresql/bin:${PATH}" \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    GRN_PLUGINS_DIR=/usr/lib/groonga/plugins \
    LOCALE_ARCHIVE=/nix/var/nix/profiles/default/lib/locale/locale-archive \
    USER=container \
    HOME=/home/container

USER container
WORKDIR /home/container

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/opt/supabase/bin/entrypoint"]

LABEL org.opencontainers.image.source="https://github.com/LeonardoRRC/pterodactyl-supabase" \
      org.opencontainers.image.description="Self-hosted Supabase in a single container for Pterodactyl, Pelican and Calagopus" \
      org.opencontainers.image.licenses="Apache-2.0"
