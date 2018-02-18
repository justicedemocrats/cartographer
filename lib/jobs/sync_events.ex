defmodule Jobs.SyncEvents do
  import ShortMaps
  require Logger

  def sync_all do
  end

  def sync_candidate(candidate, schema \\ nil) do
    ~m(endpoint osdi_api_token json_schema_filter) = Cartographer.Airtable.get_all()[candidate]

    client = OsdiClient.build_client(endpoint, osdi_api_token)

    all_events =
      OsdiClient.stream(client, "events")
      |> Enum.to_list()
      |> Enum.filter(fn ev -> keys_not_nil(ev, [~w(location postal_code)]) end)
      |> IO.inspect()
      |> Enum.filter(filter_by(schema || json_schema_filter))
      |> Enum.to_list()
      |> IO.inspect()

    # |> Enum.map(&update_or_add/1)
    # |> Stream.run()
  end

  def filter_by(schema) do
    fn ev ->
      case schema |> Poison.decode!() |> ExJsonSchema.Validator.validate(ev) do
        :ok ->
          Logger.info("passed!")
          true

        {:error, msg_list} ->
          Logger.info("Will not sync #{inspect(ev["identifiers"])}: #{inspect(msg_list)}")
          false
      end
    end
  end

  def keys_not_nil(map, keys_list) do
    keys_list
    |> Enum.map(fn keys -> get_in(map, keys) end)
    |> Enum.map(fn val -> val != nil end)
    |> Enum.all?()
  end

  def update_or_add(event) do
    case find_id_of_event_with_external_id(event) do
      nil -> create_event(event)
      id -> update_event(id, event)
    end
  end

  def find_id_of_event_with_external_id(~m(identifiers)) do
    field_match =
      Ak.Api.stream(
        "eventfield",
        query: %{
          "name" => "identifiers",
          "value__contains" => List.first(identifiers)
        }
      )
      |> Enum.take(1)
      |> List.first()

    case field_match do
      %{"event" => "/rest/v1/event/" <> event_id} ->
        String.split(event_id, "/") |> List.first()

      nil ->
        nil
    end
  end

  def update_event(id, event) do
    AkProxy.put("events/#{id}", body: event)
  end

  def create_event(event) do
    AkProxy.post("events", body: event)
  end
end
