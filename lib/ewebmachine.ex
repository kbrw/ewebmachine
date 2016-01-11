defmodule Ewebmachine do
  alias Plug.Conn
  @moduledoc (File.read!("README.md") 
               |>String.replace(~r/^See the \[generated.*$/m,"")
               |>String.replace(~r/^.*Build Status.*$/m,"")
               |>String.replace("https://raw.githubusercontent.com/awetzel/ewebmachine/master/doc/",""))

  def do_redirect(conn), do:
    Conn.put_private(conn, :resp_redirect, true)

  def req_body(conn), do: conn.private[:req_body]
  def fetch_req_body(conn, opts) do
    if conn.private[:req_body] do conn else
      {:ok, body, conn} = Conn.read_body(conn, length: (opts[:max_length] || 1_000_000))
      Conn.put_private(conn, :req_body, body)
    end
  end
end
