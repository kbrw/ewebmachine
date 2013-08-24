defmodule DefaultRoute do
  use Ewebmachine

  resource [] do
    to_html do: "<h1>EWebMachine works !!</h1>"
  end
end
