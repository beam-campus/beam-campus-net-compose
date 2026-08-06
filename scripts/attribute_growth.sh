#!/usr/bin/env bash
# Where does the ~800MB/min of growth actually live? Snapshot per-process memory
# twice and diff by pid, plus the :erlang.memory/0 categories and ETS totals.
set -uo pipefail

HOST="${BCN_HOST:-root@178.105.157.209}"
KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"
GAP="${BCN_GAP:-40}"

ssh -o BatchMode=yes -i "$KEY" "$HOST" "GAP='$GAP' bash -s" <<'REMOTE'
set -uo pipefail

timeout 200 docker exec beam-campus-site /app/bin/beam_campus rpc '
snap = fn ->
  :erlang.processes()
  |> Enum.map(fn p ->
       case Process.info(p, [:memory, :message_queue_len, :dictionary, :current_function, :registered_name]) do
         nil -> nil
         i -> {p, i[:memory], i[:message_queue_len],
               Keyword.get(i[:dictionary] || [], :"$initial_call"),
               i[:current_function], i[:registered_name]}
       end
     end)
  |> Enum.reject(&is_nil/1)
end

a = snap.()
m_a = :erlang.memory()
Process.sleep(String.to_integer(System.get_env("GAP", "40")) * 1000)
b = snap.()
m_b = :erlang.memory()

IO.puts("--- :erlang.memory/0 delta (bytes) ---")
Enum.each(m_a, fn {k, v} -> IO.inspect({k, v, Keyword.get(m_b, k) - v}) end)

am = Map.new(a, fn {p, m, _, _, _, _} -> {p, m} end)

IO.puts("")
IO.puts("--- top 12 GROWERS by per-process delta ---")
b
|> Enum.map(fn {p, m, q, init, cur, name} -> {p, m, m - Map.get(am, p, 0), q, init, cur, name} end)
|> Enum.sort_by(fn {_, _, d, _, _, _, _} -> -d end)
|> Enum.take(12)
|> Enum.each(fn {p, m, d, q, init, cur, name} ->
     IO.inspect({p, :mem, m, :grew, d, :q, q, :name, name, :was, init, :now, cur}, limit: :infinity)
   end)

IO.puts("")
IO.puts("--- process count, and how many are NEW ---")
IO.inspect({:count_a, length(a), :count_b, length(b),
            :new, Enum.count(b, fn {p, _, _, _, _, _} -> not Map.has_key?(am, p) end)})

IO.puts("")
IO.puts("--- top ETS tables (bytes) ---")
:ets.all()
|> Enum.map(fn t ->
     {(try do :ets.info(t, :name) rescue _ -> :dead end),
      (try do :ets.info(t, :memory) * :erlang.system_info(:wordsize) rescue _ -> 0 end),
      (try do :ets.info(t, :size) rescue _ -> 0 end)}
   end)
|> Enum.sort_by(fn {_, m, _} -> -m end)
|> Enum.take(8)
|> Enum.each(&IO.inspect/1)
' 2>&1 | tail -45
REMOTE
