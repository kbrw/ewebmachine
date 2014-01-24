defmodule Ewebmachine.Mixfile do
  use Mix.Project

  def project do
    [ app: :ewebmachine,
      version: "0.0.2",
      deps: [{:webmachine,">= 1.10",git: "git://github.com/basho/webmachine.git", tag: "1.10.5"}] ]
  end

  def application do
    [ applications: [:webmachine],
      env: [
        ip: '0.0.0.0',
        port: '9001',
        log_dir: 'priv/log',
        modules: [DefaultRoute]
      ] ]
  end

end
