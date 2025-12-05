defmodule Ewebmachine.Handlers do
  @moduledoc """
  Provides the default implementation for each resource handler.

  An handler is a function with the following signature:
  ```elixir
  @spec handler(conn, state) :: {response :: any | {:halt, 200..599}, conn, state}
    when conn: Plug.Conn.t(), state: var()
  ```

  An handler:
  * can update the `conn`

    > ##### Halting the connection {: .top}
    >
    > Halting the `conn` will not stop the execution of the HTTP decision tree
    > of Ewebmachine.

  * can change the state

    > #### Ewebmachine and `state` {: .info}
    > Ewebmachine never modifies the `state` is only pass it between handlers.

  * should return a response which will influence the HTTP decision tree. If an
    handler returns `{:halt, 200.599}`, the execution of the HTTP decision tree
    is immediatly stopped (the `conn` is not halted though).

    Each handler has its own specific response type, see each handler below.

  Handler functions are usually defined inside a
  `Ewebmachine.Builder.Resources.resource/2` via the macros defined by the
  `Ewebmachine.Builder.Handlers` module.

  A set of common handlers can also be defined see the documentation of
  `Ewebmachine.Builder.Handlers`.
  """

  @type conn :: Plug.Conn.t()
  @type state :: any
  @type halt :: {:halt, 200..599}

  @doc """
  Returning non-true values will result in `503 Service Unavailable`.

  Default: `true`
  """
  @doc group: :handler
  @spec service_available(conn, state) :: {boolean | halt, conn, state}
  def service_available(conn, state), do: {true, conn, state}

  @doc """
  Returning non-true values will result in `404 Not Found`.

  Default: `true`
  """
  @doc group: :handler
  @spec resource_exists(conn, state) :: {boolean | halt, conn, state}
  def resource_exists(conn, state), do: {true, conn, state}

  @doc """
  If this returns anything other than `true`, the response will be
  `401 Unauthorized`. The return value will be used as the value in
  the `WWW-Authenticate` header, for example `Basic
  realm="Webmachine"`.

  Default: `true`
  """
  @doc group: :handler
  @spec is_authorized(conn, state) :: {boolean | halt, conn, state}
  def is_authorized(conn, state), do: {true, conn, state}

  @doc """
  Returning true will result in 403 Forbidden.

  Default: `false`
  """
  @doc group: :handler
  @spec forbidden(conn, state) :: {boolean | halt, conn, state}
  def forbidden(conn, state), do: {false, conn, state}

  @doc """
  If the resource accepts POST requests to nonexistent resources, then this should return `true`.

  Default: `false`
  """
  @doc group: :handler
  @spec allow_missing_post(conn, state) :: {boolean | halt, conn, state}
  def allow_missing_post(conn, state), do: {false, conn, state}

  @doc """
  Returning true will result in 400 Bad Request.

  Default: `false`
  """
  @doc group: :handler
  @spec malformed_request(conn, state) :: {boolean | halt, conn, state}
  def malformed_request(conn, state), do: {false, conn, state}

  @doc """
  Returning true will result in 414 Request-URI Too Long.

  Default: `false`
  """
  @doc group: :handler
  @spec uri_too_long(conn, state) :: {boolean | halt, conn, state}
  def uri_too_long(conn, state), do: {false, conn, state}

  @doc """
  Returning false will result in 415 Unsupported Media Type.

  Default: `true`
  """
  @doc group: :handler
  @spec known_content_type(conn, state) :: {boolean | halt, conn, state}
  def known_content_type(conn, state), do: {true, conn, state}

  @doc """
  Returning false will result in 501 Not Implemented.

  Default: `true`
  """
  @doc group: :handler
  @spec valid_content_headers(conn, state) :: {boolean | halt, conn, state}
  def valid_content_headers(conn, state), do: {true, conn, state}

  @doc """
  Returning false will result in 413 Request Entity Too Large.

  Default: `false`
  """
  @doc group: :handler
  @spec valid_entity_length(conn, state) :: {boolean | halt, conn, state}
  def valid_entity_length(conn, state), do: {true, conn, state}

  @doc """
  If the OPTIONS method is supported and is used, the return value of
  this function is expected to be a list of pairs representing header
  names and values that should appear in the response.
  """
  @doc group: :handler
  @spec options(conn, state) :: {[{String.t(), String.t()}] | halt, conn, state}
  def options(conn, state), do: {[], conn, state}

  @doc """
  If a Method not in this list is requested, then a 405 Method Not
  Allowed will be sent. Note that these are all-caps Strings (binary).

  Default: `["GET", "HEAD"]`
  """
  @doc group: :handler
  @spec allowed_methods(conn, state) :: {[String.t()] | halt, conn, state}
  def allowed_methods(conn, state), do: {["GET", "HEAD"], conn, state}

  @doc """
  Override the known methods accepted by your automate

  Default: `["GET", "HEAD", "POST", "PUT", "DELETE", "TRACE", "CONNECT", "OPTIONS"]`
  """
  @doc group: :handler
  @spec known_methods(conn, state) :: {[String.t()] | halt, conn, state}
  def known_methods(conn, state) do
    {["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "TRACE", "CONNECT", "OPTIONS"], conn,
     state}
  end

  @doc """
  This should return a `{key, value}` tuple enumerable where the key is the
  content-type format and the value is an atom naming the function which can
  provide a resource representation in that media type. Content negotiation is
  driven by this return value. For example, if a client request includes an
  `Accept` header with a value that does not appear as a first element in any
  of the return tuples, then a 406 Not Acceptable will be sent.

  Default: `[{"text/html", to_html}]`
  """
  @doc group: :handler
  @spec content_types_provided(conn, state) ::
          {[{String.Chars.t(), atom}] | Enum.t() | halt, conn, state}
  def content_types_provided(conn, state), do: {[{"text/html", :to_html}], conn, state}

  @doc """
  This is used similarly to `content_types_provided/2`, except that it is
  for incoming resource representations. For instance, `PUT` requests.

  Default: `[]`
  """
  @doc group: :handler
  @spec content_types_accepted(conn, state) ::
          {[{String.Chars.t(), atom}] | Enum.t() | halt, conn, state}
  def content_types_accepted(conn, state), do: {[], conn, state}

  @doc """
  This is called when a DELETE request should be enacted, and should
  return `true` if the deletion succeeded.
  """
  @doc group: :handler
  @spec delete_resource(conn, state) :: {boolean | halt, conn, state}
  def delete_resource(conn, state), do: {false, conn, state}

  @doc """
  This is only called after a successful `delete_resource/2` call, and
  should return `false` if the deletion was accepted but cannot yet be
  guaranteed to have finished.
  """
  @doc group: :handler
  @spec delete_completed(conn, state) :: {boolean | halt, conn, state}
  def delete_completed(conn, state), do: {true, conn, state}

  @doc """
  If POST requests should be treated as a request to put content into
  a (potentially new) resource as opposed to being a generic
  submission for processing, then this function should return `true`.
  If it does return `true`, then `create_path/2` will be called and the
  rest of the request will be treated much like a PUT to the Path
  entry returned by that call.

  Default: `false`
  """
  @doc group: :handler
  @spec post_is_create(conn, state) :: {boolean | halt, conn, state}
  def post_is_create(conn, state), do: {false, conn, state}

  @doc """
  This will be called on a POST request if `post_is_create/2` returns
  `true`. It is an error for this function not to produce a Path if
  `post_is_create/2` returns `true`. The Path returned should be a valid
  URI part.
  """
  @doc group: :handler
  @spec create_path(conn, state) :: {nil | String.t() | halt, conn, state}
  def create_path(conn, state), do: {nil, conn, state}

  @doc """
  The base URI used in the location header on resource creation (when
  `post_is_create/2` is `true`), will be prepended to the `create_path/2`
  """
  @doc group: :handler
  @spec base_uri(conn, state) :: {String.t() | halt, conn, state}
  def base_uri(conn, state),
    do: {"#{conn.scheme}://#{conn.host}#{port_suffix(conn.scheme, conn.port)}", conn, state}

  defp port_suffix(:http, 80), do: ""
  defp port_suffix(:https, 443), do: ""
  defp port_suffix(_, port), do: ":#{port}"

  @doc """
  If `post_is_create/2` returns `false`, then this will be called to
  process any POST requests. If it succeeds, it should return `true`.
  """
  @doc group: :handler
  @spec process_post(conn, state) :: {boolean | halt, conn, state}
  def process_post(conn, state), do: {false, conn, state}

  @doc """
  return false if language in
  `Plug.Conn.get_resp_header(conn,"accept-language")` is not
  available.
  """
  @doc group: :handler
  @spec language_available(conn, state) :: {boolean | halt, conn, state}
  def language_available(conn, state), do: {true, conn, state}

  @doc """
  If this is anything other than the atom `:no_charset`, it must be a
  `{key,value}` Enumerable where `key` is the charset and `value` is a
  callable function in the resource which will be called on the
  produced body in a GET and ensure that it is in Charset.

  Default: `:no_charset`
  """
  @doc group: :handler
  @spec charsets_provided(conn, state) ::
          {:no_charset | [{String.Chars.t(), (binary -> binary)}] | Enum.t() | halt, conn, state}
  def charsets_provided(conn, state), do: {:no_charset, conn, state}
  ## this atom causes charset-negotation to short-circuit
  ## the default setting is needed for non-charset responses such as image/png
  ##    an example of how one might do actual negotiation
  ##    [{"iso-8859-1", fun(X) -> X end}, {"utf-8", make_utf8}];

  @doc """
  This must be a `{key, value}` Enumerable where `key` is a valid
  content encoding and `value` is a callable function in the resource
  which will be called on the produced body in a GET and ensure that
  it is so encoded. One useful setting is to have the function check
  on method, and on GET requests return:

  ```elixir
  [identity: &(&1), gzip: &:zlib.gzip/1]
  ```
   as this is all that is needed to support gzip content encoding.

   Default: `[{"identity", fn X-> X end}]`
  """
  @doc group: :handler
  @spec encodings_provided(conn, state) ::
          {[{String.Chars.t(), (binary -> binary)}] | Enum.t() | halt, conn, state}
  def encodings_provided(conn, state), do: {[{"identity", & &1}], conn, state}
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
  @doc group: :handler
  @spec variances(conn, state) :: {[String.t()] | halt, conn, state}
  def variances(conn, state), do: {[], conn, state}

  @doc """
  If this returns `true`, the client will receive a 409 Conflict.

  Default : `false`
  """
  @doc group: :handler
  @spec is_conflict(conn, state) :: {boolean | halt, conn, state}
  def is_conflict(conn, state), do: {false, conn, state}

  @doc """
  If this returns `true`, then it is assumed that multiple
  representations of the response are possible and a single one
  cannot be automatically chosen, so a `300 Multiple Choices` will be
  sent instead of a `200 OK`.

  Default: `false`
  """
  @doc group: :handler
  @spec multiple_choices(conn, state) :: {boolean | halt, conn, state}
  def multiple_choices(conn, state), do: {false, conn, state}

  @doc """
  If this returns `true`, the `moved_permanently/2` and `moved_temporarily/2`
  callbacks will be invoked to determine whether the response should
  be `301 Moved Permanently`, `307 Temporary Redirect`, or `410 Gone`.

  Default: `false`
  """
  @doc group: :handler
  @spec previously_existed(conn, state) :: {boolean | halt, conn, state}
  def previously_existed(conn, state), do: {false, conn, state}

  @doc """
  If this returns `{true, uri}`, the client will receive a `301 Moved
  Permanently` with `uri` in the Location header.

  Default: `false`
  """
  @doc group: :handler
  @spec moved_permanently(conn, state) :: {boolean | halt, conn, state}
  def moved_permanently(conn, state), do: {false, conn, state}

  @doc """
  If this returns `{true, uri}`, the client will receive a `307
  Temporary Redirect` with `uri` in the Location header.

  Default: `false`
  """
  @doc group: :handler
  @spec moved_temporarily(conn, state) :: {boolean | halt, conn, state}
  def moved_temporarily(conn, state), do: {false, conn, state}

  @doc """
  If this returns a `datetime()` (`{{day,month,year},{h,m,s}}`, it
  will be used for the `Last-Modified` header and for comparison in
  conditional requests.

  Default: `nil`
  """
  @doc group: :handler
  @spec last_modified(conn, state) ::
          {nil
           | {{day :: integer, month :: integer, year :: integer},
              {hour :: integer, min :: integer, sec :: integer}}
           | halt, conn, state}
  def last_modified(conn, state), do: {nil, conn, state}

  @doc """
  If not `nil`, set the expires header

  Default: `nil`
  """
  @doc group: :handler
  @spec expires(conn, state) ::
          {nil
           | {{day :: integer, month :: integer, year :: integer},
              {hour :: integer, min :: integer, sec :: integer}}
           | halt, conn, state}
  def expires(conn, state), do: {nil, conn, state}

  @doc """
  If not `nil`, it will be used for the ETag header and
  for comparison in conditional requests.

  Default: `nil`
  """
  @doc group: :handler
  @spec generate_etag(conn, state) :: {nil | binary | halt, conn, state}
  def generate_etag(conn, state), do: {nil, conn, state}

  @doc """
  if `content-md5` header exists:
  - If `:not_validated`, test if input body validate `content-md5`,
  - if return `false`, then return a bad request

  Useful if content-md5 validation does not imply only raw md5 hash
  """
  @doc group: :handler
  @spec validate_content_checksum(conn, state) :: {:not_validated | boolean | halt, conn, state}
  def validate_content_checksum(conn, state), do: {:not_validated, conn, state}

  if Mix.env() == :test do
    @doc false
    @spec ping(conn, state) :: {:pang | :pong, conn, state}
    def ping(conn, state), do: {:pang, conn, state}
  end

  @doc """
  Last handler, always called. Response is ignored except if it is a `halt`.
  """
  @doc group: :handler
  @spec finish_request(conn, state) :: {any | halt, conn, state}
  def finish_request(conn, state), do: {false, conn, state}

  @doc """
  Example body-producing function, function atom name must be referenced in `content_types_provided/2`.

  - If the result is an `Enumerable` of `iodata`, then the HTTP response will be
    a chunk encoding response where each chunk on element of the enumeration.
  - If the result is an iodata, then it is used as the HTTP response body
  """
  @spec to_html(conn, state) :: {iodata | Enum.t() | halt, conn, state}
  def to_html(conn, state), do: {"<html><body><h1>Hello World</h1></body></html>", conn, state}

  @doc """
  Example POST/PUT processing function, function atom name must be referenced
  in `content_types_accepted/2`.

  It will be called when the request is `PUT` or when the
  request is `POST` and `post_is_create/2` returns true.
  """
  @spec from_json(conn, state) :: {true | halt, conn, state}
  def from_json(conn, state), do: {true, conn, state}
end
