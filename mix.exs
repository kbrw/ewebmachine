defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "2.0.0",
      docs: [
        main: "Ewebmachine",
        source_url: "https://github.com/awetzel/ewebmachine",
        source_ref: "master"
      ],
      deps: [
        {:plug, []},
        {:cowboy, "~> 1.0", optional: true},
        {:ex_doc, only: :dev}
      ],

      description: """
        Ewebmachine contains macros and plugs to allow you to compose
        HTTP decision handlers and run the HTTP decision tree to get
        your HTTP response. This project is a rewrite for Elixir and
        Plug of basho webmachine.
      """,
      package: [links: %{"Source"=>"http://github.com/awetzel/ewebmachine",
                         "Doc"=>"http://hexdocs.pm/ewebmachine"},
                contributors: ["Arnaud Wetzel"],
                licenses: ["MIT"]] ]
  end

  def application do
    [ applications: [:plug],
      mod: {Ewebmachine.App,[]},
      env: [] ]
  end

end
