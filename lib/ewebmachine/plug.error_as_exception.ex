defmodule Ewebmachine.Plug.ErrorAsException do
  @moduledoc """
  Raises an `#{__MODULE__}` exception on errornous HTTP status code.

  If the `conn`'s state is `:set` and its `status` is higher than `399`, this
  plug raises a `#{__MODULE__}` exception.

  The `conn`'s `resp_body` is used if not empty as the exception's message,
  otherwise the http code's label is used.
  """
  @behaviour Plug

  defexception [:plug_status, :message]

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(%{status: code, state: :set} = conn, _) when code > 399, do: raise(__MODULE__, conn)
  def call(conn, _), do: conn

  def exception(%{status: code, resp_body: msg}) when byte_size(msg) > 0,
    do: %__MODULE__{plug_status: code, message: msg}

  def exception(%{status: code}),
    do: %__MODULE__{plug_status: code, message: Ewebmachine.Core.Utils.http_label(code)}
end
