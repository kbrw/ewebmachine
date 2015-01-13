defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "1.0.0",
      deps: [
        {:plug, []},
        {:cowboy, "~> 1.0", optional: true}
      ],

      description: """
        Ewebmachine is a very simple Elixir DSL around Webmachine
        from basho :
        https://github.com/basho/webmachine
        You need to read webmachine wiki, then to read the README to
        understand the simple wrapper rules.
      """,
      package: [links: %{"Source"=>"http://github.com/awetzel/ewebmachine"},
                contributors: ["Arnaud Wetzel"],
                licenses: ["MIT"]] ]
  end

  def application do
    [ applications: [:plug],
      env: [] ]
  end

end
