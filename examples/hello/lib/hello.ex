defmodule Hello do
  defmodule App do
    use Application
    
    def start(_type, _args) do
      Supervisor.start_link([
	Plug.Adapters.Cowboy2.child_spec(scheme: :http, plug: Hello.Api, options: [port: 4000]),
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
    defh to_json(conn, state), do: {Poison.encode!(state[:json_obj]), conn, state}
    
    defp cors(conn, _) do
      put_resp_header(conn, "Access-Control-Allow-Origin", "*")
    end
  end
  
  defmodule Api do
    use Ewebmachine.Builder.Resources
    plug Ewebmachine.Plug.Debug

    resources_plugs nomatch_404: true
    
    resource "/hello/:name" do %{name: name} after 
      content_types_provided do: ['application/xml': :to_xml]
      defh to_xml(conn, state), do: {"<Person><name>#{state.name}</name></Person>", conn, state}
    end
    
    resource "/hello/json/:name" do %{name: name} after 
      plug ApiCommon # this is also a plug pipeline
      
      allowed_methods do: ["GET", "PUT", "DELETE"]
      content_types_accepted do: ['application/json': :from_json]

      defh resource_exists(conn, state) do
	case Hello.Db.get(state.name) do
	  nil -> {false, conn, state}
	  user -> {true, conn, Map.put(state, :json_obj, user)}
	end
      end

      defh delete_resource(conn, state), do: {Hello.Db.delete(state.name), conn, state}
      
      defh from_json(conn, state) do
	value = conn |> Ewebmachine.fetch_req_body([]) |> Ewebmachine.req_body |> Poison.decode!
	_ = Hello.Db.put(state.name, value)
	{true, conn, state}
      end
    end

    resource "/new" do %{} after 
      plug ApiCommon #this is also a plug pipeline
      
      allowed_methods do: ["POST"]
      content_types_accepted do: ['application/json': :from_json]
      post_is_create do: true

      defh create_path(conn, state), do: {state.newpath, conn, state}
      
      defh from_json(conn, state) do
	value = conn |> Ewebmachine.fetch_req_body([]) |> Ewebmachine.req_body() |> Poison.decode!()
	newpath = "#{:io_lib.format("~9..0b", [:rand.uniform(999999999)])}"
	_ = Hello.Db.put(value["id"], value)
	{true, conn, Map.put(state, :newpath, newpath)}
      end
    end    
    
    resource "/new_with_redirect" do %{} after 
      plug ApiCommon #this is also a plug pipeline
      
      allowed_methods do: ["POST"]
      content_types_accepted do: ['application/json': :from_json]
      post_is_create do: true
      
      defh create_path(conn, state), do: {state.newpath, conn, state}
      
      defh from_json(conn, state) do
	value = conn |> Ewebmachine.fetch_req_body([]) |> Ewebmachine.req_body() |> Poison.decode!()
	newpath = "#{:io_lib.format("~9..0b", [:rand.uniform(999999999)])}"
	_ = Hello.Db.put(value["id"], value)
	conn = Plug.Conn.put_private(conn, :resp_redirect, true)
	{true, conn, Map.put(state, :newpath, newpath)}
      end
    end    

    resource "/static/*path" do %{path: Enum.join(path, "/")} after
      resource_exists do: File.regular?(path(state.path))
      content_types_provided do: [ {state.path |> Plug.MIME.path() |> default_plain, :to_content} ]
      
      defh to_content(conn, state) do
	body = File.stream!( path(state.path), [], 300_000_000)
	{body, conn, state}
      end
      
      defp path(relative), do: "#{:code.priv_dir(:ewebmachine)}/static/#{relative}"

      defp default_plain("application/octet-stream"), do: "text/plain"
      defp default_plain(type), do: type
    end
  end
end
