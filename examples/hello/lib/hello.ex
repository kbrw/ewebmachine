defmodule Hello do
  defmodule App do
    use Application
    
    def start(_type, _args) do
      Supervisor.start_link([
	Plug.Adapters.Cowboy.child_spec(:http, Hello.Api,[], port: 4000),
	Supervisor.Spec.worker(Hello.Db, [])
      ], strategy: :one_for_one)
    end
  end

  defmodule Db do
    def start_link, do: Agent.start_link(&Map.new/0, name: __MODULE__)
    def get(id), do: Agent.get(__MODULE__, &(Map.get(&1, id, nil)))
    def put(id, val), do: Agent.update(__MODULE__, &(Map.put(&1, id, val)))
    def delete(id), do: Agent.update(__MODULE__, &(Map.delete(&1, id)))
  end

  defmodule ApiCommon do 
    use Ewebmachine.Builder.Handlers
    plug :cors
    plug :add_handlers
    
    content_types_provided do: ["application/json": :to_json]
    defh to_json, do: Poison.encode!(state[:json_obj])
    
    defp cors(conn, _) do
      put_resp_header(conn, "Access-Control-Allow-Origin", "*")
    end
  end
  
  defmodule ErrorRoutes do
    use Ewebmachine.Builder.Resources
    resources_plugs
    
    resource "/error/:status" do %{s: elem(Integer.parse(status), 0)} after 
      content_types_provided do: ['text/html': :to_html, 'application/json': :to_json]
      defh to_html, do: "<h1> Error ! : '#{Ewebmachine.Core.Utils.http_label(state.s)}'</h1>"
      defh to_json, do: ~s/{"error": #{state.s}, "label": "#{Ewebmachine.Core.Utils.http_label(state.s)}"}/
      finish_request do: {:halt, state.s}
    end
  end

  defmodule Api do
    use Ewebmachine.Builder.Resources
    plug Ewebmachine.Plug.Debug
    resources_plugs error_forwarding: "/error/:status", nomatch_404: true
    plug Hello.ErrorRoutes
    
    resource "/hello/:name" do %{name: name} after 
      content_types_provided do: ['application/xml': :to_xml]
      defh to_xml, do: "<Person><name>#{state.name}</name>"
    end
    
    resource "/hello/json/:name" do %{name: name} after 
      plug ApiCommon #this is also a plug pipeline
      allowed_methods do: ["GET", "PUT", "DELETE"]
      content_types_accepted do: ['application/json': :from_json]
      resource_exists do
	user = Hello.Db.get(state.name)	
	pass(user !== nil, json_obj: user)
      end
      delete_resource do: Hello.Db.delete(state.name)
      defh from_json do
	value = conn |> Ewebmachine.fetch_req_body([]) |> Ewebmachine.req_body |> Poison.decode!
	_ = Hello.Db.put(state.name, value)
	{true, conn, state}
      end
    end
    
    resource "/static/*path" do %{path: Enum.join(path, "/")} after
      resource_exists do: File.regular?(path(state.path))
      content_types_provided do: [ {state.path |> Plug.MIME.path |> default_plain, :to_content} ]
      defh to_content, do: File.stream!( path(state.path), [], 300_000_000)
      defp path(relative), do: "#{:code.priv_dir(:ewebmachine)}/static/#{relative}"
      defp default_plain("application/octet-stream"), do: "text/plain"
      defp default_plain(type), do: type
    end
  end
end
