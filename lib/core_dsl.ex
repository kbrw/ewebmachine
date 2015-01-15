defmodule Ewebmachine.Core.DSL do

  defmacro __using__(_opts) do quote do
    import Ewebmachine.Core.DSL
    import Ewebmachine.Core.API
    import Ewebmachine.Core.Utils
    @compile :nowarn_unused_vars
  end end

  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}) when is_list(params), do: {name,params,true}
  def sig_to_sigwhen({name,_,_}), do: {name,[],true}

  defmacro resource_call(fun) do quote do
    handler = var!(conn).private[:resource_handlers][unquote(fun)] || Ewebmachine
    args = [var!(conn),var!(user_state)]
    {reply, myconn, myuser_state} = term = apply(handler,unquote(fun),args)
    if handler !== Ewebmachine do 
      myconn = Ewebmachine.Log.debug_call(myconn,handler,unquote(fun),args,term)
      IO.puts "handle call #{unquote(fun)}"
    end
    {reply,var!(conn),var!(user_state)} = case reply do
      {:halt,code}-> #if halt, store current conn and fake reply
        myconn = Conn.put_private(myconn,:machine_halt_conn,myconn)
        {reply,_,_} = if !Module.defines?(Ewebmachine,{unquote(fun),2}), do: {"",[],[]}, #body producing fun
                        else: apply(Ewebmachine,unquote(fun),[myconn,myuser_state])
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
        var!(conn) = Ewebmachine.Log.debug_decision(var!(conn),unquote(name))
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
    if !conn.resp_body, do: conn = %{conn|resp_body: ""}
    conn = %{conn|state: :set}
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

defmodule Ewebmachine.Core.Utils do
  def normalize_mtype({type,params}) do
    case String.split(type) do
      [type,subtype]->{type,subtype,params}
      _->{"application","octet-stream",%{}}
    end
  end
  def normalize_mtype({_,_,%{}}=mtype), do: mtype
  def normalize_mtype(type) do
    case Plug.Conn.Utils.media_type(to_string(type)) do
      {:ok,type,subtype,params}->{type,subtype,params}
      :error-> {"application","octet-stream",%{}}
    end
  end

  def format_mtype({type,subtype,params}) do
    params = params |> Enum.map(fn {k,v}->";#{k}=#{v}" end) |> Enum.join
    "#{type}/#{subtype} #{params}"
  end

  def choose_media_type(ct_provided,accept_header) do
    accepts = accept_header |> Plug.Conn.Utils.list |> Enum.map(&Plug.Conn.Utils.media_type/1)
    accepts = for {:ok,type,subtype,params}<-accepts do 
      q = case Float.parse(params["q"] || "1") do {q,_}->q ; _ -> 1 end
      {q,type,subtype,Dict.delete(params,"q")}
    end |> Enum.sort |> Enum.reverse
    Enum.find_value(accepts,fn {_,atype,asubtype,aparams}->
      Enum.find(ct_provided, fn {type,subtype,params}->
        (atype=="*" or atype==type) and (asubtype=="*" or asubtype==subtype) and aparams==params
      end)
    end)
  end

  def quoted_string(value), do: 
    Plug.Conn.Utils.token(value)
  def split_quoted_strings(str), do:
    (str |> Plug.Conn.Utils.list |> Enum.map(&Plug.Conn.Utils.token/1))

  def rfc1123_date({{yyyy, mm, dd}, {hour, min, sec}}) do
    day_number = :calendar.day_of_the_week({yyyy, mm, dd})
    :io_lib.format('~s, ~2.2.0w ~3.s ~4.4.0w ~2.2.0w:~2.2.0w:~2.2.0w GMT',
                     [:httpd_util.day(day_number), dd, :httpd_util.month(mm),
                      yyyy, hour, min, sec]) |> IO.iodata_to_binary
  end

  def convert_request_date(date) do
    try do
      :httpd_util.convert_request_date(date)
    catch
      _,_ -> :bad_date
    end
  end

  def choose_encoding(encs,acc_enc_hdr), do:
    choose(encs,acc_enc_hdr,"identity")
  def choose_charset(charsets,acc_char_hdr), do:
    choose(charsets,acc_char_hdr,"utf8")

  defp choose(choices,header,default) do
    ## sorted set of {prio,value}
    prios = prioritized_values(header)

    # determine if default is ok or any is ok if no match
    default_prio = Enum.find_value(prios, fn {prio,v}-> v==default && prio end)
    start_prio = Enum.find_value(prios, fn {prio,v}-> v=="*" && prio end)
    default_ok = case default_prio do
      nil -> start_prio !== 0.0
      0.0 -> false
      _ -> true
    end
    any_ok = not start_prio in [nil,0.0]

    # remove choices where prio == 0.0
    {zero_prios,prios} = Enum.partition(prios,fn {prio,_}-> prio == 0.0 end)
    choices_to_remove = Enum.map(zero_prios,&elem(&1,1))
    choices = Enum.filter(choices,&!(String.downcase(&1) in choices_to_remove))

    # find first match, if not found and any_ok, then first choice, else if default_ok, take it
    if choices !== [] do
      Enum.find_value(prios, fn {_,val}->
        Enum.find(choices, &(val == String.downcase(&1)))
      end) ||
        (any_ok && hd(choices) || 
          (default_ok && Enum.find(choices,&(&1 == default)) || 
            nil))
    end
  end

  defp prioritized_values(header) do
    header 
    |> Plug.Conn.Utils.list
    |> Enum.map(fn e->
        {q,v} = case String.split(e,~r"\s;\s", parts: 2) do
          [value,params] ->
             case Float.parse(Plug.Conn.Utils.params(params)["q"] || "1.0") do
               {q,_}->{q,value}
               :error -> {1.0,value}
             end
          [value] -> {1.0,value}
        end
        {q,String.downcase(v)}
      end)
    |> Enum.sort
    |> Enum.reverse
  end
end
