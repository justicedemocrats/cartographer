defmodule Cartographer do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children =
      Enum.concat(
        [
          # Start the endpoint when the application starts
          supervisor(Cartographer.Endpoint, []),
          supervisor(Phoenix.PubSub.PG2, [:cartographer, []]),
          worker(Cartographer.EventCache, []),
          worker(Cosmic, [[application: :cartographer]])
        ],
        if Application.get_env(:cartographer, :airtable_key) == nil do
          []
        else
          [worker(Cartographer.Scheduler, []), worker(Cartographer.Airtable, [])]
        end
      )

    opts = [strategy: :one_for_one, name: Cartographer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Cartographer.Endpoint.config_change(changed, removed)
    :ok
  end
end
