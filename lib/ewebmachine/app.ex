defmodule Ewebmachine.App do
  @moduledoc false 
  use Application
  def start(_,_) do
    Supervisor.start_link([
      Ewebmachine.Log,
      Ewebmachine.Events
    ], strategy: :one_for_one)
  end
end
