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

## Box
`178.105.157.209` (Hetzner, `beam-campus-net`). Deploy dir:
`/opt/beam-campus-net-compose`. `./scripts/deploy.sh {init|up|update|logs|down}`.
