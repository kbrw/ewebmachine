defmodule Ewebmachine.Plug do
  defmacro __before_compile__(_env) do
    quote do
      defp build_machine(conn, _opts) do
        Plug.Conn.put_private(conn,
          :resource_handlers,
          Dict.merge(conn.private[:resource_handlers],@resource_handlers))
      end
    end
  end
  defmacro __using__(_) do
    quote location: :keep do
      import Ewebmachine.Plug
      use Plug.Builder
      @before_compile Ewebmachine.Plug
      @resource_handlers %{}

      defp run_machine(conn, opts) do
        Ewebmachine.Core.v3(conn,opts[:state_init])
      end
    end
  end

  @resource_fun_names [
    :resource_exists,:service_available,:is_authorized,:forbidden,:allow_missing_post,:malformed_request,
    :base_uri,:uri_too_long,:known_content_type,:valid_content_headers,:valid_entity_length,:options,:allowed_methods,
    :delete_resource,:delete_completed,:post_is_create,:create_path,:process_post,:content_types_provided,
    :content_types_accepted,:charsets_provided,:encodings_provided,:variances,:is_conflict,:multiple_choices,
    :previously_existed,:moved_permanently,:moved_temporarily,:last_modified,:expires,:generate_etag,:finish_request
  ]
  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}), do: {name,params,true}

  for resource_fun_name<-@resource_fun_names do
    Module.eval_quoted(Ewebmachine.Plug, quote do
      defmacro unquote(resource_fun_name)(do: body) do
        resource_fun_name = unquote(resource_fun_name)
        quote do
          @resource_handlers Dict.put(@resource_handlers,unquote(resource_fun_name),__MODULE__)
          def unquote(resource_fun_name)(conn,state) do
            wrap_response(unquote(body),initialconn,initialstate)
          end
        end
      end
    end)
  end

  def do_redirect(conn), do:
    Conn.put_private(conn, :resp_redirect, true)
end

defmodule Ewebmachine.DebugPlug do
  #add /ewebmachine route to debug route
  # add conn.priv[:machine_debug] = true
end

defmodule Ewebmachine.RoutingPlug do
  defmacro __using__(_) do
    quote location: :keep do
      import Ewebmachine.RoutingPlug
      use Plug.Router
    end
  end
  
  defmacro resource(route,do: body) do
    route_as_mod = route
      |> Enum.map(&String.capitalize("#{&1}"))
      |> Enum.join(".")
    quote do
      module = Module.concat(__MODULE__,unquote(route_as_mod))
      defmodule module do
        use Ewebmachine.Plug
        unquote(body)
      end
      match unquote(route) do
        module.call(conn,module.init(route,[]))
      end
    end
  end
end
