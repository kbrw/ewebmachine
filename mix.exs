defmodule Ewebmachine.Mixfile do
  use Mix.Project

  @description """
  Ewebmachine contains macros and plugs to allow you to compose
  HTTP decision handlers and run the HTTP decision tree to get
  your HTTP response. This project is a rewrite for Elixir and
  Plug of basho webmachine.
  """

  def project, do: [
    app: :ewebmachine,
    elixir: ">= 1.3.4",
    version: "2.2.0",
    docs: docs(),
    deps: deps(),
    description: @description,
    package: package()
  ]

  def application, do: [
    applications: [:plug],
    mod: { Ewebmachine.App, [] },
    env: []
  ]

  defp docs, do: [
    main: "Ewebmachine",
    source_url: "https://github.com/kbrw/ewebmachine",
    source_ref: "master"
  ]

  defp deps, do: [
    {:plug, ">= 1.0.0"},
    {:cowboy, ">= 1.0.0", optional: true},
    {:ex_doc, ">= 0.0.0", only: :dev},
    {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
  ]

  defp package, do: [
    links: %{ "Source" => "http://github.com/kbrw/ewebmachine",
              "Doc" => "http://hexdocs.pm/ewebmachine" },
    maintainers: ["Arnaud Wetzel", "Yurii Rashkovskii", "Jean Parpaillon"],
    licenses: ["MIT"],
    files: ["lib", "priv", "mix.exs", "README*", "templates", "LICENSE*", "CHANGELOG*", "examples"]
  ]
end
