#!/usr/bin/env bash
# Focused look at the beam-campus-site container: memory now, limits, and its own logs.
set -uo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"
DEPLOY_DIR="${BCN_DEPLOY_DIR:-/opt/beam-campus-net-compose}"
LOG_LINES="${BCN_LOG_LINES:-120}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" \
  "DEPLOY_DIR='$DEPLOY_DIR' LOG_LINES='$LOG_LINES' bash -s" <<'REMOTE'
set -uo pipefail

echo "===== container memory now ====="
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}'

echo
echo "===== site memory limit / restart policy ====="
docker inspect beam-campus-site --format 'Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}} RestartPolicy={{.HostConfig.RestartPolicy.Name}} Image={{.Config.Image}}'

echo
echo "===== erlang memory breakdown (via release rpc) ====="
docker exec beam-campus-site /app/bin/beam_campus rpc \
  'IO.inspect(:erlang.memory()); IO.inspect({:processes, :erlang.system_info(:process_count)}); IO.inspect({:ports, :erlang.system_info(:port_count)}); IO.inspect({:ets, length(:ets.all())})' 2>&1 | tail -30

echo
echo "===== top 10 processes by memory ====="
docker exec beam-campus-site /app/bin/beam_campus rpc \
  ':erlang.processes() |> Enum.map(fn p -> {p, Process.info(p, [:memory, :message_queue_len, :registered_name, :current_function, :initial_call])} end) |> Enum.reject(fn {_, i} -> is_nil(i) end) |> Enum.sort_by(fn {_, i} -> -i[:memory] end) |> Enum.take(10) |> Enum.each(&IO.inspect(&1, limit: :infinity))' 2>&1 | tail -30

echo
echo "===== top 10 ETS tables by memory ====="
docker exec beam-campus-site /app/bin/beam_campus rpc \
  ':ets.all() |> Enum.map(fn t -> {(try do :ets.info(t, :name) rescue _ -> :dead end), (try do :ets.info(t, :memory) * :erlang.system_info(:wordsize) rescue _ -> 0 end), (try do :ets.info(t, :size) rescue _ -> 0 end)} end) |> Enum.sort_by(fn {_, m, _} -> -m end) |> Enum.take(10) |> Enum.each(&IO.inspect/1)' 2>&1 | tail -20

echo
echo "===== site logs (last ${LOG_LINES}) ====="
docker logs --tail "${LOG_LINES}" beam-campus-site 2>&1
REMOTE
