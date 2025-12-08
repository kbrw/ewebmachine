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
  def call(%Plug.Conn{state: :set, private: %{machine_body_stream: stream}} = conn, _) do
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

    halt(conn)
  end

  def call(%Plug.Conn{state: :set} = conn, _), do: halt(send_resp(conn))
  def call(%Plug.Conn{} = conn, _), do: conn
end
