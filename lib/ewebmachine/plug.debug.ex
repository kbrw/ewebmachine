defmodule Ewebmachine.Plug.Debug do
  @moduledoc ~S"""
  A plug providing a debug UI for the decision tree available at `/wm_debug`.

  Add it before `Ewebmachine.Plug.Run` in your plug pipeline when you
  want debugging facilities.

  ```elixir
  if Mix.env() == :dev, do: plug Ewebmachine.Plug.Debug
  ```

  Then go to `http://<host>:<port>/wm_debug`, you will see the request list
  since the launch of your server. Click on any to get the Ewebmachine
  debugging UI. The list will be automatically updated on new query.

  The Ewebmachine debugging UI shows you the path taken by the request through
  the decision tree. Decisions where user defined handlers are called are
  highlighted in red. Clicking on decision will open a panel with three tabs:
  * `Q`: contains the received http request
  * `R`: contains the sent http response
  * `D`: displays the `conn` and the `state` before and after the handler
    call. The handler's response is also displayed.

  The `auto redirect on new query` will at every request redirect your browser
  to the new request debugging UI.

  ![Debug UI example](./assets/debug_ui.png)
  """
  use Plug.Router

  alias Plug.Conn
  alias Ewebmachine.Log

  plug Plug.Static, at: "/wm_debug/static", from: :ewebmachine
  plug :match
  plug :dispatch

  require EEx
  EEx.function_from_file(:defp, :render_logs, "templates/log_list.html.eex", [:conns])
  EEx.function_from_file(:defp, :render_log, "templates/log_view.html.eex", [:logconn, :conn])

  get "/wm_debug/log/:id" do
    if logconn = Log.get(id) do
      conn |> send_resp(200, render_log(logconn, conn)) |> halt
    else
      conn |> put_resp_header("location", "/wm_debug") |> send_resp(302, "") |> halt
    end
  end

  get "/wm_debug" do
    html = render_logs(Log.list())
    conn |> send_resp(200, html) |> halt
  end

  get "/wm_debug/events" do
    Ewebmachine.Events.stream_chunks(conn)
  end

  match _ do
    put_private(conn, :machine_debug, true)
  end

  @doc false
  def to_draw(conn) do
    %{
      request: """
      #{conn.method} #{conn.request_path} HTTP/1.1
      #{html_escape(format_headers(conn.req_headers))}
      #{html_escape(body_of(conn))}
      """,
      response: %{
        http: """
        HTTP/1.1 #{conn.status} #{Ewebmachine.Core.Utils.http_label(conn.status)} 
        #{html_escape(format_headers(conn.resp_headers))}
        #{html_escape(conn.resp_body || "some chunked body")}
        """,
        code: conn.status
      },
      trace:
        Enum.map(Enum.reverse(conn.private.machine_decisions), fn {decision, calls} ->
          %{
            d: decision,
            calls:
              Enum.map(calls, fn {module, function, [in_conn, in_state],
                                  {resp, out_conn, out_state}} ->
                %{
                  module: inspect(module),
                  function: "#{function}",
                  input: """
                  state = #{html_escape(inspect(in_state, pretty: true))}

                  conn = #{html_escape(inspect(in_conn, pretty: true))}
                  """,
                  output: """
                  response = #{html_escape(inspect(resp, pretty: true))}

                  state = #{html_escape(inspect(out_state, pretty: true))}

                  conn = #{html_escape(inspect(out_conn, pretty: true))}
                  """
                }
              end)
          }
        end)
    }
  end

  defp body_of(conn) do
    case Conn.read_body(conn) do
      {:ok, body, _} -> body
      _ -> ""
    end
  end

  defp format_headers(headers) do
    headers |> Enum.map(fn {k, v} -> "#{k}: #{v}\n" end) |> Enum.join()
  end

  defp html_escape(data),
    do: to_string(for(<<char::utf8 <- IO.iodata_to_binary(data)>>, do: escape_char(char)))

  defp escape_char(?<), do: "&lt;"
  defp escape_char(?>), do: "&gt;"
  defp escape_char(?&), do: "&amp;"
  defp escape_char(?"), do: "&quot;"
  defp escape_char(?'), do: "&#39;"
  defp escape_char(c), do: c
end
