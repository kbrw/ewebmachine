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
    elixir: ">= 1.10.0",
    version: "2.3.0",
    docs: docs(),
    deps: deps(),
    description: @description,
    package: package()
  ]

  def application, do: [
    mod: { Ewebmachine.App, [] },
    extra_applications: [:inets],
    env: []
  ]

  defp docs, do: [
    main: "Ewebmachine",
    source_url: "https://github.com/kbrw/ewebmachine",
    source_ref: "master"
  ]

  defp deps, do: [
    {:plug, "~> 1.10"},
    {:plug_cowboy, "~> 2.4", optional: true},
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
