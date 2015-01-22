defmodule Ewebmachine do
  alias Plug.Conn
  @moduledoc (File.read!("README.md")
              |>String.replace(~r/^See the \[generated.*$/m,"")
              |>String.replace(~r/^.*Build Status.*$/m,"")
              |>String.replace("https://raw.githubusercontent.com/awetzel/ewebmachine/2.0-dev/doc/",""))

  def do_redirect(conn), do:
    Conn.put_private(conn, :resp_redirect, true)
end
