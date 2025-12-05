defmodule Ewebmachine.Plug.Run do
  @moduledoc ~S"""
  A plug which runs the HTTP decision tree with the set handlers defined by a
  matching `Ewebmachine.Builder.Resources.resource/2`.

  The initial user state is taken from the `do` block of the
  `Ewebmachine.Builder.Resources.resource/2` macro.

  ![](./assets/http_diagram.png)

  This plug does not send the response to let additional plugs customize the
  result.

  To send the response, use the `Ewebmachine.Plug.Send` after this one.
  """

  @behaviour Plug

  @impl Plug
  def init(_opts), do: []

  @impl Plug
  def call(conn, _opts) do
    init = conn.private[:machine_init]

    if init do
      conn = Ewebmachine.Core.v3(conn, init)
      log = conn.private[:machine_log]

      if log do
        Ewebmachine.Log.put(conn)
        Ewebmachine.Events.dispatch(log)
      end

      private =
        Map.drop(conn.private, [
          :machine_init,
          :resource_handlers,
          :machine_decisions,
          :machine_calls,
          :machine_log,
          :machine_init_at
        ])

      %{conn | private: private}
    else
      conn
    end
  end
end
