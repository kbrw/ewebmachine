Ewebmachine is a full rewrite with clean DSL and plug integration
based on Webmachine from basho. This version is not backward compatible with
the previous one that was only a thin wrapper around webmachine, use the branch
1.0-legacy to use the old one.

[![Build Status](https://travis-ci.org/awetzel/ewebmachine.svg?branch=master)](https://travis-ci.org/awetzel/ewebmachine)

See the [generated documentation](http://hexdocs.pm/ewebmachine) for more detailed explanations.

The principle is to go through the [HTTP decision tree](https://raw.githubusercontent.com/awetzel/ewebmachine/master/doc/http_diagram.png)
and make decisions according to response of some callbacks called "handlers".

To do that, the library gives you 5 plugs and 2 plug pipeline builders :

- `Ewebmachine.Plug.Run` go through the HTTP decision tree and fill
  the `conn` response according to it
- `Ewebmachine.Plug.Send` is used to send a conn set with `Ewebmachine.Plug.Run`
- `Ewebmachine.Plug.Debug` gives you a debugging web UI to see the
  HTTP decision path taken by each request.
- `Ewebmachine.Plug.ErrorAsException` take a conn with a response set but not
  send, and throw an exception is the status code is an exception
- `Ewebmachine.Plug.ErrorAsForward` take a conn with a response set but not
  send, and forward it changing the request to `GET /error/pattern/:status`
- `Ewebmachine.Builder.Handlers` gives you helpers macros and a
  `:add_handler` plug to add `handlers` as defined  in
  `Ewebmachine.Handlers` to your conn, and set the initial user state.
- `Ewebmachine.Builder.Resources` gives you a `resource` macro to
  define at the same time an `Ewebmachine.Builder.Handlers` and the
  matching spec to use it, and a plug `:resource_match` to do the
  match and execute the associated plug. The macro `resources_plugs` helps you
  to define commong plug pipeling

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


defmodule ErrorRoutes do
  use Ewebmachine.Builder.Resources ; resources_plugs
  resource "/error/:status" do %{s: elem(Integer.parse(status),0)} after 
    content_types_provided do: ['text/html': :to_html, 'application/json': :to_json]
    defh to_html, do: "<h1> Error ! : '#{Ewebmachine.Core.Utils.http_label(state.s)}'</h1>"
    defh to_json, do: ~s/{"error": #{state.s}, "label": "#{Ewebmachine.Core.Utils.http_label(state.s)}"}/
    finish_request do: {:halt,state.s}
  end
end

defmodule FullApi do
  use Ewebmachine.Builder.Resources
  if Mix.env == :dev, do: plug Ewebmachine.Plug.Debug
  resources_plugs error_forwarding: "/error/:status", nomatch_404: true
  plug ErrorRoutes

  resource "/hello/:name" do %{name: name} after 
    content_types_provided do: ['application/xml': :to_xml]
    defh to_xml, do: "<Person><name>#{state.name}</name>"
  end

  resource "/hello/json/:name" do %{name: name} after 
    plug MyJSONApi #this is also a plug pipeline
    allowed_methods do: ["GET","DELETE"]
    resource_exists do: pass((user=DB.get(state.name)) !== nil, json_obj: user)
    delete_resource do: DB.delete(state.name)
  end

  resource "/static/*path" do %{path: Enum.join(path,"/")} after
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

![Debug UI example](https://raw.githubusercontent.com/awetzel/ewebmachine/master/doc/debug_ui.png)

## Use Cowboy to serve the plug

Create a simple supervision tree with only the Cowboy server adapter spec.

```elixir
defmodule MyApp do
  use Application
  def start(_type, _args), do:
    Supervisor.start_link([
        Plug.Adapters.Cowboy.child_spec(:http,FullApi,[], port: 4000)
      ], strategy: :one_for_one)
end
```

And add it as your application entry point in your `mix.exs`

```elixir
def application do
  [applications: [:logger,:ewebmachine,:cowboy], mod: {MyApp,[]}]
end
defp deps, do:
  [{:ewebmachine, "2.0.0"}, {:cowboy, "~> 1.0"}]
```
