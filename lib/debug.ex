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

  defmodule EventHandler do
    use GenEvent
    def handle_event(log_id,conn) do #Send all builder events to browser through SSE
      Plug.Conn.chunk(conn, "event: new_query\ndata: #{log_id}\n\n")
      {:ok, conn}
    end
  end

  def to_draw(conn), do: %{
    request: """
    #{conn.method} #{Conn.full_path(conn)} HTTP/1.1
    #{html_escape format_headers(conn.req_headers)}

    #{html_escape body_of(conn)}
    """,
    response: %{
      http: """
      HTTP/1.1 #{conn.status} #{http_label(conn.status)} 
      #{html_escape format_headers(conn.resp_headers)}

      #{html_escape conn.resp_body}
      """,
      code: conn.status
    },
    trace: Enum.map(Enum.reverse(conn.private.machine_decisions), fn {decision,calls}->
      %{
        d: decision,
        calls: Enum.map(calls,fn {module,function,[in_conn,in_state],{resp,out_conn,out_state}}->
          %{
            module: inspect(module),
            function: "#{function}",
            input: """
            state = #{html_escape inspect(in_state, pretty: true)}

            conn = #{html_escape inspect(%{in_conn|private: %{}}, pretty: true)}
            """,
            output: """
            response = #{html_escape inspect(resp, pretty: true)}

            state = #{html_escape inspect(out_state, pretty: true)}

            conn = #{html_escape inspect(%{out_conn|private: %{}}, pretty: true)}
            """
          }
        end)
      }
    end)
  }

  defp body_of(conn) do
    case Conn.read_body(conn) do
      {:ok,body,_}->body
      _ -> ""
    end
  end

  defp format_headers(headers) do
    headers |> Enum.map(fn {k,v}->"#{k}: #{v}\n" end) |> Enum.join
  end

  def html_escape(data), do:
    to_string(for(<<char::utf8<-IO.iodata_to_binary(data)>>, do: escape_char(char)))
  def escape_char(?<), do: "&lt;"
  def escape_char(?>), do: "&gt;"
  def escape_char(?&), do: "&amp;"
  def escape_char(?"), do: "&quot;"
  def escape_char(?'), do: "&#39;"
  def escape_char(c), do: c

  defp http_label(100), do: "Continue"
  defp http_label(101), do: "Switching Protocol"
  defp http_label(200), do: "OK"
  defp http_label(201), do: "Created"
  defp http_label(202), do: "Accepted"
  defp http_label(203), do: "Non-Authoritative Information"
  defp http_label(204), do: "No Content"
  defp http_label(205), do: "Reset Content"
  defp http_label(206), do: "Partial Content"
  defp http_label(300), do: "Multiple Choice"
  defp http_label(301), do: "Moved Permanently"
  defp http_label(302), do: "Found"
  defp http_label(303), do: "See Other"
  defp http_label(304), do: "Not Modified"
  defp http_label(305), do: "Use Proxy"
  defp http_label(306), do: "unused"
  defp http_label(307), do: "Temporary Redirect"
  defp http_label(308), do: "Permanent Redirect"
  defp http_label(400), do: "Bad Request"
  defp http_label(401), do: "Unauthorized"
  defp http_label(402), do: "Payment Required"
  defp http_label(403), do: "Forbidden"
  defp http_label(404), do: "Not Found"
  defp http_label(405), do: "Method Not Allowed"
  defp http_label(406), do: "Not Acceptable"
  defp http_label(407), do: "Proxy Authentication Required"
  defp http_label(408), do: "Request Timeout"
  defp http_label(409), do: "Conflict"
  defp http_label(410), do: "Gone"
  defp http_label(411), do: "Length Required"
  defp http_label(412), do: "Precondition Failed"
  defp http_label(413), do: "Request Entity Too Large"
  defp http_label(414), do: "Request-URI Too Long"
  defp http_label(415), do: "Unsupported Media Type"
  defp http_label(416), do: "Requested Range Not Satisfiable"
  defp http_label(417), do: "Expectation Failed"
  defp http_label(500), do: "Internal Server Error"
  defp http_label(501), do: "Not Implemented"
  defp http_label(502), do: "Bad Gateway"
  defp http_label(503), do: "Service Unavailable"
  defp http_label(504), do: "Gateway Timeout"
  defp http_label(505), do: "HTTP Version Not Supported"
end
