#!/usr/bin/env bash
# Is the mesh ingest backlog GROWING or DRAINING? Sample the station-link
# mailboxes twice, 45s apart. Growing = ingest exceeds what the node can verify,
# and no read-side fix saves it.
set -uo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"
GAP="${BCN_GAP:-45}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" "GAP='$GAP' bash -s" <<'REMOTE'
set -uo pipefail

sample() {
  timeout 90 docker exec beam-campus-site /app/bin/beam_campus rpc '
  links = :erlang.processes()
  |> Enum.map(fn p -> {p, Process.info(p, [:memory, :message_queue_len, :dictionary])} end)
  |> Enum.reject(fn {_, i} -> is_nil(i) end)
  |> Enum.filter(fn {_, i} ->
       inspect(Keyword.get(i[:dictionary] || [], :"$initial_call")) =~ "macula"
     end)
  |> Enum.map(fn {p, i} -> {p, i[:message_queue_len], i[:memory]} end)
  |> Enum.sort_by(fn {_, q, _} -> -q end)
  |> Enum.take(8)

  IO.inspect({:ts, System.system_time(:second), :total_q, Enum.sum(Enum.map(links, &elem(&1, 1))),
              :total_mem, Enum.sum(Enum.map(links, &elem(&1, 2))),
              :beam_total, :erlang.memory(:total)})
  Enum.each(links, &IO.inspect/1)
  ' 2>&1 | tail -12
}

echo "===== sample 1 ====="
sample
echo
echo "... waiting ${GAP}s ..."
sleep "$GAP"
echo
echo "===== sample 2 ====="
sample

echo
echo "===== macula link health ====="
timeout 90 docker exec beam-campus-site /app/bin/beam_campus rpc '
Enum.each([Dronex.Mesh, Asociety.Mesh, Biotope.Mesh], fn m ->
  try do
    IO.inspect({m, m.handle()})
  rescue
    e -> IO.inspect({m, :error, e.__struct__})
  end
end)
' 2>&1 | tail -8
REMOTE
