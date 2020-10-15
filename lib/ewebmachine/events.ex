defmodule Ewebmachine.Events do
  def child_spec(_) do
    Registry.child_spec(keys: :duplicate, name: __MODULE__)
  end

  @dispatch_key :events
  def dispatch(log) do
    Registry.dispatch(__MODULE__, @dispatch_key, fn entries ->
      for {pid, nil} <- entries, do: send(pid,{:log,log})
    end)
  end

  import Plug.Conn
  def stream_chunks(conn) do
    conn = conn |>
      put_resp_header("content-type", "text/event-stream") |>
      send_chunked(200)
    {:ok, _} = Registry.register(__MODULE__,@dispatch_key,nil)
    conn = Stream.repeatedly(fn-> receive do {:log,log}-> log end end)
      |> Enum.reduce_while(conn, fn log, conn ->
        io = "event: new_query\ndata: #{log}\n\n"
        case chunk(conn,io) do {:ok,conn}->{:cont,conn};{:error,:closed}->{:halt,conn} end
      end)
    halt(conn)
  end
end
