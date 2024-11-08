# Demystify Ewebmachine DSL

Everyone has made a route with `Ewebmachine` (or at least copy and paste one),
but did you wonder once how does it work under the hood. Maybe you start
looking into it and were repelled by the heavy use of macro.

This document aims to go through some of `Ewebmachine` internals, to explain
how from a bunch of macros, we end up with a Plug pipeline.

---

Let's start with this small module:
```elixir
defmodule MyApi do
  use Ewebmachine.Builder.Resources

  resource "/api/path" do after
     allowed_methods do: ["GET"]

     defh(to_html, do: "<h1>HTML</h1>")
  end
end
```

It imports the macro `Ewebmachine.Builder.Resources.resource/[3-4]` into the
scope, with which we can make the `/api/path` route.

From this point on, the macro's magic starts :).

**How do handlers (`allowed_methods` and friends) work?**

The [`resource` macro creates a module from the given
body](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/builder.resources.ex#L157-L174).

```elixir
defmodule Ewebmachine.Builder.Resources do
  defmacro resource({:__aliases__, _, route_aliases},route,do: init_block, after: body) do
    resource_quote(Module.concat([__CALLER__.module|route_aliases]),route,init_block,body)
  end
  defmacro resource(route,do: init_block, after: body) do
    resource_quote(Module.concat(__CALLER__.module,"EWM"<>route_as_mod(route)),route,init_block,body)
  end

  def resource_quote(wm_module,route,init_block,body) do
    quote do
      @wm_routes {unquote(route), unquote(wm_module), unquote(Macro.escape(init_block))}

      defmodule unquote(wm_module) do
        use Ewebmachine.Builder.Handlers
        unquote(body)
        plug :add_handlers
      end
    end
  end

  # [...]
end
```

> #### Dynamic module {: .neutral}
>
> Dynamically named module aren't nested under their parent module.
> That's why the `resource` macro concats it with the caller's module.

In this module each handler will become a function. As is, each handler is a
macro.

The created module uses the `Ewebmachine.Builder.Handler` module. This module
defines the [list of
handlers](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/builder.handlers.ex#L91-L97)
(`allowed_methods`, etc...). For [each handler defined in this list, a
macro](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/builder.handlers.ex#L144-L152)
is created:

```elixir
defmodule Ewebmachine.Builder.Handlers do
  @resource_fun_names [
    :allowed_methods,
    # [...]
  ]

  for resource_fun_name<-@resource_fun_names do
    Module.eval_quoted(Ewebmachine.Builder.Handlers, quote do
      @doc "see `Ewebmachine.Handlers.#{unquote(resource_fun_name)}/2`"
      defmacro unquote(resource_fun_name)(do_block) do
        name = unquote(resource_fun_name)
        handler_quote(name,do_block[:do])
      end
    end)
  end

  # [...]
end
```

Inside this macro, the called [function
`handler_quote`](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/builder.handlers.ex#L102-L110)
takes care of adding the `{name, __MODULE__}` (where `name` is the handler's
name) to the module attribute `@resource_handlers` and defining a function.

```elixir
defmodule Ewebmachine.Builder.Handlers do
  defp handler_quote(name,body,guard,conn_match,state_match) do
    quote do
      @resource_handlers Map.put(@resource_handlers,unquote(name),__MODULE__)
      def unquote(name)(unquote(conn_match)=var!(conn),unquote(state_match)=var!(state)) when unquote(guard) do
        res = unquote(body)
        wrap_response(res,var!(conn),var!(state))
      end
    end
  end

  # [...]
end
```

> #### defh macro {: .info}
>
> [`defh`](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/builder.handlers.ex#L139-L142)
> macro which allows you to pass guard, works the same way underneath and calls
> `handler_quote` too.

Great we now know how handlers are transformed into functions.

---

**But how are handlers called?**

- Adding custom handlers to the connection

    The `:add_handlers` plug used by the created module takes care of adding
    handler names saved into the module's attribute to the connection's private
    field `:resource_handlers`.

    `use Ewebmachine.Builder.Handler` defines a `@before_compile
    Ewebmachine.Builder.Handler` attributes in which the [`add_handlers` plug
    function](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/builder.handlers.ex#L71-L78)
    is defined:

    ```elixir
    defmodule Ewebmachine.Builder.Handlers do
      defmacro __before_compile__(_env) do
        quote do
          defp add_handlers(conn, opts) do
            # [ ... ]
            Plug.Conn.put_private(conn, :resource_handlers,
              Enum.into(@resource_handlers, conn.private[:resource_handlers] || %{}))
          end
        end
      end
    end
    ```

- Internal usage of custom handlers

    Ewebmachine [decision
    tree](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/core.ex)
    calls handlers when going through the tree. For instance, the
    [`allowed_methods` is
    call](https://github.com/kbrw/ewebmachine/blob/b7659b9f5068cb188409d016d13635c6c4b74d6b/lib/ewebmachine/core.ex#L61)
    as such:

    ```elixir
    {methods, conn, state} = resource_call(conn, state, :allowed_methods)
    ```

    To use a custom handler, `Ewebmachine` simply looks up with the handler's
    name, into its private connection field `:resource_handlers` (added by the
    `:add_handlers` plug), which contains a map where keys are handler's names
    and values are the handler's module. If you did not define a handler it
    falls back to the default one inside the `Ewebmachine.Handlers` module.

    ```elixir
    defmodule Ewebmachine.Core.DSL do
      def resource_call(conn, state, fun) do
        handler = conn.private[:resource_handlers][fun] || Ewebmachine.Handlers
        {reply, conn, state} = term = apply(handler, fun, [conn, state])
        # [ ... ]
      end

      # [ ... ]
    end
    ```

---

Here is what the code would look like if we expand explained macros until now:

```elixir
defmodule MyApi do
  @before_compile Ewebmachine.Builder.Resources
  use Plug.Router
  import Plug.Router, only: []
  import Ewebmachine.Builder.Resources

  defp resource_match(conn, _opts) do
    conn |> match(nil) |> dispatch(nil)
  end

  @wm_routes [{"/api/path",  MyApi.EWMApiPath, []}]
end

defmodule MyApi.EWMApiPath do
  use Plug.Builder

  @resource_handlers %{
    allowed_methods: __MODULE__,
    to_html: __MODULE__
  }

  def allowed_methods(conn, state) do
    res = ["GET"]
    {res, conn, state}
  end

  def to_html(conn, state) do
    res = "<h1>HTML</h1>"
    {res, conn, state}
  end

  defp add_handlers(conn, _opts) do
    # [...]
    Plug.Conn.put_private(conn, :resource_handlers,
      Enum.into(@resource_handlers, conn.private[:resource_handlers] || %{}))
  end

  plug :add_handlers
end
```

**How does Ewebmachine call all of this?**

The missing piece of the puzzle is now, how does Ewebmachine call our plug
module `MyApi.EWMApiPath`.

From the macros' expansion above, we can see that it uses the `Plug.Router`.
Moreover, the line `@before_compile Ewebmachine.Builder.Resources` isn't
expanded, let's look into it. `Ewebmachine.Builder.Resources` called macro
`__before_compile__` does the following:

```elixir
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
```

which makes a match for the `Plug.Router`, giving us the following once expanded:

```elixir
defmodule MyApi do
  use Plug.Router
  import Plug.Router, only: []
  import Ewebmachine.Builder.Resources

  defp resource_match(conn, _opts) do
    conn |> match(nil) |> dispatch(nil)
  end

  @wm_routes [{"/api/path",  MyApi.EWMApiPath, :irrelevant_stuff}]

  Plug.Router.match "/api/path" do
    init = :irrelevant_stuff
    conn = put_private(conn, :machine_init, init)
    MyApiEWMApiPath.call(conn, [])
  end

  Plug.Router.match _ do conn
end
```

The only thing required now is to add a few plugs to make the whole thing works.
That what the macro `Ewebmachine.Builder.Resources.resources_plugs` usually
does, but let's use only the required bits

```elixir
defmodule MyApi do
    # [...]
    Plug.Router.match _ do conn

    plug :resource_match
    plug Ewebmachine.Plug.Run
    plug Ewebmachine.Plug.Send
end
```

The `:resource_match` function plug finds a matching route (`match(nil)`) and
calls it if matching (`dispatch(nil)`). Once done the connection `conn` is
return by the plug module (for instance here `MyApiEWMApiPath`) and now
contains our resource custom handlers.

Then the `Ewebmachine.Plug.Run` plug which contains `Ewebmachine`'s decision
tree is call, and its behaviour will change based on our custom handlers.

Finally, the `Ewebmachine.Plug.Send` plug is call and sends the response if the
connection wasn't halted before.
