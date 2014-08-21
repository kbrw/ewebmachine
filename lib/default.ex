defmodule DefaultRoute do
  use Ewebmachine

  resource [] do
    to_html do: "<h1>EWebMachine works !!</h1>"
  end

  defmodule App do
    use Application
    def start(_,_), do: 
      Ewebmachine.Sup.start_link(modules: [DefaultRoute], port: 6767)
  end
end
