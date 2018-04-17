defmodule Ewebmachine.Plug.Run do
  @moduledoc ~S"""
    Plug passing your `conn` through the [HTTP decision tree](http_diagram.png)
    to fill its status and response.

    This plug does not send the HTTP result, instead the `conn`
    result of this plug must be sent with the plug
    `Ewebmachine.Plug.Send`. This is useful to customize the Ewebmachine result
    after the run, for instance to customize the error body (void by default).
    
    - Decisions are make according to handlers set in `conn.private[:resource_handlers]` 
      (`%{handler_name: handler_module}`) where `handler_name` is one
      of the handler function of `Ewebmachine.Handlers` and
      `handler_module` is the module implementing it.
    - Initial user state (second parameter of handler function) is
      taken from `conn.private[:machine_init]`

    `Ewebmachine.Builder.Handlers` `:add_handler` plug allows you to
    set these parameters in order to use this Plug.

    A successfull run will reset the resource handlers and initial state.
  """
  def init(_opts), do: []
  
  def call(conn, _opts) do
    init = conn.private[:machine_init]
    if (init) do
      conn = Ewebmachine.Core.v3(conn,init)
      log = conn.private[:machine_log]
      if (log) do
        Ewebmachine.Log.put(conn)
        GenEvent.notify(Ewebmachine.Events,log)
      end
      %{conn | private: Map.drop(conn.private,
	   [:machine_init,:resource_handlers,:machine_decisions,:machine_calls,:machine_log,:machine_init_at]
	 )
      }
    else
      conn
    end
  end
end
