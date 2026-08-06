#!/usr/bin/env bash
# Collect crash diagnostics from the beam-campus.net box in ONE ssh session.
set -uo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"
DEPLOY_DIR="${BCN_DEPLOY_DIR:-/opt/beam-campus-net-compose}"
LOG_LINES="${BCN_LOG_LINES:-200}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" \
  "DEPLOY_DIR='$DEPLOY_DIR' LOG_LINES='$LOG_LINES' bash -s" <<'REMOTE'
set -uo pipefail

echo "===== uptime / load ====="
uptime

echo
echo "===== memory ====="
free -h

echo
echo "===== disk ====="
df -h / /var/lib/docker 2>/dev/null

echo
echo "===== docker ps (all) ====="
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

echo
echo "===== restart counts / exit codes / OOM ====="
for c in $(docker ps -aq); do
  docker inspect --format '{{.Name}} restarts={{.RestartCount}} state={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} started={{.State.StartedAt}} finished={{.State.FinishedAt}}' "$c"
done

echo
echo "===== kernel OOM kills (last 50) ====="
dmesg -T 2>/dev/null | grep -iE 'out of memory|oom-kill|killed process' | tail -50

echo
echo "===== app logs (last ${LOG_LINES}) ====="
cd "$DEPLOY_DIR" 2>/dev/null && docker compose logs --no-color --tail="${LOG_LINES}" 2>&1 | tail -n "${LOG_LINES}"
REMOTE
