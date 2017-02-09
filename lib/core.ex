defmodule Ewebmachine.Core do
  use Ewebmachine.Core.DSL

  ## Basho webmachine Core rewrited in a systematic way to make the
  ## conversion as reliable as possible. The Ewebmachine.Core.DSL
  ## allows this conversion to be clean imitating the DSL of Basho.
  @moduledoc false

  @spec v3(Plug.Conn.t, any) :: Plug.Conn.t
  def v3(conn, user_state) do
    try do
      {_, conn, _} = v3b13(Ewebmachine.Log.debug_init(conn), user_state)
      conn
    catch
      :throw, {:halt,conn} -> conn
    end
  end

  ## "Service Available"
  decision v3b13(conn, state) do
    case resource_call(conn, state, :ping) do
      {:pong, conn, state} ->
	v3b13b(conn, state);
      {_, conn, state} ->
	respond(conn, state, 503)
    end
  end
  
  ## "see `v3b13/2`"
  decision v3b13b(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :service_available)
    if reply do
      v3b12(conn, state)
    else
      respond(conn, state, 503)
    end
  end
  
  ## "Known method?"
  decision v3b12(conn, state) do
    {methods, conn, state} = resource_call(conn, state, :known_methods)
    if method(conn) in methods do
      v3b11(conn, state)
    else
      respond(conn, state, 501)
    end
  end
  
  ## "URI too long?"
  decision v3b11(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :uri_too_long)
    if reply  do
      respond(conn, state, 414)
    else
      v3b10(conn, state)
    end
  end
  
  ## "Method allowed?"
  decision v3b10(conn, state) do
    {methods, conn, state} = resource_call(conn, state, :allowed_methods)
    if method(conn) in methods do
      v3b9(conn, state)
    else
      conn = set_resp_headers(conn, %{"allow" => Enum.join(methods,",")})
      respond(conn, state, 405)
    end
  end
  
  ## "Content-MD5 present?"
  decision v3b9(conn, state) do
    if get_header_val(conn, "content-md5") do
      v3b9a(conn, state)
    else
      v3b9b(conn, state)
    end
  end
  
  ## "Content-MD5 valid?"
  decision v3b9a(conn, state) do
    case resource_call(conn, state, :validate_content_checksum) do
      {:not_validated, conn, state} ->
        case Base.decode64(get_header_val(conn, "content-md5")) do
          {:ok, checksum} ->
	    case compute_body_md5(conn) do
	      ^checksum ->
		v3b9b(conn, state);
	      _ ->
		respond(conn, state, 400)
	    end
          _ ->
	    respond(conn, state, 400)
        end
      {false, conn, state} ->
	respond(conn, state, 400)
      {_, conn, state} ->
	v3b9b(conn, state)
    end
  end
  
  ## "Malformed?"
  decision v3b9b(conn, state) do
    case resource_call(conn, state, :malformed_request) do
      {true, conn, state} ->
	respond(conn, state, 400)
      {false, conn, state} ->
	v3b8(conn, state)
    end
  end
  
  ## "Authorized?"
  decision v3b8(conn, state) do
    case resource_call(conn, state, :is_authorized) do
      {true, conn, state} ->
	v3b7(conn, state)
      {auth_head, conn, state} ->
        conn = set_resp_header(conn, "www-authenticate", to_string(auth_head))
	respond(conn, state, 401)
    end
  end
  
  ## "Forbidden?"
  decision v3b7(conn, state) do
    case resource_call(conn, state, :forbidden) do
      {true, conn, state} ->
	respond(conn, state, 403);
      {false, conn, state} ->
	v3b6(conn, state)
    end
  end
  
  ## "Okay Content-* Headers?"
  decision v3b6(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :valid_content_headers)
    if reply do
      v3b5(conn, state)
    else
      respond(conn, state, 501)
    end
  end
  
  ## "Known Content-Type?"
  decision v3b5(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :known_content_type)
    if reply do
      v3b4(conn, state)
    else
      respond(conn, state, 415)
    end
  end
  
  ## "Req Entity Too Large?"
  decision v3b4(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :valid_entity_length)
    if reply do
      v3b3(conn, state)
    else
      respond(conn, state, 413)
    end
  end
  
  ## "OPTIONS?"
  decision v3b3(conn, state) do
    case method(conn) do
      "OPTIONS"->
        {hdrs, conn, state} = resource_call(conn, state, :options)
        conn = set_resp_headers(conn, hdrs)
        respond(conn, state, 200)
      _ ->
	v3c3(conn, state)
    end
  end

  ## "Accept exists?"
  decision v3c3(conn, state) do
    {ct_provided, conn, state} = resource_call(conn, state, :content_types_provided)
    p_types = for {type,_fun} <- ct_provided, do: normalize_mtype(type)
    case get_header_val(conn, "accept") do
      nil ->
	conn = set_metadata(conn, :'content-type', hd(p_types))
	v3d4(conn, state)
      _ ->
	v3c4(conn, state)
    end
  end

  ## "Acceptable media type available?"
  decision v3c4(conn, state) do
    {ct_provided, conn, state} = resource_call(conn, state, :content_types_provided)
    p_types = for {type,_fun} <- ct_provided, do: normalize_mtype(type)
    case choose_media_type(p_types, get_header_val(conn, "accept")) do
      nil ->
	respond(conn, state, 406)
      type ->
	conn = set_metadata(conn, :'content-type', type)
	v3d4(conn, state)
    end
  end
  
  ## "Accept-Language exists?"
  decision v3d4(conn, state) do
    if get_header_val(conn, "accept-language") do
      v3d5(conn, state)
    else
      v3e5(conn, state)
    end
  end
  
  ## "Acceptable Language available? %% WMACH-46 (do this as proper conneg)"
  decision v3d5(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :language_available)
    if reply do
      v3e5(conn, state)
    else
      respond(conn, state, 406)
    end
  end
  
  ## "Accept-Charset exists?"
  decision v3e5(conn, state) do
    case get_header_val(conn, "accept-charset") do
      nil ->
	{charset, conn, state} = choose_charset(conn, state, "*")
	case charset do
	  nil -> respond(conn, state, 406);
	  _   -> v3f6(conn, state)
	end
      _ -> v3e6(conn, state)
    end
  end
  
  ## "Acceptable Charset available?"
  decision v3e6(conn, state) do
    accept = get_header_val(conn, "accept-charset")
    {charset, conn, state} = choose_charset(conn, state, accept)
    case charset do
      nil -> respond(conn, state, 406);
      _   -> v3f6(conn, state)
    end
  end
  
  ## Accept-Encoding exists?
  ## also, set content-type header here, now that charset is chosen)
  decision v3f6(conn, state) do
    {type, subtype, params} = get_metadata(conn, :'content-type')
    char = get_metadata(conn, :'chosen-charset')
    params = char && Dict.put(params, :charset, char) || params
    conn = set_resp_header(conn, "content-type", format_mtype({type,subtype,params}))
    case get_header_val(conn, "accept-encoding") do
      nil ->
	{encoding, conn, state} = choose_encoding(conn, state, "identity;q=1.0,*;q=0.5")
	case encoding do
	  nil -> respond(conn, state, 406);
	  _   -> v3g7(conn, state)
	end
      _ -> v3f7(conn, state)
    end
  end
  
  ## "Acceptable encoding available?"
  decision v3f7(conn, state) do
    accept = get_header_val(conn, "accept-encoding")
    {encoding, conn, state} = choose_encoding(conn, state, accept)
    case encoding do
      nil -> respond(conn, state, 406);
      _   -> v3g7(conn, state)
    end
  end
  
  ## "Resource exists?"
  decision v3g7(conn, state) do
    ## his is the first place after all conneg, so set Vary here
    {vars, conn, state} = variances(conn, state)
    conn = if length(vars) > 0 do
      set_resp_header(conn, "vary", Enum.join(vars, ","))
    else
      conn
    end

    {reply, conn, state} = resource_call(conn, state, :resource_exists)
    if reply do
      v3g8(conn, state)
    else
      v3h7(conn, state)
    end
  end
  
  ## "If-Match exists?"
  decision v3g8(conn, state) do
    if get_header_val(conn, "if-match") do
      v3g9(conn, state)
    else
      v3h10(conn, state)
    end
  end
    
  ## "If-Match: * exists"
  decision v3g9(conn, state) do
    if get_header_val(conn, "if-match") == "*" do
      v3h10(conn, state)
    else
      v3g11(conn, state)
    end
  end
  
  ## "ETag in If-Match"
  decision v3g11(conn, state) do
    etags = split_quoted_strings(get_header_val(conn, "if-match"))
    {reply, conn, state} = resource_call(conn, state, :generate_etag)
    if reply in etags do
      v3h10(conn, state)
    else
      respond(conn, state, 412)
    end
  end
  
  ## "If-Match exists"
  decision v3h7(conn, state) do
    if get_header_val(conn, "if-match") do
      respond(conn, state, 412)
    else
      v3i7(conn, state)
    end
  end
  
  ## "If-unmodified-since exists?"
  decision v3h10(conn, state) do
    if get_header_val(conn, "if-unmodified-since") do
      v3h11(conn, state)
    else
      v3i12(conn, state)
    end
  end
  
  ## "I-UM-S is valid date?"
  decision v3h11(conn, state) do
    iums_date = get_header_val(conn, "if-unmodified-since")
    if convert_request_date(iums_date) == :bad_date do
      v3i12(conn, state)
    else
      v3h12(conn, state)
    end
  end
  
  ## "Last-Modified > I-UM-S?"
  decision v3h12(conn, state) do
    req_date = get_header_val(conn, "if-unmodified-since")
    req_erl_date = convert_request_date(req_date)
    {res_erl_date, conn, state} = resource_call(conn, state, :last_modified)
    if res_erl_date > req_erl_date do
      respond(conn, state, 412)
    else
      v3i12(conn, state)
    end
  end
  
  ## "Moved permanently? (apply PUT to different URI)"
  decision v3i4(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :moved_permanently)
    case reply do
      {true, moved_uri} ->
	conn = set_resp_header(conn, "location", moved_uri)
	respond(conn, state, 301)
      false ->
	v3p3(conn, state)
    end
  end
  
  ## "PUT?"
  decision v3i7(conn, state) do
    if method(conn) == "PUT" do
      v3i4(conn, state)
    else
      v3k7(conn, state)
    end
  end
  
  ## "If-none-match exists?"
  decision v3i12(conn, state) do
    if get_header_val(conn, "if-none-match") do
      v3i13(conn, state)
    else
      v3l13(conn, state)
    end
  end
  
  ## "If-None-Match: * exists?"
  decision v3i13(conn, state) do
    if get_header_val(conn, "if-none-match") == "*" do
      v3j18(conn, state)
    else
      v3k13(conn, state)
    end
  end
  
  ## "GET or HEAD?"
  decision v3j18(conn, state) do
    if method(conn) in ["GET","HEAD"] do
      respond(conn, state, 304)
    else
      respond(conn, state, 412)
    end
  end
  
  ## "Moved permanently?"
  decision v3k5(conn, state) do
    case resource_call(conn, state, :moved_permanently) do
      {{true, moved_uri}, conn, state} ->
	conn = set_resp_header(conn, "location", moved_uri)
	respond(conn, state, 301)
      {false, conn, state} ->
	v3l5(conn, state)
    end
  end
  
  ## "Previously existed?"
  decision v3k7(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :previously_existed)
    if reply do
      v3k5(conn, state)
    else
      v3l7(conn, state)
    end
  end
  
  ## "Etag in if-none-match?"
  decision v3k13(conn, state) do
    etags = split_quoted_strings(get_header_val(conn, "if-none-match"))
    ## Membership test is a little counter-intuitive here; if the
    ## provided ETag is a member, we follow the error case out
    ## via v3j18.
    {etag, conn, state} = resource_call(conn, state, :generate_etag)
    if etag in etags do
      v3j18(conn, state)
    else
      v3l13(conn, state)
    end
  end
  
  ## "Moved temporarily?"
  decision v3l5(conn, state) do
    case resource_call(conn, state, :moved_temporarily) do
      {{true, moved_uri}, conn, state} ->
	conn = set_resp_header(conn, "location", moved_uri)
	respond(conn, state, 307)
      {false, conn, state} ->
	v3m5(conn, state)
    end
  end
  
  ## "POST?"
  decision v3l7(conn, state) do
    if method(conn) == "POST" do
      v3m7(conn, state)
    else
      respond(conn, state, 404)
    end
  end
  
  ## "IMS exists?"
  decision v3l13(conn, state) do
    if get_header_val(conn, "if-modified-since") do
      v3l14(conn, state)
    else
      v3m16(conn, state)
    end
  end
  
  ## "IMS is valid date?"
  decision v3l14(conn, state) do
    ims_date = get_header_val(conn, "if-modified-since")
    if convert_request_date(ims_date) == :bad_date do
      v3m16(conn, state)
    else
      v3l15(conn, state)
    end
  end
  
  ## "IMS > Now?"
  decision v3l15(conn, state) do
    now_date_time = :calendar.universal_time
    req_date = get_header_val(conn, "if-modified-since")
    req_erl_date = convert_request_date(req_date)
    if req_erl_date > now_date_time do
      v3m16(conn, state)
    else
      v3l17(conn, state)
    end
  end
  
  ## "Last-Modified > IMS?"
  decision v3l17(conn, state) do
    req_date = get_header_val(conn, "if-modified-since")
    req_erl_date = convert_request_date(req_date)
    {res_erl_date, conn, state} = resource_call(conn, state, :last_modified)
    if !res_erl_date or res_erl_date > req_erl_date do
      v3m16(conn, state)
    else
      respond(conn, state, 304)
    end
  end
  
  ## "POST?"
  decision v3m5(conn, state) do
    if method(conn) == "POST" do
      v3n5(conn, state)
    else
      respond(conn, state, 410)
    end
  end
  
  ## "Server allows POST to missing resource?"
  decision v3m7(conn, state) do
    {amp, conn, state} = resource_call(conn, state, :allow_missing_post)
    if amp do
      v3n11(conn, state)
    else
      respond(conn, state, 404)
    end
  end
  
  ## "DELETE?"
  decision v3m16(conn, state) do
    if method(conn) == "DELETE" do
      v3m20(conn, state)
    else
      v3n16(conn, state)
    end
  end
  
  ## "DELETE enacted immediately?  Also where DELETE is forced"
  decision v3m20(conn, state) do
    {result, conn, state} = resource_call(conn, state, :delete_resource)
    ## DELETE may have body and TCP connection will be closed unless body is read
    ## See mochiweb_request:should_close.
    ## TODO, see how to flush req body stream
    if result do
      v3m20b(conn, state)
    else
      respond(conn, state, 500)
    end
  end
  
  decision v3m20b(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :delete_completed)
    if reply do
      v3o20(conn, state)
    else
      respond(conn, state, 202)
    end
  end
  
  ## "Server allows POST to missing resource?"
  decision v3n5(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :allow_missing_post)
    if reply do
      v3n11(conn, state)
    else
      respond(conn, state, 410)
    end
  end
  
  ## "Redirect?"
  decision v3n11(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :post_is_create)
    if reply do
      {_, conn, state} = accept_helper(conn, state)
      {new_path, conn, state} = resource_call(conn, state, :create_path)

      if is_nil(new_path), do: raise "post_is_create w/o create_path"
      if !is_binary(new_path), do: raise "create_path not a string (#{inspect new_path})"
      
      {base_uri, conn, state} = resource_call(conn, state, :base_uri)
      base_uri = if String.last(base_uri) == "/" do
	String.slice(base_uri,0..-2)
      else
	base_uri
      end
      new_path = if !match?("/"<>_, new_path) do
	"#{path(conn)}/#{new_path}"
      else
	new_path
      end
      
      conn = if !get_resp_header(conn, "location") do
        set_resp_header(conn, "location", base_uri <> new_path)
      else
	conn
      end
      redirect_helper(conn, state)
    else
      {true, conn, state} = resource_call(conn, state, :process_post)
      {_, conn, state} = encode_body_if_set(conn, state)
      redirect_helper(conn, state)
    end
  end
  
  ## "POST?"
  decision v3n16(conn, state) do
    if method(conn) == "POST" do
      v3n11(conn, state)
    else
      v3o16(conn, state)
    end
  end
  
  ## "Conflict?"
  decision v3o14(conn, state) do
    case resource_call(conn, state, :is_conflict) do
      {true, conn, state} ->
	respond(conn, state, 409)
      {_, conn, state} -> 
        {_, conn, state} = accept_helper(conn, state)
        v3p11(conn, state)
    end
  end
  
  ## "PUT?"
  decision v3o16(conn, state) do
    if method(conn) == "PUT" do
      v3o14(conn, state)
    else
      v3o18(conn, state)
    end
  end
  
  ## Multiple representations?
  ## also where body generation for GET and HEAD is done)
  decision v3o18(conn, state) do
    if method(conn) in ["GET","HEAD"] do
      {etag, conn, state} = resource_call(conn, state, :generate_etag)
      conn = if etag, do: set_resp_header(conn, "etag", quoted_string(etag)), else: conn

      ct = get_metadata(conn, :'content-type')

      {lm, conn, state} = resource_call(conn, state, :last_modified)
      conn = if lm, do: set_resp_header(conn, "last-modified", rfc1123_date(lm)), else: conn
      {exp, conn, state} = resource_call(conn, state, :expires)
      conn = if exp, do: set_resp_header(conn, "expires", rfc1123_date(exp)), else: conn
      {ct_provided, conn, state} = resource_call(conn, state, :content_types_provided)
      f = Enum.find_value(ct_provided, fn {t,f} -> normalize_mtype(t) == ct && f end)
      {body, conn, state} = resource_call(conn, state, f)
      {body, conn, state} = encode_body(conn, state, body)
      conn = set_resp_body(conn, body)
      v3o18b(conn, state)
    else
      v3o18b(conn, state)
    end
  end
  
  decision v3o18b(conn, state) do
    {mc, conn, state} = resource_call(conn, state, :multiple_choices)
    if mc do
      respond(conn, state, 300)
    else
      respond(conn, state, 200)
    end
  end
  
  ## "Response includes an entity?"
  decision v3o20(conn, state) do
    if has_resp_body(conn) do
      v3o18(conn, state)
    else
      respond(conn, state, 204)
    end
  end
  
  ## "Conflict?"
  decision v3p3(conn, state) do
    {reply, conn, state} = resource_call(conn, state, :is_conflict)
    if reply do
      respond(conn, state, 409)
    else
      {_, conn, state} = accept_helper(conn, state)
      v3p11(conn, state)
    end
  end
  
  ## "New resource?  (at this point boils down to \"has location header\")"
  decision v3p11(conn, state) do
    if get_resp_header(conn, "location") do
      respond(conn, state, 201)
    else
      v3o20(conn, state)
    end
  end
  
  ###
  ### Helpers
  ###
  def variances(conn, state) do
    {ct_provided, conn, state} = resource_call(conn, state, :content_types_provided)
    {enc_provided, conn, state} = resource_call(conn, state, :encodings_provided)
    accept = if length(ct_provided) < 2, do: [], else: ["Accept"]
    accept_enc = if length(enc_provided) < 2, do: [], else: ["Accept-Encoding"]
    {accept_char, conn, state} = case resource_call(conn, state, :charsets_provided) do
				   {:no_charset, c, s} ->
				     {[], c, s}
				   {charset, c, s} ->
				     if length(charset) < 2 do
				       {[], c, s}
				     else
				       {["Accept-Charset"], c, s}
				     end
				 end
    {variances, conn, state} = resource_call(conn, state, :variances)
    {accept ++ accept_enc ++ accept_char ++ variances, conn, state}
  end
  
  def accept_helper(conn, state) do
    ct = get_header_val(conn, "content-type") || "application/octet-stream"
    {_, _, h_params} = ct = normalize_mtype(ct)
    conn = set_metadata(conn, :mediaparams, h_params)
    {ct_accepted, conn, state} = resource_call(conn, state, :content_types_accepted)
    
    mtfun = Enum.find_value(ct_accepted, fn {accept,f} ->
      fuzzy_mt_match(ct,normalize_mtype(accept)) && f
    end)
      
    if mtfun do
      {_reply, conn, state} = resource_call(conn, state, mtfun)
      encode_body_if_set(conn, state)
    else
      respond(conn, state, 415)
      throw {:halt, conn}
    end
  end
      
  def encode_body_if_set(conn, state) do
    if has_resp_body(conn) do
      body = resp_body(conn)
      {body, conn, state} = encode_body(conn, state, body)
      conn = set_resp_body(conn, body)
      {:ok, conn, state}
    else
      {:ok, conn, state}
    end
  end
  
  def encode_body(conn, state, body) do
    chosen_cset = get_metadata(conn, :'chosen-charset')
    {charsetter, conn, state} = case resource_call(conn, state, :charsets_provided) do
				  {:no_charset, c, s} ->
				    {&(&1), c, s}
				  {cp, c, s} ->
				    cs = Enum.find_value(cp, fn {c, f} ->
				      (to_string(c) == chosen_cset) && f
				    end) || &(&1)
				    {cs, c, s}
				end
    chosen_enc = get_metadata(conn, :'content-encoding')
    {enc_provided, conn, state} = resource_call(conn, state, :encodings_provided)
    encoder = Enum.find_value(enc_provided,
      fn {enc,f} -> (to_string(enc) == chosen_enc) && f end) || &(&1)
    body = case body do
	     body when is_binary(body) or is_list(body) ->
	       body |> IO.iodata_to_binary |> charsetter.() |> encoder.()
	     _->
	       body |> Stream.map(&IO.iodata_to_binary/1) |> Stream.map(charsetter) |> Stream.map(encoder)
	   end
    {body, conn, state}
  end
  
  def choose_encoding(conn, state, acc_enc_hdr) do
    {enc_provided, conn, state} = resource_call(conn, state, :encodings_provided)
    encs = for {enc, _} <- enc_provided, do: to_string(enc)
    chosen_enc = choose_encoding(encs, acc_enc_hdr)
    conn = if chosen_enc !== "identity" do
      set_resp_header(conn, "content-encoding", chosen_enc)
    else
      conn
    end
    conn = set_metadata(conn, :'content-encoding', chosen_enc)
    {chosen_enc, conn, state}
  end
  
  def choose_charset(conn, state, acc_char_hdr) do
    case resource_call(conn, state, :charsets_provided) do
      {:no_charset, conn, state} ->
	{:no_charset, conn, state}
      {cl, conn, state} ->
        charsets = for {cset,_f} <- cl, do: to_string(cset)
	charset = choose_charset(charsets, acc_char_hdr)
        conn = if (charset) do
          set_metadata(conn, :'chosen-charset', charset)
	else
	  conn
        end
	{charset, conn, state}
    end
  end

  def redirect_helper(conn, state) do
    if resp_redirect(conn) do
      if !get_resp_header(conn, "location") do
        raise "Response had do_redirect but no Location"
      else
	respond(conn, state, 303)
      end
    else
      	v3p11(conn, state)
    end
  end
  
  def respond(conn, state, code) do
    {conn, state} = if (code == 304) do
      conn = remove_resp_header(conn, "content-type")
      {etag, conn, state} = resource_call(conn, state, :generate_etag)
      conn = if etag, do: set_resp_header(conn, "etag", quoted_string(etag)), else: conn
      
      {exp, conn, state} = resource_call(conn, state, :expires)
      conn = if exp, do: set_resp_header(conn, "expires", rfc1123_date(exp)), else: conn
      {conn, state}
    else
      {conn, state}
    end
    conn = set_response_code(conn, code)
    resource_call(conn, state, :finish_request)    
  end
end
