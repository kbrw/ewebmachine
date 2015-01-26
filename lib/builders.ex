
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
        if opts && (init=opts[:init]), do:
          conn = put_private(conn,:machine_init,init)
        Plug.Conn.put_private(conn,:resource_handlers,
          Enum.into(@resource_handlers,conn.private[:resource_handlers] || %{}))
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
      @resource_handlers Dict.put(@resource_handlers,unquote(name),__MODULE__)
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
  defmacro defh(signature,do_block) do
    {name,[conn_match,state_match],guard} = sig_to_sigwhen(signature)
    handler_quote(name,do_block[:do],guard,conn_match,state_match)
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

defmodule Ewebmachine.Builder.Resources do
  @moduledoc ~S"""
  `use` this  module will `use Plug.Builder` (so a plug pipeline
  described with the `plug module_or_function_plug` macro), but gives
  you a `:resource_match` local function plug which matches routes declared
  with the `resource/2` macro and execute the plug defined by its body.

  See `Ewebmachine.Builder.Handlers` documentation to see how to
  contruct these modules (in the `after` block)

  Below a full example :

  ```

  defmodule FullApi do
    use Ewebmachine.Builder.Resources
    if Mix.env == :dev, do: plug Ewebmachine.Plug.Debug
    # pre plug, for instance you can put plugs defining common handlers
    plug :resource_match
    plug Ewebmachine.Plug.Run
    # customize ewebmachine result, for instance make an error page handler plug
    plug Ewebmachine.Plug.Send
    # plug after that will be executed only if no ewebmachine resources has matched

    resource "/hello/:name" do %{name: name} after 
      plug SomeAdditionnalPlug
      content_types_provided do: ['application/xml': :to_xml]
      defh to_xml, do: "<Person><name>#{state.name}</name>"
    end

    resource "/*path" do %{path: Enum.join(path,"/")} after
      resource_exists do:
        File.regular?(path state.path)
      content_types_provided do:
        [{state.path|>Plug.MIME.path|>default_plain,:to_content}]
      defh to_content, do:
        File.stream!(path(state.path),[],300_000_000)
      defp path(relative), do: "#{:code.priv_dir :ewebmachine_example}/web/#{relative}"
      defp default_plain("application/octet-stream"), do: "text/plain"
      defp default_plain(type), do: type
    end
  end
  ```

  ## Default plugs

  As you often want to simply match resources, run the webmachine
  automate and send the response without any customization, you can
  use the option `default_plugs` :

      use Ewebmachine.Builder.Resources, default_plugs: true

  is equivalent to
  
      use Ewebmachine.Builder
      plug :resource_match
      plug Ewebmachine.Plug.Run
      plug Ewebmachine.Plug.Send
  """
  defmacro __using__(opts) do
    quote location: :keep do
      use Plug.Router
      import Plug.Router, only: []
      import Ewebmachine.Builder.Resources
      @before_compile Ewebmachine.Builder.Resources
      if unquote(opts[:default_plugs]) do
        plug :resource_match
        plug Ewebmachine.Plug.Run
        plug Ewebmachine.Plug.Send
      end

      defp resource_match(conn, _opts) do
        conn |> match(nil) |> dispatch(nil)
      end
    end
  end

  defmacro __before_compile__(_env) do
    wm_routes =  Module.get_attribute __CALLER__.module, :wm_routes
    route_matches = for {route,wm_module,init_block}<-Enum.reverse(wm_routes) do
      quote do
        Plug.Router.match unquote(route) do
          init = unquote(init_block)
          var!(conn) = put_private(var!(conn),:machine_init,init)
          unquote(wm_module).call(var!(conn),[])
        end
      end
    end
    final_match = if !match?({"/*"<>_,_,_},hd(wm_routes)), 
      do: quote(do: Plug.Router.match _ do var!(conn) end)
    quote do
      unquote_splicing(route_matches)
      unquote(final_match)
    end
  end

  defp remove_first(":"<>e), do: e
  defp remove_first("*"<>e), do: e
  defp remove_first(e), do: e

  defp route_as_mod(route), do:
    (route |> String.split("/") |> Enum.map(& &1 |> remove_first |> String.capitalize) |> Enum.join)
  
  @doc ~S"""
  Create a webmachine handler plug and use it on `:resource_match` when path matches 

  - the route will be the matching spec (see Plug.Router.match, string spec only)
  - do_block will be called on match (so matching bindings will be
    available) and should return the initial state
  - after_block will be the webmachine handler plug module body
    (wrapped with `use Ewebmachine.Builder.Handlers` and `plug
    :add_handlers` to clean the declaration.

  ```
  resource "/my/route/:commaid" do
    id = String.split(commaid,",")
    %{foo: id}
  after
    plug SomeAdditionnalPlug
    resource_exists do: state.id == ["hello"]
  end
  ```
    
  """
  defmacro resource(route,do: init_block, after: body) do
    wm_module = Module.concat(__CALLER__.module,"EWM"<>route_as_mod(route))
    old_wm_routes = Module.get_attribute(__CALLER__.module, :wm_routes) || []
    Module.put_attribute __CALLER__.module, :wm_routes, [{route,wm_module,init_block}|old_wm_routes]
    quote do
      defmodule unquote(wm_module) do
        use Ewebmachine.Builder.Handlers
        unquote(body)
        plug :add_handlers
      end
    end
  end

  alias Ewebmachine.Plug.ErrorAsException
  alias Ewebmachine.Plug.ErrorAsForward
  defmacro resources_plugs(opts \\ []) do
    {errorplug,errorplug_params} = cond do
      opts[:error_as_exception]->{ErrorAsException,[]}
      (forward_pattern=opts[:error_forwarding])->{ErrorAsForward,[forward_pattern: forward_pattern]}
      true -> {false,[]}
    end
    quote do
      plug :resource_match
      plug Ewebmachine.Plug.Run
      if unquote(opts[:nomatch_404]), do: plug :wm_notset_404
      if unquote(errorplug), do: plug(unquote(errorplug),unquote(errorplug_params))
      plug Ewebmachine.Plug.Send

      defp wm_notset_404(%{state: :unset}=conn,_), do: resp(conn,404,"")
      defp wm_notset_404(conn,_), do: conn
    end
  end
end
