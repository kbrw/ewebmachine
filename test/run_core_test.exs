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
  
  test "default plugs" do
    defmodule SimpleResources do
      use Ewebmachine.Builder.Resources, default_plugs: true
      resource "/ok" do [] after defh(to_html, do: "toto") end
    end
    conn = SimpleResources.call(conn(:get, "/ok"), [])
    assert conn.status == 200
    assert Enum.into(conn.resp_headers,%{})["content-type"] == "text/html"
    assert conn.resp_body == "toto"
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
    assert get_resp_header(conn,"www-authenticate") == ["myrealm"]
  end
  
  test "Encoding base64" do
    app = resources do
      resource "/" do %{} after 
        encodings_provided do: [base64: &Base.encode64/1, identity: &(&1)]
        defh to_html, do: "hello"
      end
    end
    conn = app.call(conn(:get,"/",[],headers: [{"accept-encoding","base64"}]), [])
    assert get_resp_header(conn,"content-encoding") == ["base64"]
    assert conn.resp_body == "aGVsbG8="
    conn = app.call(conn(:get,"/",[],headers: [{"accept-encoding","toto"}]), [])
    assert conn.status == 200
    assert get_resp_header(conn,"content-encoding") == []
    assert conn.resp_body == "hello"
  end
  
  test "POST create path" do
    app = resources do
      resource "/orders" do %{} after 
        allowed_methods do: ["POST"]
        post_is_create do: true
        create_path do: "/titus"
        content_types_accepted do: ["text/plain": :from_text]
        defh from_text, do:
          {true,put_private(conn,:body_post,read_body(conn)),state}
      end
      resource "/orders2" do %{} after 
        allowed_methods do: ["POST"]
        post_is_create do: true
        create_path do: "titus"
        content_types_accepted do: ["text/plain": :from_text]
        defh from_text, do: true
      end
    end
    conn = app.call(conn(:post,"/orders","titus",headers: [{"content-type","text/plain"}]), [])
    assert get_resp_header(conn,"location") == ["http://www.example.com/titus"]
    assert conn.status == 201
    assert {:ok,"titus",_} = conn.private.body_post
    conn = app.call(conn(:post,"/orders2","titus",headers: [{"content-type","text/plain"}]), [])
    assert get_resp_header(conn,"location") == ["http://www.example.com/orders2/titus"]
  end
  
  test "POST process post" do
    app = resources do
      resource "/orders" do %{} after 
        allowed_methods do: ["POST"]
        process_post do:
          {true,put_private(conn,:body_post,"yes"),state}
      end
    end
    conn = app.call(conn(:post,"/orders","titus",headers: [{"content-type","text/plain"}]), [])
    assert conn.status == 204
    assert "yes" = conn.private[:body_post]
  end
  
  test "Cache if modified" do
    app = resources do
      resource "/notcached" do %{} after 
        last_modified do: {{2013,1,1},{0,0,0}}
      end
      resource "/cached" do %{} after 
        last_modified do: {{2012,12,31},{0,0,0}}
      end
    end
    conn = app.call(conn(:get,"/cached",nil,headers: [{"if-modified-since","Sat, 31 Dec 2012 19:43:31 GMT"}]), [])
    assert conn.status == 304
    conn = app.call(conn(:get,"/notcached",nil,headers: [{"if-modified-since","Sat, 31 Dec 2012 19:43:31 GMT"}]), [])
    assert conn.status == 200
  end
  
  test "Cache etag" do
    app = resources do
      resource "/notcached" do %{} after 
        generate_etag do: "titi"
      end
      resource "/cached" do %{} after 
        generate_etag do: "toto"
      end
    end
    conn = app.call(conn(:get,"/cached",nil,headers: [{"if-none-match","toto"}]), [])
    assert conn.status == 304
    conn = app.call(conn(:get,"/notcached",nil,headers: [{"if-none-match","toto"}]), [])
    assert conn.status == 200
  end
  
  test "halt test" do
    app = resources do
      resource "/error" do %{} after 
        content_types_provided do: {:halt,407}
        defh to_html, do: "toto"
      end
    end
    conn = app.call(conn(:get,"/error"), [])
    assert conn.status == 407
    assert conn.resp_body == ""
  end

  test "fuzzy acceptance" do
    app = resources do
      resource "/" do %{} after 
        allowed_methods do: ["PUT"]
        content_types_accepted do: %{"application/*"=> :from_app, {"text/*",%{"pretty"=>"true"}}=> :from_pretty}
        defh from_app, do: {:halt,601}
        defh from_pretty, do: {:halt,602}
      end
    end
    headers = [{"content-type","application/json; charset=utf8"}]
    assert app.call(conn(:put,"/","h",[headers: headers]),[]).status == 601
    headers = [{"content-type","text/html; pretty=true; charset=utf8"}]
    assert app.call(conn(:put,"/","h",[headers: headers]),[]).status == 602
  end
end
