# Supabase for Pterodactyl

Self-hosted [Supabase](https://supabase.com/docs/guides/self-hosting/docker) in a single container, packaged as an egg for Pterodactyl, Pelican and Calagopus, with an optional Cloudflare Tunnel so you get HTTPS without opening ports or running a reverse proxy.

Included: Postgres 17 (with the Supabase extensions), Auth (GoTrue), PostgREST, Realtime, Storage (local files), postgres-meta, Studio and the Envoy API gateway. Edge Functions, Supavisor, imgproxy and Analytics are not included.

## Install

1. Import [`egg/egg-supabase.json`](egg/egg-supabase.json) in **Admin → Nests → Import Egg**.
2. Create a server with at least **2 GB of RAM** and 5 GB of disk. One allocation is enough: Studio and the API share it.
3. Start it. The first start creates the database and writes all secrets to `secrets.env` (download a copy).

Studio asks for the dashboard user (`supabase` by default) and the password from `secrets.env`, or the one set in the *Dashboard Password* variable.

## HTTPS with Cloudflare Tunnel

1. Cloudflare Zero Trust → Networks → Tunnels → Create a tunnel (Cloudflared) and copy its token.
2. Add a Public Hostname, e.g. `supabase.example.com`, service **HTTP**, URL `localhost:<server port>`.
3. In the server's Startup tab paste the token in *Cloudflare Tunnel Token* and set *Public URL* to `https://supabase.example.com`.

Your apps then use `https://supabase.example.com` as the Supabase URL with the `ANON_KEY` from `secrets.env`.

## Files

| Path | Contents |
| --- | --- |
| `secrets.env` | Database password, JWT secret, API keys. Delete a line to generate a new value on the next start. |
| `postgres/` | Database files and the pgsodium/Vault root key. |
| `storage/` | Uploaded files. |
| `snippets/` | SQL snippets saved in Studio. |

Back up with the server stopped so the database files are consistent.

## How it works

The container's root filesystem is read-only under Wings, so every service is copied from its official image into one Debian image and all state lives in `/home/container`. A small supervisor (`/opt/supabase/bin/start`) runs the official database migrations on first start, starts each service with its own environment and stops everything if one of them dies. The Envoy configuration is the official one, pointed at `127.0.0.1`.

Unlike the official compose, loopback database connections require a password, because all services share one network namespace.

## License

Apache-2.0. Includes configuration and SQL files from [supabase/supabase](https://github.com/supabase/supabase) (Apache-2.0).
