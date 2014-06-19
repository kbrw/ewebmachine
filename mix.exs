defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "0.0.2",
      elixirc_paths: ["lib","demo"],
      deps: [{:webmachine, git: "git://github.com/basho/webmachine.git", tag: "1.10.6"}] ]
  end

  def application do
    [ applications: [:webmachine],
      env: [] ]
  end

end
