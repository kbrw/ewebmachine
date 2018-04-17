defmodule Ewebmachine.Plug.ErrorAsException do
  @moduledoc """
  This plug checks the current response status. If it is an error, raise a plug
  exception with the status code and the HTTP error name as the message. If
  this response body is not void, use it as the exception message.
  """
  defexception [:plug_status,:message]
  def init(_), do: []  
  def call(%{status: code, state: :set}=conn,_) when code > 399, do: raise(__MODULE__,conn)
  def call(conn,_), do: conn
  def exception(%{status: code,resp_body: msg}) when byte_size(msg)>0, do:
    %__MODULE__{plug_status: code, message: msg}
  def exception(%{status: code}), do:
    %__MODULE__{plug_status: code, message: Ewebmachine.Core.Utils.http_label(code)}
end
