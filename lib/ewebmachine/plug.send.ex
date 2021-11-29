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
      conn =
        if stream do
          conn = send_chunked(conn,conn.status)
          conn = Enum.reduce_while(stream, conn, fn chunk, conn ->
            case Plug.Conn.chunk(conn, chunk) do
              {:ok, conn} ->
                {:cont, conn}
              {:error, :closed} ->
                {:halt, conn}
            end
          end)
          conn
        else
          send_resp(conn)
        end
      halt(conn)
    else
      conn
    end
  end
end
