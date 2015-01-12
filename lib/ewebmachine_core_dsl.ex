defmodule Ewebmachine.Core.DSL do
  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}) when is_list(params), do: {name,params,true}
  def sig_to_sigwhen({name,_,_}), do: {name,[],true}
  def sig_to_sigwhen(name), do: {name,[],true}

  defmacro resource_call(fun) do quote do
    handler = conn.private[:resource_handlers][fun] || Ewebmachine.Default
    {reply, conn, user_state} = apply(handler,fun,[conn,user_state])
    {conn,reply} = case reply do
      {:halt,code}-> #if halt, store current conn and fake reply
        conn = Conn.put_private(conn,:halt_conn,conn)
        reply = elem(apply(Ewebmachine.Default,fun,[conn,user_state]),0)
        {conn,reply}
      _ ->{conn,reply}
    end
    reply
  end end

  defmacro helper(sig, do: body) do
    {name,params,guard} = sig_to_sigwhen(sig)
    params = (quote do: [conn,user_state]) ++ params
    quote do
      def unquote(name)(unquote_splicing(params)) when unquote(guard) do
        reply = unquote(body)
        {reply,conn,user_state}
      end
    end
  end

  defmacro decision(sig, do: body) do
    {name,params,guard} = sig_to_sigwhen(sig)
    params = (quote do: [conn,user_state]) ++ params
    quote do
      def unquote(name)(unquote_splicing(params)) when unquote(guard) do
        if conn.priv[:machine_debug], do: log_decision(unquote(name))
        reply = unquote(body)
        {reply,conn,user_state}
      end
    end 
  end

  defmacro h(sig) do
    {name,params,guard} = sig_to_sigwhen(sig)
    params = (quote do: [conn,user_state]) ++ params
    quote do
      {reply,conn,user_state} = unquote(decision)(unquote_splicing(params))
      reply
    end
  end

  defmacro d(sig) do quote do
    case conn do
      %{private: %{machine_halt: halt_conn}}->halt_conn
      %{halted: true}->conn
      _ -> h(unquote(sig)) ; conn
    end
  end end

  helper base_uri, do: 
    "#{conn.scheme}://#{conn.host}#{port_suffix(conn.scheme,conn.port)}"

  helper method, do: 
    conn.method

  helper resp_redirect, do: 
    conn.private[:resp_redirect]

  helper get_resp_header(name), do: 
    conn.resp_headers[name]

  helper path, do: 
    conn.path_info

  helper get_header_val(name), do: 
    conn.req_headers[name]

  helper set_response_code(code), do: 
    (conn = Conn.put_status(conn,code); :ok)

  helper set_resp_header(k,v), do: 
    (conn = Conn.put_resp_header(conn,k,v); :ok)

  helper set_resp_headers(kvs), do:
    (conn = Enum.reduce(kvs,conn,fn {k,v},acc->Conn.put_resp_header(acc,k,v)); :ok)

  helper remove_resp_header(k), do:
    (conn = Conn.delete_resp_header(conn,k); :ok)

  helper set_disp_path(path), do:
    (conn = %{conn| script_name: String.split("#{unquote(path)}","/")}; :ok)

  helper resp_body, do:
    conn.resp_body

  helper set_resp_body(body), do:
    (conn = %{conn | resp_body: unquote(body)}; :ok)

  helper has_resp_body, do:
    !is_nil(conn.resp_body)

  helper get_metadata(key), do:
    conn.priv[key]

  helper set_metadata(k,v), do:
    (conn = Conn.put_private(conn,k,v); :ok)

  helper compute_body_md5 do
    {:ok, body, conn} = Conn.read_body(conn, length: 1_000_000)
    :crypto.hash(:md5,body)
  end
end

