defmodule Ewebmachine.Core do
  use Ewebmachine.Core.DSL

  def v3(conn,user_state) do
    {_,conn,_} = v3b13(Ewebmachine.Log.debug_init(conn),user_state)
    conn
  end

  @doc "Service Available"
  decision v3b13, do:
    h(decision_test(resource_call(:ping), :pong, :v3b13b, 503))
  decision v3b13b, do:
    h(decision_test(resource_call(:service_available), true, :v3b12, 503))
  @doc "Known method?"
  decision v3b12, do:
    h(decision_test(h(method) in resource_call(:known_methods),true, :v3b11, 501))
  @doc "URI too long?"
  decision v3b11, do:
    h(decision_test(resource_call(:uri_too_long), true, 414, :v3b10))
  @doc "Method allowed?"
  decision v3b10 do
    methods = resource_call(:allowed_methods)
    if h(method) in methods do
      d(v3b9)
    else
      h(set_resp_headers(%{"Allow"=>Enum.join(methods,",")}))
      d(respond(405))
    end
  end
  
  @doc "Content-MD5 present?"
  decision v3b9, do:
    h(decision_test(h(get_header_val("content-md5")), nil, :v3b9b, :v3b9a))
  @doc "Content-MD5 valid?"
  decision v3b9a do
    case resource_call(:validate_content_checksum) do
      :not_validated ->
        checksum = Base.decode64!(h(get_header_val("content-md5")))
        body_hash = h(compute_body_md5)
        if body_hash == checksum, do: d(v3b9b), else: d(respond(400))
      false -> d(respond(400))
      _ -> d(v3b9b)
    end
  end
  @doc "Malformed?"
  decision v3b9b, do:
    h(decision_test(resource_call(:malformed_request), true, 400, :v3b8))
  @doc "Authorized?"
  decision v3b8 do
    case resource_call(:is_authorized) do
      true -> d(v3b7)
      auth_head ->
        h(set_resp_header("WWW-Authenticate", auth_head))
        d(respond(401))
    end
  end
      
  @doc "Forbidden?"
  decision v3b7, do:
    h(decision_test(resource_call(:forbidden), true, 403, :v3b6))
  @doc "Okay Content-* Headers?"
  decision v3b6, do:
    h(decision_test(resource_call(:valid_content_headers), true, :v3b5, 501))
  @doc "Known Content-Type?"
  decision v3b5, do:
    h(decision_test(resource_call(:known_content_type), true, :v3b4, 415))
  @doc "Req Entity Too Large?"
  decision v3b4, do:
    h(decision_test(resource_call(:valid_entity_length), true, :v3b3, 413))
  @doc "OPTIONS?"
  decision v3b3 do
    case h(method) do
      "OPTIONS"->
        hdrs = resource_call(:options)
        h(set_resp_headers(hdrs))
        d(respond(200))
      _ -> d(v3c3)
    end
  end
  @doc "Accept exists?"
  decision v3c3 do
    p_types = for {type,_fun}<-resource_call(:content_types_provided), do: normalize_mtype(type)
    case h(get_header_val("accept")) do
      nil -> h(set_metadata(:'content-type', hd(p_types))); d(v3d4)
      _ -> d(v3c4)
    end
  end
  @doc "Acceptable media type available?"
  decision v3c4 do
    p_types = for {type,_fun}<-resource_call(:content_types_provided), do: normalize_mtype(type)
    case choose_media_type(p_types, h(get_header_val("accept"))) do
      nil -> d(respond(406))
      type -> h(set_metadata(:'content-type', type)); d(v3d4)
    end
  end
  @doc "Accept-Language exists?"
  decision v3d4, do:
    h(decision_test(h(get_header_val("accept-language")),nil, :v3e5, :v3d5))
  @doc "Acceptable Language available? %% WMACH-46 (do this as proper conneg)"
  decision v3d5, do:
    h(decision_test(resource_call(:language_available), true, :v3e5, 406))
  @doc "Accept-Charset exists?"
  decision v3e5 do
    case h(get_header_val("accept-charset")) do
      nil -> h(decision_test(h(choose_charset("*")),nil, 406, :v3f6))
      _ -> d(v3e6)
    end
  end
  @doc "Acceptable Charset available?"
  decision v3e6, do:
    h(decision_test(h(choose_charset(h(get_header_val("accept-charset")))),nil, 406, :v3f6))
  @doc """
  Accept-Encoding exists?
  also, set content-type header here, now that charset is chosen)
  """
  decision v3f6 do
    {type,subtype,params} = h(get_metadata(:'content-type'))
    params = (char=h(get_metadata(:'chosen-charset'))) && Dict.put(params,:charset,char) || params
    h(set_resp_header("Content-Type",format_mtype({type,subtype,params})))
    case h(get_header_val("accept-encoding")) do
      nil -> h(decision_test(h(choose_encoding("identity;q=1.0,*;q=0.5")),nil, 406, :v3g7))
      _ -> d(v3f7)
    end
  end
  @doc "Acceptable encoding available?"
  decision v3f7, do:
    h(decision_test(h(choose_encoding(h(get_header_val("accept-encoding")))), nil, 406, :v3g7))
  @doc "Resource exists?"
  decision v3g7 do
    ## his is the first place after all conneg, so set Vary here
    vars = h(variances)
    if length(vars)>0, do: h(set_resp_header("Vary",Enum.join(vars,",")))
    h(decision_test(resource_call(:resource_exists), true, :v3g8, :v3h7))
  end
  @doc "If-Match exists?"
  decision v3g8, do:
    h(decision_test(h(get_header_val("if-match")), nil, :v3h10, :v3g9))
  @doc "If-Match: * exists"
  decision v3g9, do:
    h(decision_test(h(get_header_val("if-match")), "*", :v3h10, :v3g11))
  @doc "ETag in If-Match"
  decision v3g11 do
    etags = split_quoted_strings(h(get_header_val("if-match")))
    h(decision_test_fn(resource_call(:generate_etag),&(&1 in etags),:v3h10, 412))
  end
  @doc "If-Match exists"
  decision v3h7, do:
    h(decision_test(h(get_header_val("if-match")), nil, :v3i7, 412))
  @doc "If-unmodified-since exists?"
  decision v3h10, do:
    h(decision_test(h(get_header_val("if-unmodified-since")),nil,:v3i12,:v3h11))
  @doc "I-UM-S is valid date?"
  decision v3h11 do
    iums_date = h(get_header_val("if-unmodified-since"))
    h(decision_test(convert_request_date(iums_date),:bad_date,:v3i12,:v3h12))
  end
  @doc "Last-Modified > I-UM-S?"
  decision v3h12 do
    req_date = h(get_header_val("if-unmodified-since"))
    req_erl_date = convert_request_date(req_date)
    res_erl_date = resource_call(:last_modified)
    h(decision_test(res_erl_date > req_erl_date,true,412,:v3i12))
  end
  @doc "Moved permanently? (apply PUT to different URI)"
  decision v3i4 do
    case resource_call(:moved_permanently) do
      {true, moved_uri} -> h(set_resp_header("Location", moved_uri)); d(respond(301))
      false -> d(v3p3)
    end
  end
  @doc "PUT?"
  decision v3i7, do:
    h(decision_test(h(method),"PUT",:v3i4,:v3k7))
  @doc "If-none-match exists?"
  decision v3i12, do:
    h(decision_test(h(get_header_val("if-none-match")),nil,:v3l13,:v3i13))
  @doc "If-None-Match: * exists?"
  decision v3i13, do:
    h(decision_test(h(get_header_val("if-none-match")), "*", :v3j18, :v3k13))
  @doc "GET or HEAD?"
  decision v3j18, do:
    h(decision_test(h(method) in ['GET','HEAD'],true, 304, 412))
  @doc "Moved permanently?"
  decision v3k5 do
    case resource_call(:moved_permanently) do
      {true, moved_uri}-> h(set_resp_header("Location",moved_uri));d(respond(301))
      false -> d(v3l5)
    end
  end
  @doc "Previously existed?"
  decision v3k7, do:
    h(decision_test(resource_call(:previously_existed), true, :v3k5, :v3l7))
  @doc "Etag in if-none-match?"
  decision v3k13 do
    etags = split_quoted_strings(h(get_header_val("if-none-match")))
    ## Membership test is a little counter-intuitive here; if the
    ## provided ETag is a member, we follow the error case out
    ## via v3j18.
    h(decision_test_fn(resource_call(:generate_etag),&(&1 in etags),:v3j18,:v3l13))
  end
  @doc "Moved temporarily?"
  decision v3l5 do
    case resource_call(:moved_temporarily) do
      {true, moved_uri} -> h(set_resp_header("Location", moved_uri));d(respond(307))
      false -> d(v3m5)
    end
  end
  @doc "POST?"
  decision v3l7, do:
    h(decision_test(h(method), "POST", :v3m7, 404))
  @doc "IMS exists?"
  decision v3l13, do:
    h(decision_test(h(get_header_val("if-modified-since")),nil,:v3m16,:v3l14))
  @doc "IMS is valid date?"
  decision v3l14 do
    ims_date = h(get_header_val("if-modified-since"))
    h(decision_test(convert_request_date(ims_date),:bad_date,:v3m16,:v3l15))
  end
  @doc "IMS > Now?"
  decision v3l15 do
    now_date_time = :calendar.universal_time
    req_date = h(get_header_val("if-modified-since"))
    req_erl_date = convert_request_date(req_date)
    h(decision_test(req_erl_date > now_date_time,true,:v3m16,:v3l17))
  end
  @doc "Last-Modified > IMS?"
  decision v3l17 do
    req_date = h(get_header_val("if-modified-since"))
    req_erl_date = convert_request_date(req_date)
    res_erl_date = resource_call(:last_modified)
    h(decision_test(res_erl_date == nil or res_erl_date > req_erl_date,true,:v3m16, 304))
  end
  @doc "POST?"
  decision v3m5, do:
    h(decision_test(h(method),"POST",:v3n5,410))
  @doc "Server allows POST to missing resource?"
  decision v3m7, do:
    h(decision_test(resource_call(:allow_missing_post),true,:v3n11,404))
  @doc "DELETE?"
  decision v3m16, do:
    h(decision_test(h(method),"DELETE",:v3m20,:v3n16))
  @doc "DELETE enacted immediately?  Also where DELETE is forced"
  decision v3m20 do
    result = resource_call(:delete_resource)
    ## DELETE may have body and TCP connection will be closed unless body is read
    ## See mochiweb_request:should_close.
    ## TODO, see how to flush req body stream
    h(decision_test(result,true,:v3m20b,500))
  end
  decision v3m20b, do:
    h(decision_test(resource_call(:delete_completed),true,:v3o20,202))
  @doc "Server allows POST to missing resource?"
  decision v3n5, do:
    h(decision_test(resource_call(:allow_missing_post),true,:v3n11,410))
  @doc "Redirect?"
  decision v3n11 do
    if resource_call(:post_is_create) do
      new_path = resource_call(:create_path)
      if is_nil(new_path), do: raise(Exception, "post_is_create w/o create_path")
      if !is_binary(new_path), do: raise(Exception, "create_path not a string (#{inspect new_path})")
      base_uri = case resource_call(:base_uri) do
        nil -> h(base_uri)
        any -> if String.last(any)=="/", do: String.slice(any,0..-2), else: any
      end
      full_path = "/#{h(path)}/#{new_path}"
      h(set_disp_path(new_path))
      if !h(get_resp_header("Location")), do:
        h(set_resp_header("Location",base_uri<>full_path))
      h(accept_helper)
    else 
      true = resource_call(:process_post)
      h(encode_body_if_set)
    end
    d(redirect_helper)
  end
  @doc "POST?"
  decision v3n16, do:
    h(decision_test(h(method),"POST",:v3n11,:v3o16))
  @doc "Conflict?"
  decision v3o14 do
    case resource_call(:is_conflict) do
      true -> d(respond(409))
      _ -> 
        h(accept_helper)
        d(v3p11)
    end
  end
  @doc "PUT?"
  decision v3o16, do:
    h(decision_test(h(method), "PUT",:v3o14,:v3o18))
  @doc """
    Multiple representations?
    also where body generation for GET and HEAD is done)
  """
  decision v3o18 do
    final_body = if h(method) in ["GET","HEAD"] do
      if (etag=resource_call(:generate_etag)), do:
        h(set_resp_header("ETag",quoted_string(etag)))
      ct = h(get_metadata(:'content-type'))
      if (lm=resource_call(:last_modified)), do:
        h(set_resp_header("Last-Modified",rfc1123_date(lm)))
      if (exp=resource_call(:expires)), do:
        h(set_resp_header("Expires",rfc1123_date(exp)))
      f = Enum.find_value(resource_call(:content_types_provided),fn {t,f}->normalize_mtype(t)==ct && f end)
      body = resource_call(f)
      body = h(encode_body(body))
      h(set_resp_body(body))
      d(v3o18b)
    else
      d(v3o18b)
    end
  end
  
  decision v3o18b, do:
    h(decision_test(resource_call(:multiple_choices), true, 300, 200))
  @doc "Response includes an entity?"
  decision v3o20, do:
    h(decision_test(h(has_resp_body), true, :v3o18, 204))
  @doc "Conflict?"
  decision v3p3 do
    if resource_call(:is_conflict) do
      d(respond(409))
    else
      h(accept_helper)
      d(v3p11)
    end
  end
  
  @doc "New resource?  (at this point boils down to \"has location header\")"
  decision v3p11 do
    if h(get_resp_header("Location")) do
      d(respond(201))
    else
      d(v3o20)
    end
  end

  helper variances do
    accept = if length(resource_call(:content_types_provided))<2, do: [], else: ["Accept"]
    accept_enc = if length(resource_call(:encodings_provided))<2, do: [], else: ["Accept-Encoding"]
    accept_char = case resource_call(:charsets_provided) do
        :no_charset -> []
        charset -> if length(charset)<2, do: [], else: ["Accept-Charset"]
    end
    accept ++ accept_enc ++ accept_char ++ resource_call(:variances)
  end

  helper accept_helper do
    ct = h(get_header_val("Content-Type")) || "application/octet-stream"
    {_,_,mparams}=mt = normalize_mtype(ct)
    h(set_metadata(:mediaparams,mparams))
    mtfun = Enum.find_value(resource_call(:content_types_accepted), fn {t,f}-> (normalize_mtype(t) == mt) && f end)
    if mtfun do 
      resource_call(mtfun)
      h(encode_body_if_set)
    else 
      d(respond(415))
    end
  end
  
  helper encode_body_if_set do
    if h(has_resp_body) do
      body = h(resp_body)
      h(set_resp_body(h(encode_body(body))))
    end
  end
  
  helper encode_body(body) do
    chosen_cset = h(get_metadata(:'chosen-charset'))
    charsetter = case resource_call(:charsets_provided) do
      :no_charset -> &(&1)
      cp -> Enum.find_value(cp, fn {c,f}-> (c == chosen_cset) && f end) || &(&1)
    end
    chosen_enc = h(get_metadata(:'content-encoding'))
    encoder = Enum.find_value(resource_call(:encodings_provided), 
                fn {enc,f}-> (enc == chosen_enc) && f end) || &(&1)
    case body do
      %Stream{}-> body |> Stream.map(&IO.iodata_to_binary/1) |> Stream.map(charsetter) |> Stream.map(encoder)
      _-> body |> IO.iodata_to_binary |> charsetter.() |> encoder.()
    end
  end
  
  helper choose_encoding(acc_enc_hdr) do
    encs = for {enc,_}<-resource_call(:encodings_provided), do: enc
    if(chosen_enc=choose_encoding(encs, acc_enc_hdr)) do
      if chosen_enc !== "identity", do:
        h(set_resp_header("Content-Encoding",chosen_enc))
      h(set_metadata(:'content-encoding',chosen_enc))
      chosen_enc
    end
  end
  
  helper choose_charset(acc_char_hdr) do
    case resource_call(:charsets_provided) do
      :no_charset -> :no_charset
      cl ->
        charsets = for {cset,_f}<-cl, do: cset
        if (charset=choose_charset(charsets, acc_char_hdr)) do
          h(set_metadata(:'chosen-charset',charset))
          charset
        end
    end
  end

  helper redirect_helper do
    if h(resp_redirect) do
      if !h(get_resp_header("Location")), do:
        raise(Exception, "Response had do_redirect but no Location")
      d(respond(303))
    else 
      d(v3p11) 
    end
  end

  helper decision_test_fn(test,test_fn,true_flow,false_flow) do
    if test_fn.(test), 
      do: h(decision_flow(true_flow)), 
      else: h(decision_flow(false_flow))
  end 
  helper decision_test(test,test_val,true_flow,false_flow) do
    h(decision_test_fn(test,&(&1 == test_val),true_flow,false_flow))
  end
  helper decision_flow(x) when is_atom(x) do #manual "d" in order to get dynamic function name
    case conn do
      %{private: %{machine_halt_conn: nil}}->conn
      %{private: %{machine_halt_conn: halt_conn}}-> conn = halt_conn
      %{halted: true}->conn
      _ -> {_,conn,user_state} = apply(__MODULE__,x,[conn,user_state]); conn
    end
  end
  helper decision_flow(x) when is_integer(x), do: d(respond(x))
  
  helper respond(code) do
    if code == 304 do
      h(remove_resp_header("Content-Type"))
      if (etag=resource_call(:generate_etag)), do:
        h(set_resp_header("ETag", quoted_string(etag)))
      if (exp=resource_call(:expires)), do:
        h(set_resp_header("Expires",rfc1123_date(exp)))
    end
    h(set_response_code(code))
    resource_call(:finish_request)
  end
end

