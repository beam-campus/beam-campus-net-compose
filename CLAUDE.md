# CLAUDE.md — beam-campus-net-compose

Deployment descriptor for **beam-campus.net**. Clone to the box; it PULLS the
`ghcr.io/beam-campus/beam-campus-net` image from ghcr.io and runs it behind Caddy.
Mirrors `macula-realm-compose`.

## Rules
- **Never build here** — the image is built by `beam-campus-net` CI. This repo
  only pulls. If a change needs a rebuild, it belongs in `beam-campus-net`.
- **GitHub canonical** (since 2026-07-26) — `origin` is
  `github.com/beam-campus/beam-campus-net-compose`, branch `main`. Do NOT push to
  Codeberg: that copy is soon to be deleted. *This rule said the exact opposite
  until 2026-08-06, and the reversal is why it is dated.* Codeberg added Terms of
  Use § 2 (1) 7 by member vote on 2026-07-22, banning projects that mostly
  consist of AI-generated code, and the work moved out.
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

## ⚠ Watchtower keeps the IMAGE current. It never re-reads this file.

Zero-touch covers code and **not config**. A change to `docker-compose.yml` —
`mem_limit`, an env var, a network setting — sits in git doing nothing until
somebody pulls it on the box. From a laptop the two look identical: both are a
commit that was pushed, and only one of them arrived.

    ./scripts/apply_on_box.sh     # git pull + deploy.sh up, and prints before/after

## The box is 1.9 GB, and the facts it reads are megabytes

`mem_limit: 1400m` + `memswap_limit: 1400m` (equal = no swap) since 2026-08-06.
The site had been OOM-killed roughly every two hours: one DroneX raid recording
is 1.2 MB, the board held 64 of them, and every read copied the whole table.
Fixed in `beam-campus-net`; the ceiling is the guard for the next one, so Docker
kills the site alone instead of the kernel choosing between it, Caddy and the
warden. No swap is deliberate — with 4 GB behind it the node did not die, it
thrashed for an hour while even an `rpc` asking what was wrong timed out.

Diagnosis scripts live in `scripts/`: `diagnose.sh`, `diagnose_site.sh`,
`measure_board.sh`, `watch_ingest.sh`, `attribute_growth.sh`, `verify_fix.sh`.
⚠ Never walk a mesh-fed ETS table with `:ets.tab2list/1` to inspect it —
`measure_board.sh` did that in its first version and had to be killed mid-run,
because it is the same operation that was crashing the site.

## Box
`178.105.157.209` (Hetzner, `beam-campus-net`). Deploy dir:
`/opt/beam-campus-net-compose`. Bootstrap once: `docker compose up -d` (or
`./scripts/deploy.sh up`); thereafter Watchtower keeps the image current.
