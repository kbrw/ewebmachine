defmodule Ewebmachine do
  alias Plug.Conn

  def do_redirect(conn), do:
    Conn.put_private(conn, :resp_redirect, true)

  def send(conn) do
    if (stream=conn.private[:machine_body_stream]) do
      conn = Conn.send_chunked(conn,conn.status)
      Enum.each(stream,&Conn.chunk(conn,&1))
      conn
    else
      Conn.send_resp(conn)
    end
  end

  @doc """
  Returning non-true values will result in `503 Service Unavailable`.
  Default: `true`
  """
  def service_available(conn,state), do: {true,conn,state}

  @doc """
  Returning non-true values will result in `404 Not Found`.
  Default: `true`
  """
  def resource_exists(conn,state), do: {true,conn,state}

  @doc """
  If this returns anything other than `true`, the response will be `401
  Unauthorized`. The `string()` return value will be used as the value
  in the `WWW-Authenticate` header, for example `Basic realm="Webmachine"`.
  Default: `true`
  """
  def is_authorized(conn,state), do: {true,conn,state}

  @doc """
  Returning true will result in 403 Forbidden.
  Default: `false`
  """
  def forbidden(conn,state), do: {false,conn,state}

  @doc """
  If the resource accepts POST requests to nonexistent resources, then this should return `true`.
  Default: `false`
  """
  def allow_missing_post(conn,state), do: {false,conn,state}

  def malformed_request(conn,state), do:
    {false,conn,state}
  def uri_too_long(conn,state), do:
    {false,conn,state}
  def known_content_type(conn,state), do:
    {true,conn,state}
  def valid_content_headers(conn,state), do:
    {true,conn,state}
  def valid_entity_length(conn,state), do:
    {true,conn,state}
  def options(conn,state), do:
    {[],conn,state}
  def allowed_methods(conn,state), do:
    {["GET", "HEAD"],conn,state}
  def known_methods(conn,state), do:
    {["GET", "HEAD", "POST", "PUT", "DELETE", "TRACE", "CONNECT", "OPTIONS"],conn,state}
  def content_types_provided(conn,state), do:
    {[{"text/html", :to_html}],conn,state}
  def content_types_accepted(conn,state), do:
    {[],conn,state}
  def delete_resource(conn,state), do:
    {false,conn,state}
  def delete_completed(conn,state), do:
    {true,conn,state}
  def post_is_create(conn,state), do:
    {false,conn,state}
  def create_path(conn,state), do:
    {nil,conn,state}
  def base_uri(conn,state), do:
    {nil,conn,state}
  def process_post(conn,state), do:
    {false,conn,state}
  def language_available(conn,state), do:
    {true,conn,state}
  def charsets_provided(conn,state), do:
    {:no_charset,conn,state}
  ## this atom causes charset-negotation to short-circuit
  ## the default setting is needed for non-charset responses such as image/png
  ##    an example of how one might do actual negotiation
  ##    [{"iso-8859-1", fun(X) -> X end}, {"utf-8", make_utf8}];
  def encodings_provided(conn,state), do:
    {[{"identity", &(&1)}],conn,state}
  # this is handy for auto-gzip of GET-only resources:
  #    [{"identity", fun(X) -> X end}, {"gzip", fun(X) -> zlib:gzip(X) end}];
  def variances(conn,state), do:
    {[],conn,state}
  def is_conflict(conn,state), do:
    {false,conn,state}
  def multiple_choices(conn,state), do:
    {false,conn,state}
  def previously_existed(conn,state), do:
    {false,conn,state}
  def moved_permanently(conn,state), do:
    {false,conn,state}
  def moved_temporarily(conn,state), do:
    {false,conn,state}
  def last_modified(conn,state), do:
    {nil,conn,state}
  def expires(conn,state), do:
    {nil,conn,state}
  def generate_etag(conn,state), do:
    {nil,conn,state}
  def finish_request(conn,state), do:
    {true,conn,state}
  def validate_content_checksum(conn,state), do:
    {:not_validated,conn,state}
  def to_html(conn,state), do:
    {"",conn,state}
  def ping(conn,state), do:
    {:pang,conn,state}
end
