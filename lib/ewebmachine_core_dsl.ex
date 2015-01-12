defmodule Ewebmachine.Core.DSL do
  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}) when is_list(params), do: {name,params,true}
  def sig_to_sigwhen({name,_,_}), do: {name,[],true}

  defmacro resource_call(fun) do quote do
    handler = var!(conn).private[:resource_handlers][unquote(fun)] || Ewebmachine.Default
    {reply, myconn, myuser_state} = apply(handler,unquote(fun),[var!(conn),var!(user_state)])
    {reply,var!(conn),var!(user_state)} = case reply do
      {:halt,code}-> #if halt, store current conn and fake reply
        myconn = Conn.put_private(myconn,:machine_halt_conn,myconn)
        {reply,_,_} = if !Module.defines?(Ewebmachine.Default,{unquote(fun),2}), do: {"",[],[]}, #body producing fun
                        else: apply(Ewebmachine.Default,unquote(fun),[myconn,myuser_state])
        {reply,myconn,myuser_state}
      _ ->{reply,myconn,myuser_state}
    end
    reply
  end end

  defmacro helper(sig, do: body) do
    {name,params,guard} = sig_to_sigwhen(sig)
    params = (quote do: [var!(conn),var!(user_state)]) ++ params
    quote do
      def unquote(name)(unquote_splicing(params)) when unquote(guard) do
        reply = unquote(body)
        {reply,var!(conn),var!(user_state)}
      end
    end
  end

  defmacro decision(sig, do: body) do
    {name,params,guard} = sig_to_sigwhen(sig)
    params = (quote do: [var!(conn),var!(user_state)]) ++ params
    quote do
      def unquote(name)(unquote_splicing(params)) when unquote(guard) do
        #if conn.private[:machine_debug], do: log_decision(unquote(name))
        IO.puts "decide #{unquote(name)}"
        reply = unquote(body)
        {reply,var!(conn),var!(user_state)}
      end
    end 
  end

  defmacro h(sig) do
    {name,params,_guard} = sig_to_sigwhen(sig)
    params = (quote do: [var!(conn),var!(user_state)]) ++ params
    quote do
      {reply,var!(conn),var!(user_state)} = unquote(name)(unquote_splicing(params))
      reply
    end
  end

  defmacro d(sig) do quote do
    case var!(conn) do
      %{private: %{machine_halt_conn: nil}}->var!(conn)
      %{private: %{machine_halt_conn: halt_conn}}-> var!(conn) = halt_conn
      %{halted: true}->var!(conn)
      _ -> h(unquote(sig)) ; var!(conn)
    end
  end end
end

defmodule Ewebmachine.Core.API do
  import Ewebmachine.Core.DSL
  alias Plug.Conn

  helper base_uri, do: 
    "#{conn.scheme}://#{conn.host}#{port_suffix(conn.scheme,conn.port)}"

  helper method, do: 
    conn.method

  helper resp_redirect, do: 
    conn.private[:resp_redirect]

  helper get_resp_header(name), do: 
    first_or_nil(Conn.get_resp_header(conn,name))

  helper path, do: 
    conn.path_info

  helper get_header_val(name), do: 
    first_or_nil(Conn.get_req_header(conn,name))

  helper set_response_code(code) do
    conn = conn # halt machine when set response code, on respond
      |> Conn.put_private(:machine_halt_conn,nil)
      |> Conn.put_status(code)
    :ok
  end

  helper set_resp_header(k,v), do: 
    (conn = Conn.put_resp_header(conn,k,v); :ok)

  helper set_resp_headers(kvs), do:
    (conn = Enum.reduce(kvs,conn,fn {k,v},acc->Conn.put_resp_header(acc,k,v) end); :ok)

  helper remove_resp_header(k), do:
    (conn = Conn.delete_resp_header(conn,k); :ok)

  helper set_disp_path(path), do:
    (conn = %{conn| script_name: String.split("#{path}","/")}; :ok)

  helper resp_body, do:
    (conn.private[:machine_body_stream] || conn.resp_body)

  helper set_resp_body(%Stream{}=body), do:
    (conn = Conn.put_private(conn,:machine_body_stream,body); :ok)

  helper set_resp_body(body), do:
    (conn = %{conn | resp_body: body}; :ok)

  helper has_resp_body, do:
    (!is_nil(conn.resp_body) or !is_nil(conn.private[:machine_body_stream]))

  helper get_metadata(key), do:
    conn.private[key]

  helper set_metadata(k,v), do:
    (conn = Conn.put_private(conn,k,v); :ok)

  helper compute_body_md5 do
    {:ok, body, conn} = Conn.read_body(conn, length: 1_000_000)
    :crypto.hash(:md5,body)
  end

  def port_suffix(:http,80), do: ""
  def port_suffix(:https,443), do: ""
  def port_suffix(_,port), do: ":#{port}"

  def first_or_nil([v|_]), do: v
  def first_or_nil(_), do: nil
end

