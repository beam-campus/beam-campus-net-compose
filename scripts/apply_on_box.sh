#!/usr/bin/env bash
# Pull this repo on the box and re-up, so COMPOSE changes take effect.
#
# ⚠ Watchtower does NOT do this. It pulls IMAGES; it never re-reads
# docker-compose.yml. A change to mem_limit, an env var or a network setting sits
# in git doing nothing until someone runs this. That is the whole reason the
# script exists: the deploy is zero-touch for code and manual for config, and
# those two look identical from a laptop.
set -euo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"
DEPLOY_DIR="${BCN_DEPLOY_DIR:-/opt/beam-campus-net-compose}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" "DEPLOY_DIR='$DEPLOY_DIR' bash -s" <<'REMOTE'
set -euo pipefail
cd "$DEPLOY_DIR"

echo "===== before ====="
git log --oneline -1
docker inspect beam-campus-site \
  --format 'mem_limit={{.HostConfig.Memory}} memswap={{.HostConfig.MemorySwap}} image={{.Config.Image}}'

echo
echo "===== pull ====="
git pull --ff-only
git log --oneline -1

echo
echo "===== up ====="
./scripts/deploy.sh up

echo
echo "===== after ====="
docker inspect beam-campus-site \
  --format 'mem_limit={{.HostConfig.Memory}} memswap={{.HostConfig.MemorySwap}} image={{.Config.Image}}'
docker ps --format 'table {{.Names}}\t{{.Status}}'
REMOTE
