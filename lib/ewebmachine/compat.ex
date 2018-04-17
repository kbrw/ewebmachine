defmodule Ewebmachine.Compat do
  @moduledoc false
end

defmodule Ewebmachine.Compat.Enum do
  @moduledoc false
  
  case Version.compare(System.version(), "1.4.0") do
    :gt ->
      defdelegate split_with(arg0, arg1), to: Enum
    _ ->
      defdelegate split_with(arg0, arg1), to: Enum, as: :partition
  end
end
