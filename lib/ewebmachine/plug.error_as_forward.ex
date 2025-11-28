defmodule Ewebmachine.Plug.ErrorAsForward do
  @moduledoc """
  This plug take an argument `forward_pattern` (default to `"/error/:status"`),
  and, when the current response status is an error, simply forward to a `GET`
  to the path defined by the pattern and this status.
  """
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts[:forward_pattern] || "/error/:status"

  @impl Plug
  def call(%Plug.Conn{status: code, state: :set} = conn, pattern) when code > 399 do
    # `path_info` info is the request path split as segments.
    # Generate a path according to the status code.
    path_info =
      String.replace(pattern, ":status", to_string(code))
      # Transform it into segments.
      |> String.split("/", trim: true)

    %{conn | path_info: path_info, method: "GET", state: :unset}
  end

  def call(conn, _), do: conn
end
