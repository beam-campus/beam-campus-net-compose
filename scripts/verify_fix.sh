#!/usr/bin/env bash
# Confirm the fix is the code that is RUNNING, then watch the memory curve.
#
# The question is not "is it up" — it was up for two hours at a time before. It
# is whether total memory is FLAT or CLIMBING while facts keep arriving. One
# sample proves nothing; the old build grew about 14 MB/s.
set -euo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"
SAMPLES="${BCN_SAMPLES:-8}"
GAP="${BCN_GAP:-60}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" "SAMPLES='$SAMPLES' GAP='$GAP' bash -s" <<'REMOTE'
set -uo pipefail

echo "===== is the FIX the code that is running? ====="
timeout 90 docker exec beam-campus-site /app/bin/beam_campus rpc '
IO.inspect({:recordings_table, :ets.whereis(:dronex_recordings) != :undefined})
IO.inspect({:board_exports_recording, function_exported?(Dronex.WatchBouts.Board, :recording, 1)})
IO.inspect({:dronex_exports_recording, function_exported?(Dronex, :recording, 1)})
' 2>&1 | tail -5

echo
echo "===== memory curve: total, board bytes, recordings bytes, worst mailbox ====="
for i in $(seq 1 "$SAMPLES"); do
  timeout 90 docker exec beam-campus-site /app/bin/beam_campus rpc '
  w = :erlang.system_info(:wordsize)
  bytes = fn t ->
    case :ets.whereis(t) do
      :undefined -> 0
      _ -> :ets.info(t, :memory) * w
    end
  end
  rows = fn t ->
    case :ets.whereis(t) do
      :undefined -> 0
      _ -> :ets.info(t, :size)
    end
  end
  worst =
    :erlang.processes()
    |> Enum.map(fn p -> (Process.info(p, :message_queue_len) || {:x, 0}) |> elem(1) end)
    |> Enum.max(fn -> 0 end)

  IO.inspect({
    :total_mb, div(:erlang.memory(:total), 1_048_576),
    :board_kb, div(bytes.(:dronex_board), 1024),
    :raids, rows.(:dronex_board),
    :reels_mb, div(bytes.(:dronex_recordings), 1_048_576),
    :reels, rows.(:dronex_recordings),
    :worst_mailbox, worst
  })
  ' 2>&1 | tail -2
  [ "$i" -lt "$SAMPLES" ] && sleep "$GAP"
done

echo
echo "===== container view ====="
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}'
docker inspect beam-campus-site --format 'restarts={{.RestartCount}} state={{.State.Status}} oom={{.State.OOMKilled}} started={{.State.StartedAt}}'
free -h | head -2
REMOTE
