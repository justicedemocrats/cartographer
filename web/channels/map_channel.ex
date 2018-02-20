defmodule Cartographer.MapChannel do
  use Cartographer.Web, :channel
  import ShortMaps
  alias Cartographer.EventCache

  def join("events", _message, socket) do
    {:ok, socket}
  end

  def handle_in("events", ~m(candidate), socket) do
    EventCache.for(candidate)
    |> Enum.each(fn event -> push(socket, "event", event) end)

    push(socket, "done", %{})

    {:noreply, socket}
  end

  def handle_in("events", _message, socket) do
    EventCache.all()
    |> Enum.each(fn event -> push(socket, "event", event) end)

    push(socket, "done", %{})

    {:noreply, socket}
  end
end
