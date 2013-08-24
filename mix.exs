defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "0.0.1",
      deps: [{:webmachine,"1.10.2",git: "git://github.com/basho/webmachine.git"}] ]
  end

  def application do
    [ mod: { Ewebmachine.App,[] },
      applications: [:webmachine],
      env: [] ]
  end

end
