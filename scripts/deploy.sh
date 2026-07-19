#!/usr/bin/env bash
# BEAM Campus — deploy / update the site on the box.
#
#   ./scripts/deploy.sh init    # first-time: check .env, pull, up
#   ./scripts/deploy.sh up      # start / recreate
#   ./scripts/deploy.sh update  # pull newest image + recreate (Watchtower also does this)
#   ./scripts/deploy.sh logs    # tail site + caddy logs
#   ./scripts/deploy.sh down     # stop
set -euo pipefail
cd "$(dirname "$0")/.."

require_env () {
  [ -f .env ] || { echo "!! .env missing — cp .env.example .env and set SECRET_KEY_BASE"; exit 1; }
  grep -q '^SECRET_KEY_BASE=.\+' .env || { echo "!! SECRET_KEY_BASE is empty in .env"; exit 1; }
}

case "${1:-up}" in
  init)
    require_env
    docker compose pull
    docker compose up -d
    echo "up. Caddy will fetch Let's Encrypt certs once DNS points here."
    ;;
  up)      require_env; docker compose up -d ;;
  update)  require_env; docker compose pull && docker compose up -d ;;
  logs)    docker compose logs -f --tail=100 site caddy ;;
  down)    docker compose down ;;
  *)       echo "usage: $0 {init|up|update|logs|down}"; exit 2 ;;
esac
