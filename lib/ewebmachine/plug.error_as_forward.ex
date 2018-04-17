defmodule Ewebmachine.Plug.ErrorAsForward do
  @moduledoc """
  This plug take an argument `forward_pattern` (default to `"/error/:status"`),
  and, when the current response status is an error, simply forward to a `GET`
  to the path defined by the pattern and this status.
  """
  def init(opts), do: (opts[:forward_pattern] || "/error/:status")
  def call(%{status: code, state: :set}=conn,pattern) when code > 399 do
    path = pattern |> String.slice(1..-1) |> String.replace(":status",to_string(code)) |> String.split("/")
    %{conn| path_info: path, method: "GET", state: :unset}
  end
  def call(conn,_), do: conn
end
