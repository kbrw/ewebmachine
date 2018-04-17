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

  ## Common Plugs macro helper

  As the most common use case is to match resources, run the webmachine
  automate, then set a 404 if no resource match, then handle error code, then
  send the response, the `resources_plugs/1` macro allows you to do that.

  For example, if you want to convert all HTTP errors as Exceptions, and
  consider that all path must be handled and so any non matching path should
  return a 404 :

      resources_plugs error_as_exception: true, nomatch_404: true

  is equivalent to
  
      plug :resource_match
      plug Ewebmachine.Plug.Run
      plug :wm_notset_404
      plug Ewebmachine.Plug.ErrorAsException
      plug Ewebmachine.Plug.Send

      defp wm_notset_404(%{state: :unset}=conn,_), do: resp(conn,404,"")
      defp wm_notset_404(conn,_), do: conn

  Another example, following plugs must handle non matching paths and errors
  should be converted into `GET /error/:status` that must be handled by
  following plugs :

      resources_plugs error_forwarding: "/error/:status"

  is equivalent to

      plug :resource_match
      plug Ewebmachine.Plug.Run
      plug Ewebmachine.Plug.ErrorAsForward, forward_pattern: "/error/:status"
      plug Ewebmachine.Plug.Send
  """
  defmacro __using__(opts) do
    quote location: :keep do
      @before_compile Ewebmachine.Builder.Resources
      use Plug.Router
      import Plug.Router, only: []
      import Ewebmachine.Builder.Resources
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
    id = string.split(commaid,",")
    %{foo: id}
  after
    plug someadditionnalplug
    resource_exists do: state.id == ["hello"]
  end

  resource ShortenedRouteName, "/my/route/that/would/generate/a/long/module/name/:commaid" do
    id = String.split(commaid,",")
    %{foo: id}
  after
    plug SomeAdditionnalPlug
    resource_exists do: state.id == ["hello"]
  end
  ```
    
  """
  defmacro resource({:__aliases__, _, route_aliases},route,do: init_block, after: body) do
    resource_quote(Module.concat([__CALLER__.module|route_aliases]),route,init_block,body,__CALLER__.module)
  end
  defmacro resource(route,do: init_block, after: body) do
    resource_quote(Module.concat(__CALLER__.module,"EWM"<>route_as_mod(route)),route,init_block,body,__CALLER__.module)
  end

  def resource_quote(wm_module,route,init_block,body,caller_module) do
    old_wm_routes = Module.get_attribute(caller_module, :wm_routes) || []
    Module.put_attribute caller_module, :wm_routes, [{route,wm_module,init_block}|old_wm_routes]
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
