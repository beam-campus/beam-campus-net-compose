# beam-campus-net-compose

Production deployment for **beam-campus.net** — the descriptor you clone onto
the dedicated box. It **pulls** the prebuilt image
`ghcr.io/beam-campus/beam-campus-net` from ghcr.io (built by CI) and runs it behind
Caddy with automatic Let's Encrypt; Watchtower keeps it current.

Mirrors `macula-internal/macula-realm-compose`.

## Stack

| Service | What |
|---------|------|
| `site` | `ghcr.io/beam-campus/beam-campus-net` — Phoenix LiveView site, SQLite on the `site-data` volume |
| `caddy` | reverse proxy + automatic Let's Encrypt (80/443) |
| `watchtower` | auto-updates `site` when a new `:latest` is pushed |

## First deploy (on the box)

```bash
git clone https://codeberg.org/beam-campus/beam-campus-net-compose /opt/beam-campus-net-compose
cd /opt/beam-campus-net-compose
cp .env.example .env
# set SECRET_KEY_BASE (openssl rand -base64 48); confirm PHX_HOST / SITE_ADDRESS
./scripts/deploy.sh init
```

DNS for `beam-campus.net` (+ `www`) must point at the box so Caddy can pass the
ACME challenge. Managed at Linode.

## Update

Watchtower pulls new images every 5 min. To force it now:

```bash
./scripts/deploy.sh update
```

## Where the image comes from

`beam-campus-net` CI (GitHub Actions, via the Codeberg push-mirror) builds
`Dockerfile.prod` and pushes `ghcr.io/beam-campus/beam-campus-net:latest` + a semver tag
to ghcr.io. This repo only ever pulls.
