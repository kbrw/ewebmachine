defmodule Ewebmachine.App do
  @moduledoc false 
  use Application
  import Supervisor.Spec
  def start(_,_) do
    Supervisor.start_link([
      worker(Ewebmachine.Log,[]),
      worker(GenEvent,[[name: Ewebmachine.Events]])
    ], strategy: :one_for_one)
  end
end
