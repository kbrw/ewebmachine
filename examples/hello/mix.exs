defmodule Hello.Mixfile do
  use Mix.Project

  def project do
    [app: :hello,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [
      applications: [:logger, :ewebmachine, :cowboy, :poison],
      mod: {Hello.App, []}
    ]
  end

  defp deps do
    [
      {:ewebmachine, path: "../.."},
      {:cowboy, ">= 1.0.4"},
      {:poison, "~> 3.0.0"}
    ]
  end
end
