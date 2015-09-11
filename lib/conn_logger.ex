defmodule Ewebmachine.App do
  @moduledoc false 
  use Application
  import Supervisor.Spec
  def start(_,_) do
    Supervisor.start_link([
      worker(Ewebmachine.Log,[]),
      worker(GenEvent,[[name: Ewebmachine.Events]])
    ], strategy: :one_for_one)
  end
end

defmodule Ewebmachine.Log do
  alias Plug.Conn
  use GenServer
  @moduledoc false

  def init([]), do:
    (:ets.new(:logs, [:ordered_set, :named_table]); {:ok,[]})
  def handle_cast(conn,_), do:
    (:ets.insert(:logs,{conn.private[:machine_log],conn}); {:noreply,[]})

  # Public API, self describing
  def start_link, do: 
    GenServer.start_link(__MODULE__,[], name: __MODULE__)
  def put(conn), do: 
    GenServer.cast(__MODULE__,conn)
  def list do # fold only needed file for log listing for perfs
    :ets.foldl(fn {_,%{method: m, path_info: pi, private: %{machine_log: l, machine_init_at: i}}},acc-> 
       [%Conn{method: m,path_info: pi, private: %{machine_log: l,machine_init_at: i}}|acc]
    end,[],:logs)
  end
  def get(id), do: 
    (case :ets.lookup(:logs,id) do [{_,conn}]->conn; _->nil end)
  def id, do:
    (make_ref |> :erlang.term_to_binary |> Base.url_encode64)

  # Conn modifiers called by automate during run
  def debug_init(conn) do
    if conn.private[:machine_debug] do
      conn
      |> Conn.put_private(:machine_log,id)
      |> Conn.put_private(:machine_init_at,:erlang.timestamp)
      |> Conn.put_private(:machine_decisions,[])
      |> Conn.put_private(:machine_calls,[])
    else conn end
  end
  def debug_call(conn,module,function,[in_conn,in_state],{resp,out_conn,out_state}) do
    if conn.private[:machine_log] !== nil and module !== Ewebmachine.Handlers do
      Conn.put_private(conn,:machine_calls,
        [{module,function,[%{in_conn|private: %{}},in_state],
                           {resp,%{out_conn|private: %{}},out_state}}
            |conn.private.machine_calls])
    else conn end
  end
  def debug_enddecision(conn) do
    if conn.private[:machine_log] do
      case conn.private.machine_decisions do
        [{decision,_}|rest] ->
          conn 
          |> Conn.put_private(:machine_decisions,[{decision,Enum.reverse(conn.private.machine_calls)}|rest])
          |> Conn.put_private(:machine_calls,[])
        _->conn
      end
    else conn end
  end
  def debug_decision(conn,decision) do
    if conn.private[:machine_log] do
      case Regex.run(~r/^v[0-9]([a-z]*[0-9]*)$/,to_string(decision)) do
        [_,decision]-> 
          conn = debug_enddecision(conn)
          Conn.put_private(conn,:machine_decisions,[{decision,[]}|conn.private.machine_decisions])
        _->conn
      end
    else conn end
  end
end

