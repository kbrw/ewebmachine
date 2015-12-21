defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "2.0.11",
      docs: [
        main: "Ewebmachine",
        source_url: "https://github.com/awetzel/ewebmachine",
        source_ref: "master"
      ],
      deps: [
        {:plug, "~> 1.0"},
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
                maintainers: ["Arnaud Wetzel", "Yurii Rashkovskii"],
                licenses: ["MIT"],
                files: ["lib", "priv", "mix.exs", "README*", "templates", "LICENSE*"]]]
  end

  def application do
    [ applications: [:plug],
      mod: {Ewebmachine.App,[]},
      env: [] ]
  end

end
