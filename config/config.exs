# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :cartographer, Cartographer.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "YvhsFaTeHnJmyreNqJSXXX8CVv+npYjqvdQAjcmpOBoGE0dBkUzKQ5p+RaJf131/",
  render_errors: [view: Cartographer.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Cartographer.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :cosmic, slug: "brand-new-congress"

config :cartographer, Cartographer.Scheduler,
  jobs: [
    {"*/5 * * * *", {Jobs.ProcessNewEvents, :go, []}}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
