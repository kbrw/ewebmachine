defmodule Ewebmachine.App do
  @moduledoc false 
  use Application
  import Supervisor.Spec
  def start(_,_), do:
    Supervisor.start_link([
      supervisor(Ewebmachine.Log,[]),
      worker(GenEvent,[[name: Ewebmachine.Events]])
    ], strategy: :one_for_one)
end

defmodule Ewebmachine.Log do
  alias Plug.Conn
  @moduledoc false

  # Public API, self describing
  def start_link, do:
    Agent.start_link(fn->[] end, name: __MODULE__)
  def put(conn), do:
    Agent.update(__MODULE__,fn l->[conn|l] end)
  def list, do:
    Agent.get(__MODULE__,& &1)
  def get(id), do:
    Agent.get(__MODULE__,fn l->Enum.find(l,&(&1.private[:machine_log]==id)) end)
  def id, do:
    (make_ref |> :erlang.term_to_binary |> Base.url_encode64)

  # Conn modifiers called by automate during run
  def debug_init(conn) do
    if conn.private[:machine_debug] do
      conn
      |> Conn.put_private(:machine_log,id)
      |> Conn.put_private(:machine_init_at,:erlang.now)
      |> Conn.put_private(:machine_decisions,[])
      |> Conn.put_private(:machine_calls,[])
    else conn end
  end
  def debug_call(conn,module,function,in_args,out_term) do
    if conn.private[:machine_log] !== nil and module !== Ewebmachine.Handlers do
      Conn.put_private(conn,:machine_calls,
        [{module,function,in_args,out_term}|conn.private.machine_calls])
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

