defmodule Ewebmachine.Handlers do
  @type conn :: Plug.Conn.t
  @type state :: any
  @type halt :: {:halt, 200..599}

  @moduledoc """
  Implement the functions described below to make decisions in the 
  [HTTP decision tree](http_diagram.png) :

  - `service_available/2`
  - `resource_exists/2`
  - `is_authorized/2`
  - `forbidden/2`
  - `allow_missing_post/2`
  - `malformed_request/2`
  - `uri_too_long/2`
  - `known_content_type/2`
  - `valid_content_headers/2`
  - `valid_entity_length/2`
  - `options/2`
  - `allowed_methods/2`
  - `known_methods/2`
  - `content_types_provided/2`
  - `content_types_accepted/2`
  - `delete_resource/2`
  - `delete_completed/2`
  - `post_is_create/2`
  - `create_path/2`
  - `base_uri/2`
  - `process_post/2`
  - `language_available/2`
  - `charsets_provided/2`
  - `encodings_provided/2`
  - `variances/2`
  - `is_conflict/2`
  - `multiple_choices/2`
  - `previously_existed/2`
  - `moved_permanently/2`
  - `moved_temporarily/2`
  - `last_modified/2`
  - `expires/2`
  - `generate_etag/2`
  - `validate_content_checksum/2`
  - `ping/2`
  - Body-producing function, see `to_html/2` (but any function name can be
    used, as referenced by `content_types_provided/2`
  - POST/PUT processing function, see `from_json/2` (but any function name can be
    used, as referenced by `content_types_accepted/2`

  All the handlers have the same signature :

  ```
  (conn :: Plug.Conn.t,state :: any)->{response :: any | {:halt,200..599},conn :: Plug.Conn.t, state :: any}
  ```

  where every handler implementation : 

  - can change or halt the plug `conn` passed as argument
  - can change the user state object passed from on handler to another in its arguments
  - returns something which will make decision in the HTTP decision tree (see
    documentation of functions in this module to see expected results and effects)
  - can return `{:halt,200..599}` to end the ewebmachine automate execution,
    but do not `halt` the `conn`, so the plug pipeline can continue.

  So each handler implementation is actually a "plug" returning a response giving
  information allowing to make the good response code and path in the HTTP
  specification.

  ## Usage ##

  The following modules will help you to construct these handlers and use them :

  - `Ewebmachine.Builder.Handlers` gives you macros and helpers to define the
    handlers and automatically create the plug to add them to your `conn.private[:resource_handlers]`
  - `Ewebmachine.Plug.Run` run the HTTP decision tree executing the handler
     implementations described in its `conn.private[:resource_handlers]`. The
     initial user `state` is taken in `conn.private[:machine_init]`

  """

  @doc """
  Returning non-true values will result in `503 Service Unavailable`.

  Default: `true`
  """
  @spec service_available(conn,state) :: {boolean | halt,conn,state}
  def service_available(conn,state), do: {true,conn,state}

  @doc """
  Returning non-true values will result in `404 Not Found`.

  Default: `true`
  """
  @spec resource_exists(conn,state) :: {boolean | halt,conn,state}
  def resource_exists(conn,state), do: {true,conn,state}

  @doc """
  If this returns anything other than `true`, the response will be
  `401 Unauthorized`. The return value will be used as the value in
  the `WWW-Authenticate` header, for example `Basic
  realm="Webmachine"`.

  Default: `true`
  """
  @spec is_authorized(conn,state) :: {boolean | halt,conn,state}
  def is_authorized(conn,state), do: {true,conn,state}

  @doc """
  Returning true will result in 403 Forbidden.

  Default: `false`
  """
  @spec forbidden(conn,state) :: {boolean | halt,conn,state}
  def forbidden(conn,state), do: {false,conn,state}

  @doc """
  If the resource accepts POST requests to nonexistent resources, then this should return `true`.

  Default: `false`
  """
  @spec allow_missing_post(conn,state) :: {boolean | halt,conn,state}
  def allow_missing_post(conn,state), do: {false,conn,state}

  @doc """
  Returning true will result in 400 Bad Request.

  Default: `false`
  """
  @spec malformed_request(conn,state) :: {boolean | halt,conn,state}
  def malformed_request(conn,state), do:
    {false,conn,state}

  @doc """
  Returning true will result in 414 Request-URI Too Long.

  Default: `false`
  """
  @spec uri_too_long(conn,state) :: {boolean | halt,conn,state}
  def uri_too_long(conn,state), do:
    {false,conn,state}

  @doc """
  Returning false will result in 415 Unsupported Media Type.

  Default: `true`
  """
  @spec known_content_type(conn,state) :: {boolean | halt,conn,state}
  def known_content_type(conn,state), do:
    {true,conn,state}

  @doc """
  Returning false will result in 501 Not Implemented.

  Default: `true`
  """
  @spec valid_content_headers(conn,state) :: {boolean | halt,conn,state}
  def valid_content_headers(conn,state), do:
    {true,conn,state}

  @doc """
  Returning false will result in 413 Request Entity Too Large.

  Default: `false`
  """
  @spec valid_entity_length(conn,state) :: {boolean | halt,conn,state}
  def valid_entity_length(conn,state), do:
    {true,conn,state}

  @doc """
  If the OPTIONS method is supported and is used, the return value of
  this function is expected to be a list of pairs representing header
  names and values that should appear in the response.
  """
  @spec options(conn,state) :: {[{String.t,String.t}] | halt,conn,state}
  def options(conn,state), do:
    {[],conn,state}

  @doc """
  If a Method not in this list is requested, then a 405 Method Not
  Allowed will be sent. Note that these are all-caps Strings (binary).

  Default: `["GET", "HEAD"]`
  """
  @spec allowed_methods(conn,state) :: {[String.t] | halt,conn,state}
  def allowed_methods(conn,state), do:
    {["GET", "HEAD"],conn,state}

  @doc """
  Override the known methods accepted by your automate

  Default: `["GET", "HEAD", "POST", "PUT", "DELETE", "TRACE", "CONNECT", "OPTIONS"]`
  """
  @spec known_methods(conn,state) :: {[String.t] | halt,conn,state}
  def known_methods(conn,state), do:
    {["GET", "HEAD", "POST", "PUT", "DELETE", "TRACE", "CONNECT", "OPTIONS"],conn,state}

  @doc """
  This should return a key value tuple enumerable where the key is
  the content-type format and the value is an atom naming the
  function which can provide a resource representation in that media
  type. Content negotiation is driven by this return value. For
  example, if a client request includes an Accept header with a value
  that does not appear as a first element in any of the return
  tuples, then a 406 Not Acceptable will be
  sent.

  Default: `[{"text/html", to_html}]`
  """
  @spec content_types_provided(conn,state) :: {[{String.Chars.t,atom}] | Enum.t | halt,conn,state}
  def content_types_provided(conn,state), do:
    {[{"text/html", :to_html}],conn,state}

  @doc """
  This is used similarly to content_types_provided, except that it is
  for incoming resource representations -- for example, PUT requests.
  Handler functions usually want to use `Plug.read_body(conn)` to
  access the incoming request body.
  
  Default: `[]`
  """
  @spec content_types_accepted(conn,state) :: {[{String.Chars.t,atom}] | Enum.t | halt,conn,state}
  def content_types_accepted(conn,state), do:
    {[],conn,state}

  @doc """
  This is called when a DELETE request should be enacted, and should
  return `true` if the deletion succeeded.
  """
  @spec delete_resource(conn,state) :: {boolean | halt,conn,state}
  def delete_resource(conn,state), do:
    {false,conn,state}

  @doc """
  This is only called after a successful `delete_resource` call, and
  should return `false` if the deletion was accepted but cannot yet be
  guaranteed to have finished.
  """
  @spec delete_completed(conn,state) :: {boolean | halt,conn,state}
  def delete_completed(conn,state), do:
    {true,conn,state}

  @doc """
  If POST requests should be treated as a request to put content into
  a (potentially new) resource as opposed to being a generic
  submission for processing, then this function should return true.
  If it does return `true`, then `create_path` will be called and the
  rest of the request will be treated much like a PUT to the Path
  entry returned by that call.

  Default: `false`
  """
  @spec post_is_create(conn,state) :: {boolean | halt,conn,state}
  def post_is_create(conn,state), do:
    {false,conn,state}

  @doc """
  This will be called on a POST request if `post_is_create` returns
  true. It is an error for this function not to produce a Path if
  post_is_create returns true. The Path returned should be a valid
  URI part.
  """
  @spec create_path(conn,state) :: {nil | String.t | halt,conn,state}
  def create_path(conn,state), do:
    {nil,conn,state}

  @doc """
  The base URI used in the location header on resource creation (when
  `post_is_create` is `true`), will be prepended to the `create_path`
  """
  @spec base_uri(conn,state) :: {String.t | halt,conn,state}
  def base_uri(conn,state), do:
    {"#{conn.scheme}://#{conn.host}#{port_suffix(conn.scheme,conn.port)}",conn,state}

  defp port_suffix(:http,80), do: ""
  defp port_suffix(:https,443), do: ""
  defp port_suffix(_,port), do: ":#{port}"

  @doc """
  If `post_is_create` returns `false`, then this will be called to
  process any POST requests. If it succeeds, it should return `true`.
  """
  @spec process_post(conn,state) :: {boolean | halt,conn,state}
  def process_post(conn,state), do:
    {false,conn,state}

  @doc """
  return false if language in
  `Plug.Conn.get_resp_header(conn,"accept-language")` is not
  available.
  """
  @spec language_available(conn,state) :: {boolean | halt,conn,state}
  def language_available(conn,state), do:
    {true,conn,state}

  @doc """
  If this is anything other than the atom `:no_charset`, it must be a
  `{key,value}` Enumerable where `key` is the charset and `value` is a
  callable function in the resource which will be called on the
  produced body in a GET and ensure that it is in Charset.

  Default: `:no_charset`
  """
  @spec charsets_provided(conn,state) :: {:no_charset | [{String.Chars.t,(binary->binary)}] | Enum.t | halt,conn,state}
  def charsets_provided(conn,state), do:
    {:no_charset,conn,state}
  ## this atom causes charset-negotation to short-circuit
  ## the default setting is needed for non-charset responses such as image/png
  ##    an example of how one might do actual negotiation
  ##    [{"iso-8859-1", fun(X) -> X end}, {"utf-8", make_utf8}];

  @doc """
  This must be a `{key,value}` Enumerable where `key` is a valid
  content encoding and `value` is a callable function in the resource
  which will be called on the produced body in a GET and ensure that
  it is so encoded. One useful setting is to have the function check
  on method, and on GET requests return:

  ```
  [identity: &(&1), gzip: &:zlib.gzip/1]
  ```
   as this is all that is needed to support gzip content encoding.

   Default: `[{"identity", fn X-> X end}]`
  """
  @spec encodings_provided(conn,state) :: {[{String.Chars.t,(binary->binary)}] | Enum.t | halt,conn,state}
  def encodings_provided(conn,state), do:
    {[{"identity", &(&1)}],conn,state}
  # this is handy for auto-gzip of GET-only resources:
  #    [{"identity", fun(X) -> X end}, {"gzip", fun(X) -> zlib:gzip(X) end}];

  @doc """
  If this function is implemented, it should return a list of strings
  with header names that should be included in a given response's
  Vary header. The standard conneg headers (`Accept`, `Accept-Encoding`,
  `Accept-Charset`, `Accept-Language`) do not need to be specified here
  as Webmachine will add the correct elements of those automatically
  depending on resource behavior.

  Default : `[]`
  """
  @spec variances(conn,state) :: {[String.t] | halt,conn,state}
  def variances(conn,state), do:
    {[],conn,state}

  @doc """
  If this returns `true`, the client will receive a 409 Conflict.

  Default : `false`
  """
  @spec is_conflict(conn,state) :: {boolean | halt,conn,state}
  def is_conflict(conn,state), do:
    {false,conn,state}

  @doc """
  If this returns `true`, then it is assumed that multiple
  representations of the response are possible and a single one
  cannot be automatically chosen, so a `300 Multiple Choices` will be
  sent instead of a `200 OK`.

  Default: `false`
  """
  @spec multiple_choices(conn,state) :: {boolean | halt,conn,state}
  def multiple_choices(conn,state), do:
    {false,conn,state}

  @doc """
  If this returns `true`, the `moved_permanently` and `moved_temporarily`
  callbacks will be invoked to determine whether the response should
  be `301 Moved Permanently`, `307 Temporary Redirect`, or `410 Gone`.

  Default: `false`
  """
  @spec previously_existed(conn,state) :: {boolean | halt,conn,state}
  def previously_existed(conn,state), do:
    {false,conn,state}

  @doc """
  If this returns `{true, uri}`, the client will receive a `301 Moved
  Permanently` with `uri` in the Location header.

  Default: `false`
  """
  @spec moved_permanently(conn,state) :: {boolean | halt,conn,state}
  def moved_permanently(conn,state), do:
    {false,conn,state}

  @doc """
  If this returns `{true, uri}`, the client will receive a `307
  Temporary Redirect` with `uri` in the Location header.

  Default: `false`
  """
  @spec moved_temporarily(conn,state) :: {boolean | halt,conn,state}
  def moved_temporarily(conn,state), do:
    {false,conn,state}

  @doc """
  If this returns a `datetime()` (`{{day,month,year},{h,m,s}}`, it
  will be used for the `Last-Modified` header and for comparison in
  conditional requests.

  Default: `nil`
  """
  @spec last_modified(conn,state) :: {nil | {{day::integer,month::integer,year::integer},{hour::integer,min::integer,sec::integer}} | halt,conn,state}
  def last_modified(conn,state), do:
    {nil,conn,state}

  @doc """
  If not `nil`, set the expires header

  Default: `nil`
  """
  @spec expires(conn,state) :: {nil | {{day::integer,month::integer,year::integer},{hour::integer,min::integer,sec::integer}} | halt,conn,state}
  def expires(conn,state), do:
    {nil,conn,state}

  @doc """
  If not `nil`, it will be used for the ETag header and
  for comparison in conditional requests.

  Default: `nil`
  """
  @spec generate_etag(conn,state) :: {nil | binary | halt,conn,state}
  def generate_etag(conn,state), do:
    {nil,conn,state}

  @doc """
  if `content-md5` header exists: 
  - If `:not_validated`, test if input body validate `content-md5`,
  - if return `false`, then return a bad request

  Useful if content-md5 validation does not imply only raw md5 hash
  """
  @spec validate_content_checksum(conn,state) :: {:not_validated | boolean | halt,conn,state}
  def validate_content_checksum(conn,state), do:
    {:not_validated,conn,state}

  @doc """
  Must be present and returning `pong` to prove that handlers are
  well linked to the automate
  """
  @spec ping(conn,state) :: {:pang | :pong | halt,conn,state}
  def ping(conn,state), do:
    {:pang,conn,state}

  @doc """
  Example body-producing function, function atom name must be referenced in `content_types_provided/2`.
  
  - If the result is an `Enumerable` of `iodata`, then the HTTP response will be
    a chunk encoding response where each chunk on element of the enumeration.
  - If the result is an iodata, then it is used as the HTTP response body
  """
  @spec to_html(conn,state) :: {iodata | Enum.t | halt,conn,state}
  def to_html(conn,state), do:
    {"<html><body><h1>Hello World</h1></body></html>",conn,state}

  @doc """
  Example POST/PUT processing function, function atom name must be referenced
  in `content_types_accepted/2`.

  It will be called when the request is `PUT` or when the
    request is `POST` and `post_is_create` returns true.
  """
  @spec from_json(conn,state) :: {true | halt,conn,state}
  def from_json(conn,state), do:
    {true,conn,state}
end
