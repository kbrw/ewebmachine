defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def version, do: "2.3.2"

  @description """
  Ewebmachine contains macros and plugs to allow you to compose
  HTTP decision handlers and run the HTTP decision tree to get
  your HTTP response. This project is a rewrite for Elixir and
  Plug of basho webmachine.
  """

  def project do
    [
      app: :ewebmachine,
      version: version(),
      elixir: ">= 1.13.4",
      docs: docs(),
      deps: deps(),
      description: @description,
      package: package(),
    ]
  end

  def application do
    [
      mod: { Ewebmachine.App, [] },
      extra_applications: [:inets],
      env: []
    ]
  end

  defp docs do
    [
      assets: "assets",
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "README.md": [title: "Overview"],
        "pages/demystify_dsl.md": [title: "Demystify Ewebmachine DSL"],
      ],
      main: "readme",
      source_url: git_repository(),
      # We need to git tag with the corresponding format.
      source_ref: "v#{version()}",
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.10"},
      {:plug_cowboy, "~> 2.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      links: %{
        "GitHub" => git_repository(),
        "Doc" => "http://hexdocs.pm/ewebmachine",
        "Changelog" => "https://hexdocs.pm/ewebmachine/changelog.html",
      },
      maintainers: ["Arnaud Wetzel", "Yurii Rashkovskii", "Jean Parpaillon"],
      licenses: ["MIT"],
      files: ["lib", "priv", "mix.exs", "README*", "templates", "LICENSE*", "CHANGELOG*", "examples"],
    ]
  end

  defp git_repository do
    "http://github.com/kbrw/ewebmachine"
  end
end
