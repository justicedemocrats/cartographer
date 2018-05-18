defmodule Cartographer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cartographer,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Cartographer, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_), do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0-rc"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:actionkit, git: "https://github.com/justicedemocrats/actionkit_ex.git"},
      {:httpotion, "~> 3.1.0"},
      {:tesla, "~> 0.10.0"},
      {:cosmic, git: "https://github.com/justicedemocrats/cosmic_ex.git"},
      {:quantum, ">= 2.2.2"},
      {:timex, "~> 3.0"},
      {:distillery, "~> 1.0.0"},
      {:ex_json_schema, "~> 0.5.4"},
      {:airtable_config, git: "https://github.com/justicedemocrats/airtable_config.git"},
      {:html_sanitize_ex, "~> 1.3.0-rc3"},
      {:maps, git: "https://github.com/justicedemocrats/maps_ex.git"},
      {:geo, "~> 1.5"},
      {:topo, "~> 0.1.0"},
      {:stash, "~> 1.0.0"},
      {:cors_plug, "~> 1.5"}
    ]
  end
end
