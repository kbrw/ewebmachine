defmodule MyApp1 do
  use Ewebmachine
  
  resource [] do
    to_html do: "<html><body><h1>Hello World</h1></body></html>"
  end

  resource ['coucou'] do
    to_html do: {"<html><body><h1>Hello World</h1></body></html>",_req,_ctx}
  end

  resource ['caca'] do
    to_html do: {"<html><body><h1>Hello World</h1></body></html>",_req,_ctx}
  end

end
