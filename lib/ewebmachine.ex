defmodule Ewebmachine do
  @moduledoc (File.read!("README.md") |>
    String.replace(~r/^See the \[generated.*$/m, "") |>
    String.replace(~r/^.*Build Status.*$/m, "") |>
    String.replace("https://raw.githubusercontent.com/kbrw/ewebmachine/master/doc/", ""))

  alias Plug.Conn

  @doc """
  Set :resp_redirect to `true`
  """
  @spec do_redirect(Plug.Conn.t) :: Plug.Conn.t
  def do_redirect(conn) do
    Conn.put_private(conn, :resp_redirect, true)
  end

  @doc """
  Returns request body from request (requires fetching body first)
  """
  @spec req_body(Plug.Conn.t) :: binary
  def req_body(conn), do: conn.private[:req_body]

  @doc """
  Fetch request body

  Options: 
  * max_length: maximum bytes to fetch (default: 1_000_000)
  """
  @spec fetch_req_body(Plug.Conn.t, Enumerable.t) :: Plug.Conn.t
  def fetch_req_body(conn, opts) do
    if conn.private[:req_body] do conn else
      {:ok, body, conn} = Conn.read_body(conn, length: (opts[:max_length] || 1_000_000))
      Conn.put_private(conn, :req_body, body)
    end
  end
end
