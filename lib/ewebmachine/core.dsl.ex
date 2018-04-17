defmodule Ewebmachine.Core.DSL do
  ## Macros and helpers defining the DSL for the Ewebmachine decision
  ## core : for legacy reasons, the module is called 'DSL' while they are
  ## are mostly helper functions.
  ##
  ## Changes:
  ##     Macros hiding `conn` and `user_state` variables have been removed
  ##     as they can produce unsafe use of these variables if used in
  ##     structures like if/cond/... which is deprecated in elixir 1.3

  ## Usage : 

  ##     decision mydecision(conn, user_state, args...) do # def mydecision(conn, user_state, arg...)
  ##       ...debug_decision
  ##       ...exec body
  ##     end
  @moduledoc false

  alias Plug.Conn

  defmacro __using__(_opts) do quote do
    import Ewebmachine.Core.DSL
    import Ewebmachine.Core.Utils
  end end

  def sig_to_sigwhen({:when, _, [{name,_,params}, guard]}), do: {name, params, guard}
  def sig_to_sigwhen({name, _, params}) when is_list(params), do: {name, params, true}
  def sig_to_sigwhen({name, _, _}), do: {name, [], true}

  defmacro decision(sig, do: body) do
    {name, [conn, state], guard} = sig_to_sigwhen(sig)
    quote do
      def unquote(name)(unquote(conn), unquote(state)) when unquote(guard) do
        var!(conn) = Ewebmachine.Log.debug_decision(unquote(conn), unquote(name))
        unquote(body)
      end
    end
  end

  def resource_call(conn, state, fun) do
    handler = conn.private[:resource_handlers][fun] || Ewebmachine.Handlers
    {reply, conn, state} = term = apply(handler, fun, [conn, state])
    conn = Ewebmachine.Log.debug_call(conn, handler, fun, [conn, state], term)
    case reply do
      {:halt, code} ->
	throw {:halt, set_response_code(conn, code)}
      _ ->
	{reply, conn, state}
    end
  end

  def method(conn), do: conn.method

  def resp_redirect(conn), do: conn.private[:resp_redirect]

  def get_resp_header(conn, name), do: first_or_nil(Conn.get_resp_header(conn, name))

  def path(conn), do: conn.request_path

  def get_header_val(conn, name), do: first_or_nil(Conn.get_req_header(conn, name))

  def set_response_code(conn, code) do
    conn = conn # halt machine when set response code, on respond
    |> Conn.put_status(code)
    |> Ewebmachine.Log.debug_enddecision
    conn = if !conn.resp_body, do: %{conn | resp_body: ""}, else: conn
    %{conn | state: :set}
  end

  def set_resp_header(conn, k, v), do: Conn.put_resp_header(conn, k, v)
  
  def set_resp_headers(conn, kvs) do
    Enum.reduce(kvs, conn,
      fn {k,v}, acc ->
	Conn.put_resp_header(acc, k, v)
      end)
  end

  def remove_resp_header(conn, k) do
    Conn.delete_resp_header(conn, k)
  end

  def set_disp_path(conn, path), do: %{conn | script_name: String.split("#{path}","/")}

  def resp_body(conn), do: conn.private[:machine_body_stream] || conn.resp_body

  def set_resp_body(conn, body) when is_binary(body) or is_list(body) do
    %{conn | resp_body: body}
  end
  def set_resp_body(conn, body) do          #if not an IO List, then it should be an enumerable
    Conn.put_private(conn, :machine_body_stream, body)
  end

  def has_resp_body(conn) do
    (!is_nil(conn.resp_body) or !is_nil(conn.private[:machine_body_stream]))
  end
  
  def get_metadata(conn, key), do: conn.private[key]

  def set_metadata(conn, k, v), do: Conn.put_private(conn, k, v)
  
  def compute_body_md5(conn) do
    conn = Ewebmachine.fetch_req_body(conn, [])
    :crypto.hash(:md5, Ewebmachine.req_body(conn))
  end

  def first_or_nil([v|_]), do: v
  def first_or_nil(_), do: nil
end
