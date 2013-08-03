Code.require_file "test_helper.exs", __DIR__

defmodule EwebmachineTest do
  use ExUnit.Case

  test "http resource routing" do
    defmodule MyHTTP do
      use Ewebmachine
      resource ["hello",:name] do
      end
      resource [] do
        ini "tata"
        defp coucou, do: :true
        resource_exists do: coucou
      end
    end
    assert MyHTTP.routes == [{["hello",:name],EwebmachineTest.MyHTTP0,[]},{[],EwebmachineTest.MyHTTP1,[]}]
    assert EwebmachineTest.MyHTTP0.init([]) == {:ok,nil}
    assert EwebmachineTest.MyHTTP1.init([]) == {:ok,"tata"}
  end

  test "http resource functions" do
    defmodule MyHTTP2 do
      use Ewebmachine
      resource ["hello",:name] do
        resource_exists do
          {:true,_req,_ctx}
        end
      end
    end
    assert EwebmachineTest.MyHTTP20.resource_exists(:r,:c) == {:true,:r,:c}
  end
end
