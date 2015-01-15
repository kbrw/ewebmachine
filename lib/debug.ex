defmodule Ewebmachine.App do
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
    if conn.private[:machine_log] do
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

defmodule Ewebmachine.DebugPlug do
  use Plug.Router
  alias Plug.Conn
  alias Ewebmachine.Log
  plug Plug.Static, at: "/wm_debug/static", from: :ewebmachine
  plug :match
  plug :dispatch

  require EEx
  EEx.function_from_file :defp, :render_logs, "templates/log_list.html.eex", [:conns]
  EEx.function_from_file :defp, :render_log, "templates/log_view.html.eex", [:logconn,:conn]

  get "/wm_debug/log/:id" do
    if (logconn=Log.get(id)) do
      conn |> send_resp(200,render_log(logconn,conn)) |> halt
    else
      conn |> put_resp_header("location","/wm_debug") |> send_resp(302,"") |> halt
    end
  end

  get "/wm_debug" do
    html = render_logs(Log.list)
    conn |> send_resp(200,html) |> halt
  end

  get "/wm_debug/events" do
    conn=conn |> put_resp_header("content-type", "text/event-stream") |> send_chunked(200)
    GenEvent.add_mon_handler(Ewebmachine.Events,{Ewebmachine.DebugPlug.EventHandler,make_ref},conn)
    receive do {:gen_event_EXIT,_,_} -> halt(conn) end
  end

  match _ do
    conn 
    |> put_private(:machine_debug,true)
    |> register_before_send(fn conn->
        if (log=conn.private[:machine_log]) do
          Ewebmachine.Log.put(conn)
          GenEvent.notify(Ewebmachine.Events,log)
        end
        conn
    end)
  end

  defp body_of(conn) do
    case Conn.read_body(conn) do
      {:ok,body,_}->body
      _ -> ""
    end
  end

  defp format_headers(headers) do
    headers |> Enum.map(fn {k,v}->"#{k}: #{v}\n" end) |> Enum.join
  end

  def to_draw(conn), do: %{
    request: """
    #{conn.method} #{Conn.full_path(conn)} HTTP/1.1
    #{format_headers(conn.req_headers)}

    #{body_of(conn)}
    """,
    response: %{
      http: """
      HTTP/1.1 #{conn.status} Status 
      #{format_headers(conn.resp_headers)}

      #{conn.resp_body}
      """,
      code: conn.status
    },
    trace: Enum.map(Enum.reverse(conn.private.machine_decisions), fn {decision,calls}->
      %{
        d: decision,
        calls: Enum.map(calls,fn {module,function,[callconn,state],out_term}->
          %{
            module: inspect(module),
            function: "#{function}",
            input: inspect({state,%{callconn|private: %{}}}, pretty: true),
            output: inspect(out_term, pretty: true)
          }
        end)
      }
    end)
  }

  defmodule EventHandler do
    use GenEvent
    def handle_event(log_id,conn) do #Send all builder events to browser through SSE
      Plug.Conn.chunk(conn, "event: new_query\ndata: #{log_id}\n\n")
      {:ok, conn}
    end
  end
end
