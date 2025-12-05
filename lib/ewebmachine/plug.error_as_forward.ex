defmodule Ewebmachine.Plug.ErrorAsForward do
  @moduledoc """
  Sets the `path_info` on errornous HTTP status code to forward the request to
  another plug.

  If the `conn`'s `status` is higher than `399` , the `conn`'s `path_info` is
  set to the `forward_pattern`, the `state` sets to `:unset`, and the `method`
  to `GET`.

  Usefull is you want to have a generic route error handler downstream in the
  pipeline.

  ## Options

  * `forward_pattern` - sets the redirection path. The `:status` will be
    replaced by the `conn`'s `status`. Defaults to `/error/:status`.
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
