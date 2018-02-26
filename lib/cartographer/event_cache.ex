defmodule Cartographer.EventCache do
  import ShortMaps
  require Logger
  use Agent

  def start_link do
    Agent.start_link(
      fn ->
        queue_update()
        []
      end,
      name: __MODULE__
    )
  end

  def queue_update do
    spawn(fn ->
      update()
    end)
  end

  def update do
    all_events = Cartographer.FetchEvents.all()
    Agent.update(__MODULE__, fn _ -> all_events end)
    Logger.info("Updated event cache at #{Timex.now() |> DateTime.to_iso8601()}")
    all_events
  end

  def all do
    Agent.get(__MODULE__, & &1)
  end

  def for(candidate) do
    all()
    |> Enum.filter(fn ev -> is_for_candidate(ev, candidate) end)
  end

  def is_for_candidate(~m(tags), candidate) when is_list(tags) do
    tags
    |> Enum.filter(&String.contains?(&1, "Calendar: "))
    |> Enum.map(&(String.split(&1, ":") |> List.last() |> String.trim()))
    |> Enum.map(&(String.replace(&1, " ", "-") |> String.downcase()))
    |> Enum.member?(candidate)
  end

  def is_for_candidate(_, _) do
    false
  end
end
