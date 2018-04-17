defmodule Ewebmachine.Plug.Send do
  @moduledoc ~S"""
  Calling this plug will send the response and halt the connection
  pipeline if the `conn` has passed through an `Ewebmachine.Plug.Run`.
  """
  import Plug.Conn

  @doc false
  def init(_opts), do: []

  @doc false
  def call(conn, _opts) do
    if conn.state == :set do
      stream = conn.private[:machine_body_stream]
      if (stream) do
        conn = send_chunked(conn,conn.status)
        Enum.each(stream,&chunk(conn,&1))
        conn
      else
        send_resp(conn)
      end |> halt()
    else
      conn
    end
  end
end
