defmodule Ewebmachine.Builder.Resources do
  @moduledoc ~S"""
  Provides macros to make endpoints for resources.

  > #### `use Ewebmachine.Builder.Resources` {: .info}
  >
  > When you `use Ewebmachine.Builder.Resources`, it will `use Plug.Router`,
  > `import Ewebmachine.Builder.Resources`, declare a private function plug
  > `resource_match` which passes the connection through the `:match` and
  > `:dispatch` plugs from `Plug`.

  `use Ewebmachine.Builder.Resources` also accept the following option:
  * `:default_plugs` - which when set to `true`, also add the plugs
    `:resource_match`, `Ewebmachine.Plug.Run` and `Ewebmachine.Plug.Send`

  ## Example

  Multiple resources can be declared inside a single module and will be matched
  accordingly.
  ```elixir
  defmodule FullApi do
    use Ewebmachine.Builder.Resources

    if Mix.env == :dev, do: plug Ewebmachine.Plug.Debug
    # Pre plug, for instance you can put plugs defining common handlers
    plug :resource_match
    plug Ewebmachine.Plug.Run
    # Customize Ewebmachine result, for instance make an error page handler plug
    plug Ewebmachine.Plug.Send
    # Plug after that will be executed only if no ewebmachine resources has matched

    resource "/hello/:name" do %{name: name} after
      plug SomeAdditionnalPlug
      content_types_provided do: ['application/xml': :to_xml]
      defh to_xml, do: "<Person><name>#{state.name}</name>"
    end

    resource "/hello/foo/:bar" do %{bar: bar} after
      content_types_provided do: ['text/plain': :to_text]
      defh to_text, do: "Foo #{state.bar}"
    end
  end
  ```

  > #### Increasing compilation time {: .warning}
  >
  > Using many `resource/2` macros inside the same module can significantly
  > raise the compilation time since it makes a module underneath and if one
  > depends on another module at compilte time it will need to recompile the
  > whole file, which the compiler does in a linear maner.
  >
  > Splitting a module which uses many `resource/2` will decrease the
  > compilation time.
  """
  defmacro __using__(opts) do
    quote location: :keep do
      @before_compile Ewebmachine.Builder.Resources
      use Plug.Router
      import Plug.Router, only: []
      import Ewebmachine.Builder.Resources

      Module.register_attribute(__MODULE__, :wm_routes, accumulate: true)

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
    wm_routes = Module.get_attribute(__CALLER__.module, :wm_routes)

    route_matches =
      for {route, wm_module, init_block} <- Enum.reverse(wm_routes) do
        quote do
          Plug.Router.match unquote(route) do
            init = unquote(init_block)
            var!(conn) = put_private(var!(conn), :machine_init, init)
            unquote(wm_module).call(var!(conn), [])
          end
        end
      end

    final_match =
      if !match?({"/*" <> _, _, _}, hd(wm_routes)) do
        quote(
          do:
            Plug.Router.match _ do
              var!(conn)
            end
        )
      end

    quote do
      unquote_splicing(route_matches)
      unquote(final_match)
    end
  end

  defp remove_first(":" <> e), do: e
  defp remove_first("*" <> e), do: e
  defp remove_first(e), do: e

  defp route_as_mod(route) do
    route
    |> String.split("/")
    |> Enum.map(&(&1 |> remove_first |> String.capitalize()))
    |> Enum.join()
  end

  @doc """
  Same as `resource/2` but you can set the module's name.

  ```elixir
  resource ShortenedRouteName, "/my/route/that/would/generate/a/long/module/name/:id" do
    # ...
  end
  ```
  """
  defmacro resource({:__aliases__, _, route_aliases}, route, do: init_block, after: body) do
    resource_quote(Module.concat([__CALLER__.module | route_aliases]), route, init_block, body)
  end

  @doc ~S"""
  Creates a plug module which is executed on path match.

  The created module will use the `Ewebmachine.Builder.Handlers` module and add
  the plug `:add_handlers` at the end of it.

  See `Plug.Router` for the path specification.

  The macro takes a `do` and an `after`. Both are executed on match. The `do`
  block is executed to make the initial state. In its scope path bindings are
  available. The handlers declared in the `after` block are executed by the
  `Ewebmachine.Plug.Run` plug.

  ## Example

  ```elixir
  resource "/my/route/:commaid" do
    id = String.split(commaid, ",")
    %{foo: id}
  after
    resource_exists do: state.id == ["hello"]
  end
  ```
  """
  defmacro resource(route, do: init_block, after: body) do
    resource_quote(
      Module.concat(__CALLER__.module, "EWM" <> route_as_mod(route)),
      route,
      init_block,
      body
    )
  end

  def resource_quote(wm_module, route, init_block, body) do
    quote do
      @wm_routes {unquote(route), unquote(wm_module), unquote(Macro.escape(init_block))}

      defmodule unquote(wm_module) do
        use Ewebmachine.Builder.Handlers
        unquote(body)
        plug :add_handlers
      end
    end
  end

  @doc """
  Adds common plugs to match resources with Ewebmachine.

  The macro's intent is to cover the most common use case to match resources. To
  do so it adds the following plug by default:
  * `:resource_match` which passes the connection through the `:match` and
    `:dispatch` plugs of `Plug`.
  * `Ewebmachine.Plug.Run`
  * `Ewebmachine.Plug.Send`

  Additional processing can be provided for connection which did not match any
  route or which returns an erroneous http code via the following options:
  * `:nomatch_404` - if sets to `true` adds a function plug `wm_notset_404`
    which is case of an `:unset` state respond with a `404` http code. Defaults
    to `false`.
  * `:error_as_exception` - if sets to `true` adds the
    `Ewebmachine.Plug.ErrorAsException` plug. Defaults to `false`.
  * `:error_forwarding` - when a pattern is given and `:error_as_exception` is
    not set, it adds the `Ewebmachine.Plug.ErrorAsForward` plug with as
    `:forward_pattern` the given pattern. Defaults to `nil`.
  """
  alias Ewebmachine.Plug.ErrorAsException
  alias Ewebmachine.Plug.ErrorAsForward

  defmacro resources_plugs(opts \\ []) do
    {errorplug, errorplug_params} =
      cond do
        opts[:error_as_exception] ->
          {ErrorAsException, []}

        forward_pattern = opts[:error_forwarding] ->
          {ErrorAsForward, [forward_pattern: forward_pattern]}

        true ->
          {false, []}
      end

    quote do
      plug :resource_match
      plug Ewebmachine.Plug.Run
      if unquote(opts[:nomatch_404]), do: plug(:wm_notset_404)
      if unquote(errorplug), do: plug(unquote(errorplug), unquote(errorplug_params))
      plug Ewebmachine.Plug.Send

      defp wm_notset_404(%{state: :unset} = conn, _), do: resp(conn, 404, "")
      defp wm_notset_404(conn, _), do: conn
    end
  end
end
