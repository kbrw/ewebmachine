defmodule Ewebmachine.Builder.Handlers do
  @moduledoc """
  Provides macros to define your handlers, usually inside a
  `Ewebmachine.Builder.Resources.resource/2`.

  This module defines:
  * a specific macro for each handler defined in `Ewebmachine.Builder.Handlers`
    see the [Handlers](#handlers) section.
  * the `defh/2` macro to define handler
  * the `pass/2` macro to ease handler response

  > #### `use Ewebmachine.Builder.Handlers` {: .info}
  >
  > When you `use Ewebmachine.Builder.Handlers`, it will `use Plug.Builder`
  > and define a function plug `:add_handlers`. This plug will register every
  > defined handlers inside the calling module into `conn`. Those registered
  > handler will then be used by the  `Ewebmachine.Plug.Run` plug.

  > #### Declare and use common handlers {: .tip}
  >
  > If you want to add common handlers that should be used for several
  > `Ewebmachine.Builder.Resources.resource/2`s, you can do so by making a plug
  > module with your common handlers and use the `:add_handlers` plug.
  > The module implementing an handler is saved inside the `conn` and is then
  > used by the `Ewebmachine.Plug.Run` plug to call the appropriate one.
  > For instance if you define the following plug module:
  > ```elixir
  > defmodule CommonHandlers
  >   use Ewebmachine.Builder.Handlers
  >   plug :add_handlers
  >
  >   content_types_provided ["application/json": :to_json]
  >   defh to_json do
  >     JSON.encode!(state.response)
  >   end
  > end
  > ```
  > and add it to your application's plug pipeline then the module implementing
  > the handler `content_types_provided` will be `CommonHandlers` instead of
  > the default `Ewebmachine.Handlers`.
  """
  defmacro __before_compile__(_env) do
    quote do
      defp add_handlers(conn, opts) do
        conn =
          case Access.fetch(opts, :init) do
            {:ok, init} when init not in [false, nil] -> put_private(conn, :machine_init, init)
            _ -> conn
          end

        Plug.Conn.put_private(
          conn,
          :resource_handlers,
          Enum.into(@resource_handlers, conn.private[:resource_handlers] || %{})
        )
      end
    end
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      use Plug.Builder
      import Ewebmachine.Builder.Handlers
      @before_compile Ewebmachine.Builder.Handlers
      @resource_handlers %{}

      if Mix.env() == :test do
        defh ping(_, _), do: :pong
      end
    end
  end

  @resource_fun_names [
    :resource_exists,
    :service_available,
    :is_authorized,
    :forbidden,
    :allow_missing_post,
    :malformed_request,
    :known_methods,
    :base_uri,
    :uri_too_long,
    :known_content_type,
    :valid_content_headers,
    :valid_entity_length,
    :options,
    :allowed_methods,
    :delete_resource,
    :delete_completed,
    :post_is_create,
    :create_path,
    :process_post,
    :content_types_provided,
    :content_types_accepted,
    :charsets_provided,
    :encodings_provided,
    :variances,
    :is_conflict,
    :multiple_choices,
    :previously_existed,
    :moved_permanently,
    :moved_temporarily,
    :last_modified,
    :expires,
    :generate_etag,
    :finish_request
  ]
  defp sig_to_sigwhen({:when, _, [{name, _, params}, guard]}), do: {name, params, guard}
  defp sig_to_sigwhen({name, _, params}) when is_list(params), do: {name, params, true}
  defp sig_to_sigwhen({name, _, _}), do: {name, [quote(do: _), quote(do: _)], true}

  defp handler_quote(name, body, guard, conn_match, state_match) do
    conn_match =
      case var_in_patterns?(conn_match, :conn) do
        true -> conn_match
        false -> quote(do: unquote(conn_match) = var!(conn))
      end

    state_match =
      case var_in_patterns?(state_match, :state) do
        true -> state_match
        false -> quote(do: unquote(state_match) = var!(state))
      end

    quote do
      @resource_handlers Map.put(@resource_handlers, unquote(name), __MODULE__)
      def unquote(name)(unquote(conn_match), unquote(state_match)) when unquote(guard) do
        res = unquote(body)
        wrap_response(res, var!(conn), var!(state))
      end
    end
  end

  defp handler_quote(name, body) do
    handler_quote(name, body, true, quote(do: _), quote(do: _))
  end

  defp var_in_patterns?(ast, name) do
    case ast do
      {:=, meta, [pat1, pat2]} when is_list(meta) ->
        var_in_patterns?(pat1, name) or var_in_patterns?(pat2, name)

      {^name, meta, context} when is_list(meta) and is_atom(context) ->
        true

      _ ->
        false
    end
  end

  @doc false
  def wrap_response({_, %Plug.Conn{}, _} = tuple, _, _), do: tuple
  def wrap_response(r, conn, state), do: {r, conn, state}

  @doc """
  Defines a resource handler function as described by the `Ewebmachine.Handlers`
  module.

  Handlers defined with this macro can either return the complete tuple
  `{response, conn, state}` or only the `response`. The returned value is then
  wrapped if needed.

  Use this macro when you want to:
  * define a handler which processes and produces body (the one given to
  `Ewebmachine.Handlers.content_types_provided/2` or
  `Ewebmachine.Handlers.content_types_accepted/2`)

    ```elixir
    content_types_accepted do: ["text/heml": :to_html]
    content_types_provided do: ["application/json": :from_json]

    defh to_html, do: "hello you"
    defh from_json, do: pass(:ok, json: Poison.decode!(read_body conn))
    ```

  * use pattern matching via the function's head or a guard
    ```elixir
    defh resources_exists(conn, %{obj: obj}) when obj != nil, do: true
    defh resources_exists(conn, _), do: false
    ```

    > #### Predefined handler {: .info}
    >
    > If you don't need pattern matching you can directly use the predefined
    > handlers from this module. For instance instead of `defh
    > resource_exists(conn, state) do ... end` use `resource_exist do ... end`.
  """
  defmacro defh(signature, do_block) do
    {name, [conn_match, state_match], guard} = sig_to_sigwhen(signature)
    handler_quote(name, do_block[:do], guard, conn_match, state_match)
  end

  for resource_fun_name <- @resource_fun_names do
    Code.eval_quoted(
      quote do
        @doc group: :handler
        @doc """
        Same as `defh #{unquote(resource_fun_name)}(conn, state) do ... end`

        See `Ewebmachine.Handlers.#{unquote(resource_fun_name)}/2` for more
        information on the handler's purpose.
        """
        defmacro unquote(resource_fun_name)(do_block) do
          name = unquote(resource_fun_name)
          handler_quote(name, do_block[:do])
        end
      end,
      [],
      __ENV__
    )
  end

  @doc """
  Passes the handler response as well as updating the state.

  It expands to
  ```elixir
  {response, var!(conn), Enum.into(update_state, var!(state))}
  ```

  Use it when you need to add some value to an `t:Enumerable.t/0` state.

  For instance for a `Ewebmachine.Handlers.resource_exists/2` handler which
  caches the result:
  ```elixir
  resource_exists do
    user = DB.get(state.id)

    pass is_map(user), current_user: user
  end
  ```
  instead of defining the whole response tuple of the handler
  ```elixir
  resource_exists do
    user = DB.get(state.id)

    {is_map(user), conn, Map.put(state, :current_user, user)}
  end
  ```
  """
  defmacro pass(response, update_state) do
    quote do
      {unquote(response), var!(conn), Enum.into(unquote(update_state), var!(state))}
    end
  end
end
