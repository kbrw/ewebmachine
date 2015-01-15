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
    else conn end
  end
  def debug_decision(conn,decision) do
    Conn.put_private(conn,:machine_decisions,[decision|conn.private.machine_decisions])
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
    html = render_log(Log.get(id),conn)
    conn |> send_resp(200,html) |> halt
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

  def to_draw(conn), do: %{
    request: %{
      method: "#{conn.method}",
      path: Conn.full_path(conn),
      headers: Enum.into(conn.req_headers,%{}),
      body: case Conn.read_body(conn) do
          {:ok,body,_}->body
          _ -> ""
        end
    },
    response: %{
      code: conn.status,
      headers: Enum.into(conn.resp_headers,%{}),
      body: (conn.resp_body || "")
    },
    trace: [
      %{
        d: "v3b13",
        calls: [%{
          module: "module",     
          function: "function",
          input: "inspect(input conn)",
          output: "inspect(input conn)"
        }]
      }
    ]
  }

  defmodule EventHandler do
    use GenEvent
    def handle_event(log_id,conn) do #Send all builder events to browser through SSE
      Plug.Conn.chunk(conn, "event: new_query\ndata: #{log_id}\n\n")
      {:ok, conn}
    end
  end
end
