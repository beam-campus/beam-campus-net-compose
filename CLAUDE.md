# CLAUDE.md — beam-campus-net-compose

Deployment descriptor for **beam-campus.net**. Clone to the box; it PULLS the
`ghcr.io/beam-campus/beam-campus-net` image from ghcr.io and runs it behind Caddy.
Mirrors `macula-realm-compose`.

## Rules
- **Never build here** — the image is built by `beam-campus-net` CI. This repo
  only pulls. If a change needs a rebuild, it belongs in `beam-campus-net`.
- **Codeberg canonical** — push to `origin` (codeberg.org/beam-campus/…), never
  GitHub first. GitHub is the CI mirror.
- Secrets live in `.env` on the box only — never committed.
- TLS is Caddy's job (automatic Let's Encrypt). DNS at Linode.

## Deploy model — ZERO-TOUCH (like macula-realm-compose)
Routine deploys are **not** run by hand. Push to `beam-campus-net` → CI publishes a
new `:latest` to ghcr → **Watchtower** (in `docker-compose.yml`, running by default,
60s poll, label-enabled) auto-pulls and rolling-restarts the site. No ssh, no
`deploy.sh update`. The scripts are **bootstrap only** (`init`/`up`/`logs`/`down`).

**One-time prerequisite for auto-pull:** the box must be able to pull the image —
make `ghcr.io/beam-campus/beam-campus-net` **public** (GitHub Package settings →
visibility), or put a read-only registry PAT in `./docker-config.json` on the box and
mount it into the watchtower service (as macula-realm-compose does).

## Box
`178.105.157.209` (Hetzner, `beam-campus-net`). Deploy dir:
`/opt/beam-campus-net-compose`. Bootstrap once: `docker compose up -d` (or
`./scripts/deploy.sh up`); thereafter Watchtower keeps it current.
