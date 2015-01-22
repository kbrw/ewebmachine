Code.require_file "test_helper.exs", __DIR__

defmodule CommonMacros do
  defmacro resources([do: body]) do 
    name = :"#{inspect make_ref}"
    quote do
      defmodule unquote(name) do
        use Ewebmachine.Builder.Resources
        plug :resource_match
        plug Ewebmachine.Plug.Run
        plug Ewebmachine.Plug.Send
        plug :error_404
        defp error_404(conn,_), do:
          (conn |> send_resp(404,"") |> halt)
        unquote(body)
      end
      unquote(name)
    end 
  end
end

defmodule EwebmachineTest do
  use ExUnit.Case
  use Plug.Test
  import CommonMacros

  test "Simple Handlers builder with only to_html default GET" do
    defmodule SimpleHtml do
      use Ewebmachine.Builder.Handlers
      plug :add_handlers, init: %{}
      plug Ewebmachine.Plug.Run
      plug Ewebmachine.Plug.Send

      defh to_html, do: "Hello World"
    end
    conn = SimpleHtml.call(conn(:get, "/"), [])
    assert conn.status == 200
    assert Enum.into(conn.resp_headers,%{})["content-type"] == "text/html"
    assert conn.resp_body == "Hello World"
    assert conn.state == :sent
  end

  test "Simple resource builder with XML and path match param" do
    app = resources do
      resource "/hello/:name" do %{name: name} after 
        content_types_provided do: ['application/xml': :to_xml]
        defh to_xml, do: "<Person><name>#{state.name}</name></Person>"
      end
    end
    assert app.call(conn(:get, "/"), []).status == 404
    conn = app.call(conn(:get, "/hello/arnaud"), [])
    assert conn.status == 200
    assert Enum.into(conn.resp_headers,%{})["content-type"] == "application/xml"
    assert conn.resp_body == "<Person><name>arnaud</name></Person>"
  end

  test "Implement not exists" do
    app = resources do
      resource "/hello/:name" do %{name: name} after 
        resource_exists do: state.name !== "idonotexist"
        defh to_html, do: state.name
      end
    end
    assert app.call(conn(:get, "/hello/arnaud"), []).status == 200
    assert app.call(conn(:get, "/hello/idonotexist"), []).status == 404
  end

  test "Service not available" do
    app = resources do
      resource "/notok" do %{} after 
        service_available do: false
      end
      resource "/ok" do %{} after 
        service_available do: true
      end
    end
    assert app.call(conn(:get, "/notok"), []).status == 503
    assert app.call(conn(:get, "/ok"), []).status == 200
  end

  test "Unknown method" do
    app = resources do
      resource "/notok" do %{} after known_methods(do: ["TOTO"]) end
      resource "/ok" do %{} after end
    end
    assert app.call(conn(:get, "/notok"), []).status == 501
    assert app.call(conn(:get, "/ok"), []).status == 200
  end

  test "Url too long" do
    app = resources do
      resource "/notok" do %{} after uri_too_long(do: true) end
      resource "/ok" do %{} after end
    end
    assert app.call(conn(:get, "/notok"), []).status == 414
    assert app.call(conn(:get, "/ok"), []).status == 200
  end

  test "Method allowed ?" do
    app = resources do
      resource "/notok" do %{} after allowed_methods(do: ["POST"]) end
      resource "/ok" do %{} after end
    end
    assert app.call(conn(:get, "/notok"), []).status == 405
    assert app.call(conn(:get, "/ok"), []).status == 200
  end

  test "Content MD5 check" do
    app = resources do
      resource "/" do %{} after 
        allowed_methods do: ["PUT"]
        content_types_accepted do: ["application/json": :from_json]
        defh from_json, do: true
      end
    end
    headers = [{"content-type","application/json"},{"content-md5","qqsjdf"}]
    assert app.call(conn(:put,"/","hello\n",[headers: headers]),[]).status == 400
    headers = [{"content-type","application/json"},{"content-md5","sZRqySSS0jR8YjW00mERhA=="}]
    assert app.call(conn(:put,"/","hello\n",[headers: headers]),[]).status == 204
  end

  test "Malformed ?" do
    app = resources do
      resource "/notok" do %{} after malformed_request(do: true) end
      resource "/ok" do %{} after end
    end
    assert app.call(conn(:get, "/notok"), []).status == 400
    assert app.call(conn(:get, "/ok"), []).status == 200
  end

  test "Is authorized ?" do
    app = resources do
      resource "/notok" do %{} after is_authorized(do: "myrealm") end
      resource "/ok" do %{} after end
    end
    assert app.call(conn(:get, "/ok"), []).status == 200
    conn = app.call(conn(:get, "/notok"), [])
    assert conn.status == 401
    assert get_resp_header(conn,"WWW-Authenticate") == ["myrealm"]
  end
end
