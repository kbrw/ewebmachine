defmodule Ewebmachine.Plug do
  defmacro __before_compile__(_env) do
    quote do
      defp machine_build(conn, opts) do
        if opts && (init=opts[:init]), do:
          conn = put_private(conn,:machine_init,init)
        Plug.Conn.put_private(conn,
          :resource_handlers,
          Dict.merge(conn.private[:resource_handlers] || %{},@resource_handlers))
      end
    end
  end
  defmacro __using__(opts) do
    quote location: :keep do
      import Ewebmachine.Plug
      use Plug.Builder
      @before_compile Ewebmachine.Plug
      @resource_handlers %{}
      ping do: :pong

      defp machine_run(conn,init_state) do
        Ewebmachine.Core.v3(conn,conn.private[:machine_init])
      end

      defp machine_send(conn, _opts) do
        if conn.private[:machine_init], 
          do: (conn |> Ewebmachine.send |> halt),
          else: conn
      end
    end
  end

  @resource_fun_names [
    :resource_exists,:service_available,:is_authorized,:forbidden,:allow_missing_post,:malformed_request,
    :base_uri,:uri_too_long,:known_content_type,:valid_content_headers,:valid_entity_length,:options,:allowed_methods,
    :delete_resource,:delete_completed,:post_is_create,:create_path,:process_post,:content_types_provided,
    :content_types_accepted,:charsets_provided,:encodings_provided,:variances,:is_conflict,:multiple_choices,
    :previously_existed,:moved_permanently,:moved_temporarily,:last_modified,:expires,:generate_etag,:finish_request, :ping
  ]
  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}), do: {name,params,true}

  def handler_quote(name,body) do
    quote do
      @resource_handlers Dict.put(@resource_handlers,unquote(name),__MODULE__)
      def unquote(name)(var!(conn),var!(state)) do
        wrap_response(unquote(body),var!(conn),var!(state))
      end
    end 
  end

  defmacro handler(name,do: body), do:
    handler_quote(name,body)

  for resource_fun_name<-@resource_fun_names do
    Module.eval_quoted(Ewebmachine.Plug, quote do
      defmacro unquote(resource_fun_name)(do: body) do
        name = unquote(resource_fun_name)
        handler_quote(name,body)
      end
    end)
  end

  def wrap_response({:dictstate,r,newstate},rq,state), do: {r,rq,Keyword.merge(state,newstate)}
  def wrap_response({_,_,_}=tuple,_,_), do: tuple
  def wrap_response(r,rq,state), do: {r,rq,state}
  def pass(r,update_state), do: {:dictstate,r,update_state}
end

defmodule Ewebmachine.RoutingPlug do
  defmacro __using__(_) do
    quote location: :keep do
      use Plug.Router
      import Ewebmachine.RoutingPlug
      @wm_routes []

      defp machine_send(conn, _opts) do
        if conn.private[:machine_init], 
          do: (conn |> Ewebmachine.send |> halt),
          else: conn
      end
    end
  end

  defmacro match_resources do
    wm_routes =  Module.get_attribute __CALLER__.module, :wm_routes
    quotes = for {route,wm_module,init_block}<-wm_routes do
      quote do
        match unquote(route) do
          init = unquote(init_block)
          var!(conn) = put_private(var!(conn),:machine_init,init)
          unquote(wm_module).call(var!(conn),[])
        end
      end
    end
    quote do unquote_splicing(quotes) end
  end

  defp remove_first(":"<>e), do: e
  defp remove_first(e), do: e
  defp var_or_value({var,_,_}), do: var
  defp var_or_value(e), do: e

  defp route_as_mod("/"), do: Root
  defp route_as_mod([]), do: Root
  defp route_as_mod(route) when is_binary(route), do:
    (route |> String.split("/") |> Enum.map(& &1 |> remove_first |> String.capitalize) |> Enum.join("."))
  defp route_as_mod(route) when is_list(route), do:
    (route |> Enum.map(& &1 |> var_or_value |> to_string |> String.capitalize) |> Enum.join("."))
  
  defmacro resource(route,do: init_block, after: body) do
    wm_module = Module.concat(__CALLER__.module,route_as_mod(route))
    old_wm_routes = Module.get_attribute(__CALLER__.module, :wm_routes) || []
    Module.put_attribute __CALLER__.module, :wm_routes, [{route,wm_module,init_block}|old_wm_routes]
    quote do
      defmodule unquote(wm_module) do
        use Ewebmachine.Plug
        plug :machine_build
        plug :machine_run
        unquote(body)
        plug :machine_send
      end
    end
  end
end
