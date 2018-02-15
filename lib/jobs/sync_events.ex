defmodule Jobs.SyncEvents do
  import ShortMaps
  require Logger

  def sync_all do
  end

  def sync_candidate(candidate, schema \\ nil) do
    ~m(endpoint osdi_api_token json_schema_filter) = Cartographer.Airtable.get_all()[candidate]

    client = OsdiProxy.build_client(endpoint, osdi_api_token)

    OsdiProxy.stream(client, "events")
    |> Enum.take(3)
    |> Stream.filter(filter_by(schema || json_schema_filter))
    |> Stream.map(&update_or_add/1)
    |> Stream.run()
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

  def update_or_add(event) do
  end
end
