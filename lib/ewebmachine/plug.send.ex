defmodule Ewebmachine.Plug.Send do
  @moduledoc ~S"""
  A plug which sends the response and halts the pipeline if the state is `:set`.

  Should be used in a plug pipeline after the `Ewebmachine.Plug.Run` plug.
  """
  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(_opts), do: []

  @impl Plug
  def call(conn, _opts) do
    if conn.state == :set do
      stream = conn.private[:machine_body_stream]

      conn =
        if stream do
          conn = send_chunked(conn, conn.status)

          conn =
            Enum.reduce_while(stream, conn, fn chunk, conn ->
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
