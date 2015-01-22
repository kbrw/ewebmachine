Ewebmachine is a full rewrite with clean DSL and plug integration
based on Webmachine from basho. 

[![Build Status](https://travis-ci.org/awetzel/ewebmachine.svg?branch=master)](https://travis-ci.org/awetzel/ewebmachine)

See the [generated documentation](http://hexdocs.pm/ewebmachine) for more detailed explanations.

The principle is to go through the [HTTP decision tree](https://raw.githubusercontent.com/awetzel/ewebmachine/2.0-dev/doc/http_diagram.png)
and make decisions according to response of some callbacks called "handlers".

To do that, the library gives you 3 plugs and 2 plug pipeline builders :

- `Ewebmachine.Plug.Run` go through the HTTP decision tree and fill
  the `conn` response according to it
- `Ewebmachine.Plug.Send` is used to send a conn set with `Ewebmachine.Plug.Run`
- `Ewebmachine.Plug.Debug` gives you a debugging web UI to see the
  HTTP decision path taken by each request.
- `Ewebmachine.Builder.Handlers` gives you helpers macros and a
  `:add_handler` plug to add `handlers` as defined  in
  `Ewebmachine.Handlers` to your conn, and set the initial user state.
- `Ewebmachine.Builder.Resources` gives you a `resource` macro to
  define at the same time an `Ewebmachine.Builder.Handlers` and the
  matching spec to use it, and a plug `:resource_match` to do the
  match and execute the associated plug.

## Example usage

```elixir
defmodule MyJSONApi do 
  use Ewebmachine.Builder.Handlers
  plug :cors
  plug :add_handlers, init: %{}

  content_types_provided do: ["application/json": :to_json]
  defh to_json, do: Poison.encode!(state[:json_obj])

  defp cors(conn,_), do: 
    put_resp_header(conn,"Access-Control-Allow-Origin","*")
end

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
    plug MyJSONApi
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

## Debug UI 

Go to `/wm_debug` to see precedent requests and debug there HTTP
decision path. The debug UI can be updated automatically on the
requests.

![Debug UI example](https://raw.githubusercontent.com/awetzel/ewebmachine/2.0-dev/doc/debug_ui.png)
