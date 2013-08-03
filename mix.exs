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
      env: [ip: '0.0.0.0',
            port: 7171,
            routes: [MyApp1]] ]
  end

end
