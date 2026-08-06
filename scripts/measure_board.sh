#!/usr/bin/env bash
# Measure what fills :dronex_board WITHOUT copying the whole table.
#
# ⚠ An earlier version of this script called :ets.tab2list/1, which is the exact
# operation that is crashing the site: it copies the whole ~120MB table into the
# calling process. Walk the keys with first/next and look up ONE row at a time.
set -uo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" bash -s <<'REMOTE'
set -uo pipefail

echo "===== per-row size, walked one key at a time (top 12) ====="
timeout 120 docker exec beam-campus-site /app/bin/beam_campus rpc '
w = :erlang.system_info(:wordsize)

keys = Stream.unfold(:ets.first(:dronex_board), fn
  :"$end_of_table" -> nil
  k -> {k, :ets.next(:dronex_board, k)}
end) |> Enum.to_list()

rows = Enum.map(keys, fn k ->
  [{^k, v}] = :ets.lookup(:dronex_board, k)
  shape = case k do
    {:raid, id} -> "raid:" <> String.slice(id, 0, 10)
    b when is_binary(b) -> "island:" <> String.slice(b, 0, 10)
    a -> inspect(a)
  end
  parts = case v do
    %{parts: p} -> Enum.map(p, fn {pk, pl} -> {pk, length(pl)} end)
    %{facts: f} -> Map.keys(f)
    _ -> []
  end
  bytes = :erts_debug.size(v) * w
  {shape, bytes, parts}
end)

IO.inspect({:total_keys, length(keys), :total_bytes, Enum.sum(Enum.map(rows, &elem(&1, 1)))})
rows |> Enum.sort_by(&(-elem(&1, 1))) |> Enum.take(12) |> Enum.each(&IO.inspect(&1, limit: :infinity))
' 2>&1 | tail -18

echo
echo "===== one recording: frame count, bytes, keys ====="
timeout 120 docker exec beam-campus-site /app/bin/beam_campus rpc '
w = :erlang.system_info(:wordsize)
k = Stream.unfold(:ets.first(:dronex_board), fn
      :"$end_of_table" -> nil
      k -> {k, :ets.next(:dronex_board, k)}
    end)
    |> Enum.find(fn
      {:raid, _} -> true
      _ -> false
    end)

[{^k, v}] = :ets.lookup(:dronex_board, k)
Enum.each(v.parts, fn {kind, list} ->
  f = hd(list)
  IO.inspect({kind, :held, length(list), :frames, length(Map.get(f, "frames", [])),
              :bytes_each, :erts_debug.size(f) * w, :keys, Map.keys(f)}, limit: :infinity)
end)
' 2>&1 | tail -10

echo
echo "===== top process consumers ====="
timeout 120 docker exec beam-campus-site /app/bin/beam_campus rpc '
:erlang.processes()
|> Enum.map(fn p -> {p, Process.info(p, [:memory, :message_queue_len, :dictionary, :current_function])} end)
|> Enum.reject(fn {_, i} -> is_nil(i) end)
|> Enum.sort_by(fn {_, i} -> -i[:memory] end)
|> Enum.take(10)
|> Enum.each(fn {p, i} ->
  IO.inspect({p, :mem, i[:memory], :q, i[:message_queue_len],
              :now, i[:current_function],
              :was, Keyword.get(i[:dictionary] || [], :"$initial_call")}, limit: :infinity)
end)
IO.inspect({:erlang_total, :erlang.memory(:total), :processes, :erlang.memory(:processes), :ets, :erlang.memory(:ets)})
' 2>&1 | tail -14
REMOTE
