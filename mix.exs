defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "0.0.2",
      deps: [{:webmachine,">= 1.10",git: "git://github.com/basho/webmachine.git", branch: "1.10"}] ]
  end

  def application do
    [ mod: { Ewebmachine.App,[] },
      applications: [:webmachine],
      env: [
        ip: '0.0.0.0',
        port: '9001',
        log_dir: 'priv/log',
        modules: [DefaultRoute]
      ] ]
  end

end
