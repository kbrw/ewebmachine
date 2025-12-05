defmodule Ewebmachine do
  @moduledoc """
  Contains utility functions to work with Ewebmachine private fields set inside `conn`
  """

  alias Plug.Conn

  @doc """
  Sets `:resp_redirect` to `true`
  """
  @spec do_redirect(Plug.Conn.t()) :: Plug.Conn.t()
  def do_redirect(conn) do
    Conn.put_private(conn, :resp_redirect, true)
  end

  @doc """
  Returns request body from request (requires fetching body first).

  See `fetch_req_body/2` to fetch the body.
  """
  @spec req_body(Plug.Conn.t()) :: binary
  def req_body(conn), do: conn.private[:req_body]

  @doc """
  Fetches the request body.

  Options:
  * `max_length` - maximum bytes to fetch. Defaults to: `1_000_000`.
  """
  @spec fetch_req_body(Plug.Conn.t(), Enumerable.t()) :: Plug.Conn.t()
  def fetch_req_body(conn, opts) do
    if conn.private[:req_body] do
      conn
    else
      {:ok, body, conn} = Conn.read_body(conn, length: opts[:max_length] || 1_000_000)
      Conn.put_private(conn, :req_body, body)
    end
  end
end
