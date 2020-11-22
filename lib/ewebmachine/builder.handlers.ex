defmodule Ewebmachine.Builder.Handlers do
  @moduledoc """
  `use` this  module will `use Plug.Builder` (so a plug pipeline
  described with the `plug module_or_function_plug` macro), but gives
  you an `:add_handler` local function plug which adds to the conn
  the locally defined ewebmachine handlers (see `Ewebmachine.Handlers`).

  So : 

  - Construct your automate decision handler through multiple `:add_handler` plugs
  - Pipe the plug `Ewebmachine.Plug.Run` to run the HTTP automate which
    will call these handlers to take decisions. 
  - Pipe the plug `Ewebmachine.Plug.Send` to send and halt any conn previsously passed
    through an automate run.
  
  To define handlers, use the following helpers :

  - the handler specific macros (like `Ewebmachine.Builder.Handlers.resource_exists/1`)
  - the macro `defh/2` to define any helpers, usefull for body
    producing handlers or to have multiple function clauses 
  - in handler implementation `conn` and `state` binding are available
  - the response of the handler implementation is wrapped, so that
    returning `:my_response` is the same as returning `{:my_response,conn,state}`

  Below a full example :

  ```
  defmodule MyJSONApi do 
    use Ewebmachine.Builder.Handlers
    plug :cors
    plug :add_handlers, init: %{}

    content_types_provided do: ["application/json": :to_json]
    defh to_json, do: Poison.encode!(state[:json_obj])

    defp cors(conn,_), do: 
      put_resp_header(conn,"Access-Control-Allow-Origin","*")
  end

  defmodule GetUser do 
    use Ewebmachine.Builder.Handlers
    plug MyJSONApi
    plug :add_handlers
    plug Ewebmachine.Plug.Run
    plug Ewebmachine.Plug.Send
    resource_exists do:
      pass( !is_nil(user=DB.User.get(conn.params["q"])), json_obj: user)
  end
  defmodule GetOrder do 
    use Ewebmachine.Builder.Handlers
    plug MyJSONApi
    plug :add_handlers
    plug Ewebmachine.Plug.Run
    plug Ewebmachine.Plug.Send
    resource_exists do:
      pass(!is_nil(order=DB.Order.get(conn.params["q"])), json_obj: order)
  end

  defmodule API do
    use Plug.Router
    plug :match 
    plug :dispatch

    get "/get/user", do: GetUser.call(conn,[])
    get "/get/order", do: GetOrder.call(conn,[])
    end
  ```
  """
  defmacro __before_compile__(_env) do
    quote do
      defp add_handlers(conn, opts) do
        conn = case Access.fetch(opts, :init) do
          {:ok, init} when not (init in [false, nil]) -> put_private(conn, :machine_init, init)
          _ -> conn
        end
        Plug.Conn.put_private(conn, :resource_handlers,
          Enum.into(@resource_handlers, conn.private[:resource_handlers] || %{}))
      end
    end
  end
  defmacro __using__(_opts) do
    quote location: :keep do
      use Plug.Builder
      import Ewebmachine.Builder.Handlers
      @before_compile Ewebmachine.Builder.Handlers
      @resource_handlers %{}
      ping do: :pong
    end
  end

  @resource_fun_names [
    :resource_exists,:service_available,:is_authorized,:forbidden,:allow_missing_post,:malformed_request,:known_methods,
    :base_uri,:uri_too_long,:known_content_type,:valid_content_headers,:valid_entity_length,:options,:allowed_methods,
    :delete_resource,:delete_completed,:post_is_create,:create_path,:process_post,:content_types_provided,
    :content_types_accepted,:charsets_provided,:encodings_provided,:variances,:is_conflict,:multiple_choices,
    :previously_existed,:moved_permanently,:moved_temporarily,:last_modified,:expires,:generate_etag, :ping, :finish_request
  ]
  defp sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  defp sig_to_sigwhen({name,_,params}) when is_list(params), do: {name,params,true}
  defp sig_to_sigwhen({name,_,_}), do: {name,[quote(do: _),quote(do: _)],true}

  defp handler_quote(name,body,guard,conn_match,state_match) do
    quote do
      @resource_handlers Map.put(@resource_handlers,unquote(name),__MODULE__)
      def unquote(name)(unquote(conn_match)=var!(conn),unquote(state_match)=var!(state)) when unquote(guard) do
        res = unquote(body)
        wrap_response(res,var!(conn),var!(state))
      end
    end 
  end
  defp handler_quote(name,body) do
    handler_quote(name,body,true,quote(do: _),quote(do: _))
  end

  @doc """
  define a resource handler function as described at
  `Ewebmachine.Handlers`.
  
  Since there is a specific macro in this module for each handler,
  this macro is useful : 

  - to define body producing and body processing handlers (the one
    referenced in the response of `Ewebmachine.Handlers.content_types_provided/2` or 
    `Ewebmachine.Handlers.content_types_accepted/2`)
  - to explicitly take the `conn` and the `state` parameter, which
    allows you to add guards and pattern matching for instance to
    define multiple clauses for the handler

  ```
  defh to_html, do: "hello you"
  defh from_json, do: pass(:ok, json: Poison.decode!(read_body conn))
  ```

  ```
  defh resources_exists(conn,%{obj: obj}) when obj !== nil, do: true
  defh resources_exists(conn,_), do: false
  ```
  """
  defmacro defh(signature, do_block) do
    {name, [conn_match,state_match], guard} = sig_to_sigwhen(signature)
    handler_quote(name, do_block[:do], guard, conn_match, state_match)
  end

  for resource_fun_name<-@resource_fun_names do
    Module.eval_quoted(Ewebmachine.Builder.Handlers, quote do
      @doc "see `Ewebmachine.Handlers.#{unquote(resource_fun_name)}/2`"
      defmacro unquote(resource_fun_name)(do_block) do
        name = unquote(resource_fun_name)
        handler_quote(name,do_block[:do])
      end
    end)
  end

  @doc false
  def wrap_response({_,%Plug.Conn{},_}=tuple,_,_), do: tuple
  def wrap_response(r,conn,state), do: {r,conn,state}

  @doc """
  Shortcut macro for :
  {response,var!(conn),Enum.into(update_state,var!(state))}

  use it if your handler wants to add some value to a collectable
  state (a map for instance), but using default "conn" current
  binding.

  for instance a resources_exists implementation "caching" the result
  in the state could be :

      pass (user=DB.get(state.id)) != nil, current_user: user
      # same as returning :
      {true,conn,%{id: "arnaud", current_user: %User{id: "arnaud"}}}
  """
  defmacro pass(response,update_state) do
    quote do 
      {unquote(response),var!(conn),Enum.into(unquote(update_state),var!(state))}
    end
  end
end
