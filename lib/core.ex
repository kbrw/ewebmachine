defmodule Ewebmachine.Core do
  use Ewebmachine.Core.DSL
  ## Basho webmachine Core rewrited in a systematic way to make the
  ## conversion as reliable as possible. The Ewebmachine.Core.DSL
  ## allows this conversion to be clean imitating the DSL of Basho.
  @moduledoc false

  @spec v3(Plug.Conn.t, any) :: Plug.Conn.t
  def v3(conn,user_state) do
    try do
      {_,conn,_} = v3b13(Ewebmachine.Log.debug_init(conn),user_state)
      conn
    catch
      :throw, {:halt,conn}->conn
    end
  end

  ## "Service Available"
  decision v3b13, do:
    if(resource_call(:ping) == :pong, do: d(v3b13b), else: d(503))
  ## "see `v3b13/2`"
  decision v3b13b, do:
    if(resource_call(:service_available), do: d(v3b12), else: d(503))
  ## "Known method?"
  decision v3b12, do:
    if(d(method) in resource_call(:known_methods), do: d(v3b11), else: d(501))
  ## "URI too long?"
  decision v3b11, do:
    if(resource_call(:uri_too_long),do: d(414), else: d(v3b10))
  ## "Method allowed?"
  decision v3b10 do
    methods = resource_call(:allowed_methods)
    if d(method) in methods do
      d(v3b9)
    else
      d(set_resp_headers(%{"Allow"=>Enum.join(methods,",")}))
      d(405)
    end
  end
  
  ## "Content-MD5 present?"
  decision v3b9, do:
    if(d(get_header_val("content-md5")), do: d(v3b9a), else: d(v3b9b))
  ## "Content-MD5 valid?"
  decision v3b9a do
    case resource_call(:validate_content_checksum) do
      :not_validated ->
        case Base.decode64(d(get_header_val("content-md5"))) do
          {:ok,checksum}->
            body_hash = d(compute_body_md5)
            if body_hash == checksum, do: d(v3b9b), else: d(400)
          _ -> d(400)
        end
      false -> d(400)
      _ -> d(v3b9b)
    end
  end
  ## "Malformed?"
  decision v3b9b, do:
    if(resource_call(:malformed_request), do: d(400), else: d(v3b8))
  ## "Authorized?"
  decision v3b8 do
    case resource_call(:is_authorized) do
      true -> d(v3b7)
      auth_head ->
        d(set_resp_header("WWW-Authenticate", auth_head))
        d(401)
    end
  end
      
  ## "Forbidden?"
  decision v3b7, do:
    if(resource_call(:forbidden), do: d(403), else: d(v3b6))
  ## "Okay Content-* Headers?"
  decision v3b6, do:
    if(resource_call(:valid_content_headers), do: d(v3b5), else: d(501))
  ## "Known Content-Type?"
  decision v3b5, do:
    if(resource_call(:known_content_type), do: d(v3b4), else: d(415))
  ## "Req Entity Too Large?"
  decision v3b4, do:
    if(resource_call(:valid_entity_length), do: d(v3b3), else: d(413))
  ## "OPTIONS?"
  decision v3b3 do
    case d(method) do
      "OPTIONS"->
        hdrs = resource_call(:options)
        d(set_resp_headers(hdrs))
        d(200)
      _ -> d(v3c3)
    end
  end
  ## "Accept exists?"
  decision v3c3 do
    ct_provided = resource_call(:content_types_provided)
    p_types = for {type,_fun}<-ct_provided, do: normalize_mtype(type)
    case d(get_header_val("accept")) do
      nil -> d(set_metadata(:'content-type', hd(p_types))); d(v3d4)
      _ -> d(v3c4)
    end
  end
  ## "Acceptable media type available?"
  decision v3c4 do
    ct_provided = resource_call(:content_types_provided)
    p_types = for {type,_fun}<-ct_provided, do: normalize_mtype(type)
    case choose_media_type(p_types, d(get_header_val("accept"))) do
      nil -> d(406)
      type -> d(set_metadata(:'content-type', type)); d(v3d4)
    end
  end
  ## "Accept-Language exists?"
  decision v3d4, do:
    if(d(get_header_val("accept-language")), do: d(v3d5), else: d(v3e5))
  ## "Acceptable Language available? %% WMACH-46 (do this as proper conneg)"
  decision v3d5, do:
    if(resource_call(:language_available), do: d(v3e5), else: d(406))
  ## "Accept-Charset exists?"
  decision v3e5 do
    case d(get_header_val("accept-charset")) do
      nil -> if(d(choose_charset("*")), do: d(v3f6), else: d(406))
      _ -> d(v3e6)
    end
  end
  ## "Acceptable Charset available?"
  decision v3e6 do
    accept = d(get_header_val("accept-charset"))
    if(d(choose_charset(accept)), do: d(v3f6), else: d(406))
  end
  ## Accept-Encoding exists?
  ## also, set content-type header here, now that charset is chosen)
  decision v3f6 do
    {type,subtype,params} = d(get_metadata(:'content-type'))
    params = (char=d(get_metadata(:'chosen-charset'))) && Dict.put(params,:charset,char) || params
    d(set_resp_header("content-type",format_mtype({type,subtype,params})))
    case d(get_header_val("accept-encoding")) do
      nil -> if(d(choose_encoding("identity;q=1.0,*;q=0.5")), do: d(v3g7), else: d(406))
      _ -> d(v3f7)
    end
  end
  ## "Acceptable encoding available?"
  decision v3f7 do
    accept = d(get_header_val("accept-encoding"))
    if(d(choose_encoding(accept)), do: d(v3g7), else: d(406))
  end
  ## "Resource exists?"
  decision v3g7 do
    ## his is the first place after all conneg, so set Vary here
    vars = d(variances)
    if length(vars)>0, do: d(set_resp_header("Vary",Enum.join(vars,",")))
    if(resource_call(:resource_exists), do: d(v3g8), else: d(v3h7))
  end
  ## "If-Match exists?"
  decision v3g8, do:
    if(d(get_header_val("if-match")), do: d(v3g9), else: d(v3h10))
  ## "If-Match: * exists"
  decision v3g9, do:
    if(d(get_header_val("if-match")) == "*", do: d(v3h10), else: d(v3g11))
  ## "ETag in If-Match"
  decision v3g11 do
    etags = split_quoted_strings(d(get_header_val("if-match")))
    if resource_call(:generate_etag) in etags, do: d(v3h10), else: d(412)
  end
  ## "If-Match exists"
  decision v3h7, do:
    if(d(get_header_val("if-match")), do: d(412), else: d(v3i7))
  ## "If-unmodified-since exists?"
  decision v3h10, do:
    if(d(get_header_val("if-unmodified-since")), do: d(v3h11), else: d(v3i12))
  ## "I-UM-S is valid date?"
  decision v3h11 do
    iums_date = d(get_header_val("if-unmodified-since"))
    if convert_request_date(iums_date) == :bad_date, do: d(v3i12), else: d(v3h12)
  end
  ## "Last-Modified > I-UM-S?"
  decision v3h12 do
    req_date = d(get_header_val("if-unmodified-since"))
    req_erl_date = convert_request_date(req_date)
    res_erl_date = resource_call(:last_modified)
    if res_erl_date > req_erl_date, do: d(412), else: d(v3i12)
  end
  ## "Moved permanently? (apply PUT to different URI)"
  decision v3i4 do
    case resource_call(:moved_permanently) do
      {true, moved_uri} -> d(set_resp_header("Location", moved_uri)); d(301)
      false -> d(v3p3)
    end
  end
  ## "PUT?"
  decision v3i7, do:
    if(d(method) == "PUT", do: d(v3i4), else: d(v3k7))
  ## "If-none-match exists?"
  decision v3i12, do:
    if(d(get_header_val("if-none-match")), do: d(v3i13), else: d(v3l13))
  ## "If-None-Match: * exists?"
  decision v3i13, do:
    if(d(get_header_val("if-none-match")) == "*", do: d(v3j18), else: d(v3k13))
  ## "GET or HEAD?"
  decision v3j18, do:
    if(d(method) in ["GET","HEAD"], do: d(304), else: d(412))
  ## "Moved permanently?"
  decision v3k5 do
    case resource_call(:moved_permanently) do
      {true, moved_uri}-> d(set_resp_header("Location",moved_uri));d(301)
      false -> d(v3l5)
    end
  end
  ## "Previously existed?"
  decision v3k7, do:
    if(resource_call(:previously_existed), do: d(v3k5), else: d(v3l7))
  ## "Etag in if-none-match?"
  decision v3k13 do
    etags = split_quoted_strings(d(get_header_val("if-none-match")))
    ## Membership test is a little counter-intuitive here; if the
    ## provided ETag is a member, we follow the error case out
    ## via v3j18.
    if(resource_call(:generate_etag) in etags, do: d(v3j18), else: d(v3l13))
  end
  ## "Moved temporarily?"
  decision v3l5 do
    case resource_call(:moved_temporarily) do
      {true, moved_uri} -> d(set_resp_header("Location", moved_uri));d(307)
      false -> d(v3m5)
    end
  end
  ## "POST?"
  decision v3l7, do:
    if(d(method) == "POST", do: d(v3m7), else: d(404))
  ## "IMS exists?"
  decision v3l13, do:
    if(d(get_header_val("if-modified-since")), do: d(v3l14), else: d(v3m16))
  ## "IMS is valid date?"
  decision v3l14 do
    ims_date = d(get_header_val("if-modified-since"))
    if convert_request_date(ims_date) == :bad_date, do: d(v3m16), else: d(v3l15)
  end
  ## "IMS > Now?"
  decision v3l15 do
    now_date_time = :calendar.universal_time
    req_date = d(get_header_val("if-modified-since"))
    req_erl_date = convert_request_date(req_date)
    if req_erl_date > now_date_time, do: d(v3m16), else: d(v3l17)
  end
  ## "Last-Modified > IMS?"
  decision v3l17 do
    req_date = d(get_header_val("if-modified-since"))
    req_erl_date = convert_request_date(req_date)
    res_erl_date = resource_call(:last_modified)
    if !res_erl_date or res_erl_date > req_erl_date, do: d(v3m16), else: d(304)
  end
  ## "POST?"
  decision v3m5, do:
    if(d(method) == "POST", do: d(v3n5), else: d(410))
  ## "Server allows POST to missing resource?"
  decision v3m7, do:
    if(resource_call(:allow_missing_post), do: d(v3n11), else: d(404))
  ## "DELETE?"
  decision v3m16, do:
    if(d(method) == "DELETE", do: d(v3m20), else: d(v3n16))
  ## "DELETE enacted immediately?  Also where DELETE is forced"
  decision v3m20 do
    result = resource_call(:delete_resource)
    ## DELETE may have body and TCP connection will be closed unless body is read
    ## See mochiweb_request:should_close.
    ## TODO, see how to flush req body stream
    if result, do: d(v3m20b), else: d(500)
  end
  decision v3m20b, do:
    if(resource_call(:delete_completed), do: d(v3o20), else: d(202))
  ## "Server allows POST to missing resource?"
  decision v3n5, do:
    if(resource_call(:allow_missing_post), do: d(v3n11), else: d(410))
  ## "Redirect?"
  decision v3n11 do
    if resource_call(:post_is_create) do
      d(accept_helper)
      new_path = resource_call(:create_path)
      if is_nil(new_path), do: raise(Exception, "post_is_create w/o create_path")
      if !is_binary(new_path), do: raise(Exception, "create_path not a string (#{inspect new_path})")
      base_uri = resource_call(:base_uri)
      base_uri = if String.last(base_uri)=="/", do: String.slice(base_uri,0..-2), else: base_uri
      new_path = if !match?("/"<>_,new_path), do: "/#{d(path)}/#{new_path}", else: new_path
      if !d(get_resp_header("Location")), do:
        d(set_resp_header("Location",base_uri<>new_path))
    else 
      true = resource_call(:process_post)
      d(encode_body_if_set)
    end
    d(redirect_helper)
  end
  ## "POST?"
  decision v3n16, do:
    if(d(method) == "POST", do: d(v3n11), else: d(v3o16))
  ## "Conflict?"
  decision v3o14 do
    case resource_call(:is_conflict) do
      true -> d(409)
      _ -> 
        d(accept_helper)
        d(v3p11)
    end
  end
  ## "PUT?"
  decision v3o16, do:
    if(d(method)=="PUT", do: d(v3o14), else: d(v3o18))
  ## Multiple representations?
  ## also where body generation for GET and HEAD is done)
  decision v3o18 do
    final_body = if d(method) in ["GET","HEAD"] do
      if (etag=resource_call(:generate_etag)), do:
        d(set_resp_header("ETag",quoted_string(etag)))
      ct = d(get_metadata(:'content-type'))
      if (lm=resource_call(:last_modified)), do:
        d(set_resp_header("Last-Modified",rfc1123_date(lm)))
      if (exp=resource_call(:expires)), do:
        d(set_resp_header("Expires",rfc1123_date(exp)))
      ct_provided = resource_call(:content_types_provided)
      f = Enum.find_value(ct_provided,fn {t,f}->normalize_mtype(t)==ct && f end)
      body = resource_call(f)
      body = d(encode_body(body))
      d(set_resp_body(body))
      d(v3o18b)
    else
      d(v3o18b)
    end
  end
  
  decision v3o18b, do:
    if(resource_call(:multiple_choices), do: d(300), else: d(200))
  ## "Response includes an entity?"
  decision v3o20, do:
    if(d(has_resp_body), do: d(v3o18), else: d(204))
  ## "Conflict?"
  decision v3p3 do
    if resource_call(:is_conflict) do
      d(409)
    else
      d(accept_helper)
      d(v3p11)
    end
  end
  
  ## "New resource?  (at this point boils down to \"has location header\")"
  decision v3p11 do
    if d(get_resp_header("Location")) do
      d(201)
    else
      d(v3o20)
    end
  end

  helper variances do
    ct_provided = resource_call(:content_types_provided)
    enc_provided = resource_call(:encodings_provided)
    accept = if length(ct_provided)<2, do: [], else: ["Accept"]
    accept_enc = if length(enc_provided)<2, do: [], else: ["Accept-Encoding"]
    accept_char = case resource_call(:charsets_provided) do
        :no_charset -> []
        charset -> if length(charset)<2, do: [], else: ["Accept-Charset"]
    end
    variances = resource_call :variances
    accept ++ accept_enc ++ accept_char ++ variances
  end

  helper accept_helper do
    ct = d(get_header_val("content-type")) || "application/octet-stream"
    {_,_,h_params}=ct=normalize_mtype(ct)
    d(set_metadata(:mediaparams,h_params))
    ct_accepted = resource_call(:content_types_accepted)
    mtfun = Enum.find_value(ct_accepted, fn {accept,f}->fuzzy_mt_match(ct,normalize_mtype(accept)) && f end)
    if mtfun do 
      resource_call(mtfun)
      d(encode_body_if_set)
    else 
      d(415)
    end
  end
  
  helper encode_body_if_set do
    if d(has_resp_body) do
      body = d(resp_body)
      d(set_resp_body(d(encode_body(body))))
    end
  end
  
  helper encode_body(body) do
    chosen_cset = d(get_metadata(:'chosen-charset'))
    charsetter = case resource_call(:charsets_provided) do
      :no_charset -> &(&1)
      cp -> Enum.find_value(cp, fn {c,f}-> (to_string(c) == chosen_cset) && f end) || &(&1)
    end
    chosen_enc = d(get_metadata(:'content-encoding'))
    encoder = Enum.find_value(resource_call(:encodings_provided), 
                fn {enc,f}-> (to_string(enc) == chosen_enc) && f end) || &(&1)
    case body do
      body when is_binary(body) or is_list(body)-> body |> IO.iodata_to_binary |> charsetter.() |> encoder.()
      _-> body |> Stream.map(&IO.iodata_to_binary/1) |> Stream.map(charsetter) |> Stream.map(encoder)
    end
  end
  
  helper choose_encoding(acc_enc_hdr) do
    enc_provided = resource_call(:encodings_provided)
    encs = for {enc,_}<-enc_provided, do: to_string(enc)
    if(chosen_enc=choose_encoding(encs, acc_enc_hdr)) do
      if chosen_enc !== "identity", do:
        d(set_resp_header("Content-Encoding",chosen_enc))
      d(set_metadata(:'content-encoding',chosen_enc))
      chosen_enc
    end
  end
  
  helper choose_charset(acc_char_hdr) do
    case resource_call(:charsets_provided) do
      :no_charset -> :no_charset
      cl ->
        charsets = for {cset,_f}<-cl, do: to_string(cset)
        if (charset=choose_charset(charsets, acc_char_hdr)) do
          d(set_metadata(:'chosen-charset',charset))
          charset
        end
    end
  end

  helper redirect_helper do
    if d(resp_redirect) do
      if !d(get_resp_header("Location")), do:
        raise(Exception, "Response had do_redirect but no Location")
      d(303)
    else 
      d(v3p11) 
    end
  end
  
  helper respond(code) do
    if code == 304 do
      d(remove_resp_header("content-type"))
      if (etag=resource_call(:generate_etag)), do:
        d(set_resp_header("ETag", quoted_string(etag)))
      if (exp=resource_call(:expires)), do:
        d(set_resp_header("Expires",rfc1123_date(exp)))
    end
    d(set_response_code(code))
    resource_call(:finish_request)
  end
end

