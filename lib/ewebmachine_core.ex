defmodule Ewebmachine.Core do
  import Ewebmachine.Core.DSL
  import Ewebmachine.Core.Helpers
  import Ewebmachine.Core.Utils

  decision v3, do: d(v3b13)

  ## "Service Available"
  decision v3b13, do:
    h(decision_test(resource_call(:ping), :pong, :v3b13b, 503))
  decision v3b13b, do:
    h(decision_test(resource_call(:service_available), true, :v3b12, 503))
  ## "Known method?"
  decision v3b12, do:
    h(decision_test(h(method) in resource_call(:known_methods),true, :v3b11, 501))
  ## "URI too long?"
  decision v3b11, do:
    h(decision_test(resource_call(:uri_too_long), true, 414, :v3b10))
  ## "Method allowed?"
  decision v3b10 do
    methods = resource_call(:allowed_methods)
    if h(method) in methods do
      d(v3b9)
    else
      h(set_resp_headers(%{"Allow"=>Enum.join(methods,",")}))
      d(respond(405))
    end
  end
  
  ## "Content-MD5 present?"
  decision v3b9, do:
    h(decision_test(h(get_header_val("content-md5")), nil, :v3b9b, :v3b9a))
  ## "Content-MD5 valid?"
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
  ## "Malformed?"
  decision v3b9b, do:
    h(decision_test(resource_call(:malformed_request), true, 400, :v3b8))
  ## "Authorized?"
  decision v3b8 do
    case resource_call(:is_authorized) do
      true -> d(v3b7)
      auth_head ->
        h(set_resp_header("WWW-Authenticate", auth_head))
        d(respond(401))
    end
  end
      
  ## "Forbidden?"
  decision v3b7, do:
    h(decision_test(resource_call(:forbidden), true, 403, :v3b6))
  ## "Okay Content-* Headers?"
  decision v3b6, do:
    h(decision_test(resource_call(:valid_content_headers), true, :v3b5, 501))
  ## "Known Content-Type?"
  decision v3b5, do:
    h(decision_test(resource_call(:known_content_type), true, :v3b4, 415))
  ## "Req Entity Too Large?"
  decision v3b4, do:
    h(decision_test(resource_call(:valid_entity_length), true, :v3b3, 413))
  ## "OPTIONS?"
  decision v3b3 do
    case h(method) do
      "OPTIONS"->
        hdrs = resource_call(:options)
        h(set_resp_headers(hdrs))
        d(respond(200))
      _ -> d(v3c3)
    end
  end
  ## Accept exists?
  decision v3c3 do
    p_types = for {type,_fun}<-resource_call(:content_types_provided), do: type
    case h(get_header_val("accept")) do
      nil -> set_metadata(:'content-type', hd(p_types)); d(v3d4)
      _ -> d(v3c4)
    end
  end
  ## Acceptable media type available?
  decision v3c4 do
    p_types = for {type,_fun}<-resource_call(:content_types_provided), do: type
    case choose_media_type(p_types, h(get_header_val("accept"))) do
      nil -> d(respond(406))
      type -> set_metadata(:'content-type', type); d(v3d4)
    end
  end
  ## Accept-Language exists?
  decision v3d4, do:
    h(decision_test(h(get_header_val("accept-language")),nil, :v3e5, :v3d5))
  ## Acceptable Language available? %% WMACH-46 (do this as proper conneg)
  decision v3d5, do:
    h(decision_test(resource_call(:language_available), true, :v3e5, 406);)
  ## Accept-Charset exists?
  decision v3e5 do
    case h(get_header_val("accept-charset")) do
      nil -> h(decision_test(choose_charset("*"),nil, 406, :v3f6))
      _ -> d(v3e6)
    end
  end
  ## Acceptable Charset available?
  decision v3e6, do:
    h(decision_test(choose_charset(h(get_header_val("accept-charset"))),nil, 406, :v3f6))
  ## Accept-Encoding exists?
  ## also, set content-type header here, now that charset is chosen)
  decision v3f6 do
    ctype = h(get_metadata(:'content-type'))
    charset = (char=h(get_metadata(:'chosen-charset'))) && "; charset=#{char}" || ""
    h(set_resp_header("Content-Type",ctype<>charset))
    case h(get_header_val("accept-encoding")) do
      nil -> h(decision_test(choose_encoding("identity;q=1.0,*;q=0.5"),nil, 406, :v3g7))
      _ -> d(v3f7)
    end
  end
  ## Acceptable encoding available?
  decision v3f7, do:
    h(decision_test(choose_encoding(h(get_header_val("accept-encoding"))), nil, 406, :v3g7))
  ## "Resource exists?"
  decision v3g7 do
  ## his is the first place after all conneg, so set Vary here
    vars = variances
    if(length(vars)>0, do: h(set_resp_header("Vary",Enum.join(vars,",")))
    h(decision_test(resource_call(:resource_exists), true, :v3g8, :v3h7))
  end
  ## "If-Match exists?"
  decision v3g8, do:
    h(decision_test(h(get_header_val("if-match")), nil, :v3h10, :v3g9))
  ## "If-Match: * exists"
  decision v3g9, do:
    h(decision_test(h(get_header_val("if-match")), "*", :v3h10, :v3g11))
  ## "ETag in If-Match"
  decision v3g11 do
    etags = split_quoted_strings(h(get_header_val("if-match")))
    h(decision_test_fn(resource_call(:generate_etag),&(&1 in etags),:v3h10, 412))
  end
  ## "If-Match exists"
  ## (note: need to reflect this change at in next version of diagram)
  decision v3h7, do:
    h(decision_test(h(get_header_val("if-match")), nil, :v3i7, 412))
  ## "If-unmodified-since exists?"
  decision v3h10, do:
    h(decision_test(h(get_header_val("if-unmodified-since")),nil,:v3i12,:v3h11))
  ## "I-UM-S is valid date?"
  decision v3h11 do
    iums_date = h(get_header_val("if-unmodified-since"))
    h(decision_test(convert_request_date(iums_date),:bad_date,:v3i12,:v3h12))
  end
  ## "Last-Modified > I-UM-S?"
  decision v3h12 do
    req_date = h(get_header_val("if-unmodified-since"))
    req_erl_date = convert_request_date(req_date)
    res_erl_date = resource_call(:last_modified)
    h(decision_test(res_erl_date > req_erl_date,true,412,:v3i12))
  end
  ## "Moved permanently? (apply PUT to different URI)"
  decision v3i4 do
    case resource_call(:moved_permanently) do
      {true, moved_uri} -> h(set_resp_header("Location", moved_uri)); d(respond(301))
      false -> d(v3p3)
    end
  end
  ## PUT?
  decision v3i7, do:
    h(decision_test(h(method),"PUT",:v3i4,:v3k7))
  ## "If-none-match exists?"
  decision v3i12, do:
    h(decision_test(h(get_header_val("if-none-match")),nil,:v3l13,:v3i13))
  ## "If-None-Match: * exists?"
  decision v3i13, do:
    h(decision_test(h(get_header_val("if-none-match")), "*", :v3j18, :v3k13);)
  ## GET or HEAD?
  decision v3j18 do
    h(decision_test(h(method) in ['GET','HEAD'],true, 304, 412))
  ## "Moved permanently?"
  decision v3k5 do
    case resource_call(:moved_permanently) do
      {true, moved_uri}-> h(set_resp_header("Location",moved_uri));d(respond(301))
      false -> d(v3l5)
    end
  end
  ## "Previously existed?"
  decision v3k7, do:
    h(decision_test(resource_call(:previously_existed), true, :v3k5, :v3l7))
  ## "Etag in if-none-match?"
  decision v3k13 do
    etags = split_quoted_strings(h(get_header_val("if-none-match")))
    ## Membership test is a little counter-intuitive here; if the
    ## provided ETag is a member, we follow the error case out
    ## via v3j18.
    h(decision_test_fn(resource_call(:generate_etag),&(&1 in etags),:v3j18,:v3l13))
  end
  ## "Moved temporarily?"
  decision v3l5 do
    case resource_call(:moved_temporarily) of
      {true, moved_uri} -> h(set_resp_header("Location", moved_uri));d(respond(307))
      false -> d(v3m5)
    end
  end
  ## "POST?"
  decision v3l7, do:
    h(decision_test(h(method), "POST", :v3m7, 404))
  ## "IMS exists?"
  decision v3l13, do:
    h(decision_test(h(get_header_val("if-modified-since")),nil,:v3m16,:v3l14))
  ## "IMS is valid date?"
  decision v3l14 do
    ims_date = h(get_header_val("if-modified-since"))
    h(decision_test(convert_request_date(ims_date),:bad_date,:v3m16,:v3l15))
  end
  ## "IMS > Now?"
  decision v3l15 do
    now_date_time = :calendar.universal_time
    req_date = h(get_header_val("if-modified-since"))
    req_erl_date = convert_request_date(req_date)
    h(decision_test(req_erl_date > now_date_time,true,:v3m16,:v3l17))
  end
  ## "Last-Modified > IMS?"
  decision v3l17 do
    req_date = h(get_header_val("if-modified-since"))
    req_erl_date = convert_request_date(req_date)
    res_erl_date = resource_call(:last_modified)
    h(decision_test(res_erl_date == nil or res_erl_date > req_erl_date,true,:v3m16, 304))
  end
  ## "POST?"
  decision v3m5, do:
    h(decision_test(h(method),"POST",:v3n5,410))
  ## "Server allows POST to missing resource?"
  decision v3m7, do:
    h(decision_test(resource_call(:allow_missing_post),true,:v3n11,404))
  ## "DELETE?"
  decision v3m16, do:
    h(decision_test(h(method),"DELETE",:v3m20,:v3n16))
  ## DELETE enacted immediately?
  ## Also where DELETE is forced
  decision v3m20 do
    result = resource_call(:delete_resource)
    ## DELETE may have body and TCP connection will be closed unless body is read
    ## See mochiweb_request:should_close.
    ## TODO, see how to flush req body stream
    h(decision_test(result,true,:v3m20b,500))
  end
  decision v3m20b, do:
    h(decision_test(resource_call(:delete_completed),true,:v3o20,202))
  ## "Server allows POST to missing resource?"
  decision v3n5, do:
    h(decision_test(resource_call(:allow_missing_post),true,:v3n11,410))
  ## "Redirect?"
  decision v3n11 do
    stage1 = case resource_call(:post_is_create) do
      true ->
        new_path = resource_call(:create_path)
        if is_nil(new_path), do: throw new Exception("post_is_create w/o create_path")
        if !is_binary(new_path), do: throw new Exception("create_path not a string (#{inspect new_path})")
        base_uri = case resource_call(:base_uri) do
          nil -> h(base_uri)
          any -> if String.last(any)=="/", do: String.slice(any,0..-2), else: any
        end
        full_path = "/#{h(path)}/#{new_path}"
        h(set_disp_path(new_path))
        if !h(get_resp_header("Location")), do:
          h(set_resp_header("Location",base_uri<>full_path))
        h(accept_helper)
      false ->
        true = resource_call(:process_post)
        encode_body_if_set
        :stage1_ok
    end,
    case Stage1 of
          stage1_ok ->
              case h(resp_redirect) of
                  true ->
                      case h(get_resp_header("Location")) of
                          undefined ->
                              Reason = "Response had do_redirect but no Location",
                              error_response(500, Reason);
                          _ ->
                              respond(303)
                      end;
                  _ ->
                      d(v3p11)
              end;
          _ -> nop
      end;
  ## "POST?"
  decision v3n16 do
      h(decision_test(h(method), 'POST', v3n11, v3o16);)
  ## Conflict?
  decision v3o14 do
      case resource_call(is_conflict) of
          true -> respond(409);
          _ -> Res = accept_helper(),
               case Res of
                   {respond, Code} -> respond(Code);
                   {halt, Code} -> respond(Code);
                   {error, _,_} -> error_response(Res);
                   {error, _} -> error_response(Res);
                   _ -> d(v3p11)
               end
      end;
  ## "PUT?"
  decision v3o16 do
      h(decision_test(h(method), 'PUT', v3o14, v3o18);)
  ## Multiple representations?
  ## also where body generation for GET and HEAD is done)
  decision v3o18 do
      BuildBody = case h(method) of
          'GET' -> true;
          'HEAD' -> true;
          _ -> false
      end,
      FinalBody = case BuildBody of
          true ->
              case resource_call(generate_etag) of
                  undefined -> nop;
                  ETag -> wrcall({set_resp_header, "ETag", webmachine_util:quoted_string(ETag)})
              end,
              CT = wrcall({get_metadata, 'content-type'}),
              case resource_call(last_modified) of
                  undefined -> nop;
                  LM ->
                      wrcall({set_resp_header, "Last-Modified",
                              webmachine_util:rfc1123_date(LM)})
              end,
              case resource_call(expires) of
                  undefined -> nop;
                  Exp ->
                      wrcall({set_resp_header, "Expires",
                              webmachine_util:rfc1123_date(Exp)})
              end,
              F = hd([Fun || {Type,Fun} <- resource_call(content_types_provided),
                             CT =:= webmachine_util:format_content_type(Type)]),
              resource_call(F);
          false -> nop
      end,
      case FinalBody of
          {error, _} -> error_response(FinalBody);
          {error, _,_} -> error_response(FinalBody);
          {halt, Code} -> respond(Code);
          nop -> d(v3o18b);
          _ -> wrcall({set_resp_body,
                       encode_body(FinalBody)}),
               d(v3o18b)
      end;
  
  decision v3o18b do
      h(decision_test(resource_call(multiple_choices), true, 300, 200);)
  ## Response includes an entity?
  decision v3o20 do
      h(decision_test(wrcall(has_resp_body), true, v3o18, 204);)
  ## Conflict?
  decision v3p3 do
      case resource_call(is_conflict) of
          true -> respond(409);
          _ -> Res = accept_helper(),
               case Res of
                   {respond, Code} -> respond(Code);
                   {halt, Code} -> respond(Code);
                   {error, _,_} -> error_response(Res);
                   {error, _} -> error_response(Res);
                   _ -> d(v3p11)
               end
      end;
  
  ## New resource?  (at this point boils down to "has location header")
  decision v3p11 do
      case h(get_resp_header("Location") of
          undefined -> d(v3o20);
          _ -> respond(201)
      end
  end
  
  
  decision respond(code) do
    if code == 304 do
      h(remove_resp_header("Content-Type"))
      if (e_tag=resource_call(:generate_etag)), do:
        h(set_resp_header("ETag", Ewebmachine.Util.quoted_string(etag)))
      if (exp=resource_call(:expires)), do:
        h(set_resp_header("Expires",Ewebmachine.Util.rfc1123_date(exp)))
    end
    h(set_response_code(code))
    resource_call(:finish_request)
  end
end

defmodule Ewebmachine.Core.Utils do
  def choose_media_type(content_types,accept_header) do
    nil
  end
  def quoted_string(etag) do
    ## TODO webmachine_util:quoted_string(ETag)
    etag
  end
  def rfc1123_date(exp) do
    ## TODO  webmachine_util:rfc1123_date(Exp)
    exp
  end
  def split_quoted_strings(str) do
    ## TODO webmachine_util:split_quoted_strings
    []
  end
  def convert_request_date(date) do
    ## TODO webmachine_util:convert_request_date(IUMSDate)
    date
  end
  def media_type_to_detail(ct) do
    ## webmachine_util:media_type_to_detail(CT)
  end
end

defmodule Ewebmachine.Core.Helpers do
  import Ewebmachine.Core.DSL

  helper variances do
    accept = if length(resource_call(:content_types_provided))<2, do: [], else: ["Accept"]
    accept_enc = if length(resource_call(:encodings_provided))<2, do: [], else: ["Accept-Encoding"]
    accept_char = case resource_call(:charsets_provided) do
        :no_charset -> []
        charset -> if length(charset)<2, do: [], else: ["Accept-Charset"]
    end,
    accept ++ accept_enc ++ accept_char ++ resource_call(:variances)
  end

  helper accept_helper do
    ct = h(get_header_val("Content-Type")) || "application/octet-stream"
    {mt,mparams} = Ewebmachine.Core.Utils.media_type_to_detail(ct)
    h(set_metadata(:mediaparams,mparams))
    mtfun = Enum.find_value(resource_call(:content_types_accepted), fn {t,f}-> (t == mt) && f end)
    if mtfun do 
      resource_call(mtfun)
      encode_body_if_set
    else d(respond(415)) end
  end
  
  helper encode_body_if_set do
    if h(has_resp_body) do
      body = h(resp_body)
      h(set_resp_body(encode_body(body)))
    end
  end
  
  helper encode_body(body) do
    chosen_cset = h(get_metadata(:'chosen-charset'))
    charsetter = case resource_call(:charsets_provided) do
      :no_charset -> &(&1)
      cp -> Enum.find_value(cp, fn {c,f}-> (c == chosen_cset) && f end) || &(&1)
    end,
    chosen_enc = h(get_metadata(:'content-encoding'))
    encoder = Enum.find_value(resource_call(:encodings_provided), 
                fn {enc,f}-> (enc == chosen_enc) && f end) || &(&1)
    case Body of
        {stream, StreamBody} ->
            {stream, make_encoder_stream(Encoder, Charsetter, StreamBody)};
        {known_length_stream, 0, _StreamBody} ->
            {known_length_stream, 0, empty_stream()};
        {known_length_stream, Size, StreamBody} ->
            case h(method) of
                'HEAD' ->
                    {known_length_stream, Size, empty_stream()};
                _ ->
                    {known_length_stream, Size, make_encoder_stream(Encoder, Charsetter, StreamBody)}
            end;
        {stream, Size, Fun} ->
            {stream, Size, make_size_encoder_stream(Encoder, Charsetter, Fun)};
        {writer, BodyFun} ->
            {writer, {Encoder, Charsetter, BodyFun}};
        _ ->
            Encoder(Charsetter(iolist_to_binary(Body)))
    end
  end
  
  ## @private
  def empty_stream() do
      {<<>>, fun() -> {<<>>, done} end}
  end
  
  def make_encoder_stream(Encoder, Charsetter, {Body, done}) do
      {Encoder(Charsetter(Body)), done};
  def make_encoder_stream(Encoder, Charsetter, {Body, Next}) do
      {Encoder(Charsetter(Body)),
       fun() -> make_encoder_stream(Encoder, Charsetter, Next()) end}
  end
  
  def make_size_encoder_stream(Encoder, Charsetter, Fun) do
      fun(Start, End) ->
              make_encoder_stream(Encoder, Charsetter, Fun(Start, End))
      end
  end
  
  def choose_encoding(AccEncHdr) do
      Encs = [Enc || {Enc,_Fun} <- resource_call(encodings_provided)],
      case webmachine_util:choose_encoding(Encs, AccEncHdr) of
          none -> none;
          ChosenEnc ->
              case ChosenEnc of
                  "identity" ->
                      nop;
                  _ ->
                      wrcall({set_resp_header, "Content-Encoding",ChosenEnc})
              end,
              wrcall({set_metadata, 'content-encoding',ChosenEnc}),
              ChosenEnc
      end
  end
  
  def choose_charset(AccCharHdr) do
      case resource_call(charsets_provided) of
          no_charset ->
              no_charset;
          CL ->
              CSets = [CSet || {CSet,_Fun} <- CL],
              case webmachine_util:choose_charset(CSets, AccCharHdr) of
                  none -> none;
                  Charset ->
                      wrcall({set_metadata, 'chosen-charset',Charset}),
                      Charset
              end
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
  helper decision_flow(x) when is_atom(x), do: d(x)
  helper decision_flow(x) when is_integer(x), do: d(respond(x))

  def port_suffix(:http,80), do: ""
  def port_suffix(:https,443), do: ""
  def port_suffix(_,port), do: ":#{port}"
end

