defmodule Jobs.SyncEvents do
  import ShortMaps
  import AkClient
  require Logger

  @initial_sync false

  @do_delete not @initial_sync
  @send_email not @initial_sync

  def sync_all do
    Cartographer.Airtable.get_all()
    |> Map.keys()
    |> Enum.map(&try_sync_candidate/1)
  end

  def try_sync_candidate(candidate) do
    try do
      sync_candidate(candidate)
    rescue
      _ -> Logger.error("Could not sync #{candidate}")
    end
  end

  def sync_candidate(candidate, schema \\ nil) do
    ~m(
      endpoint osdi_api_token json_schema_filter reference_name
      candidate_events_url point_of_contact sync_rsvps
    ) = Cartographer.Airtable.get_all()[candidate]

    external_client = OsdiClient.build_client(endpoint, osdi_api_token)

    # Save the synced output so we can delete from ours
    their_events_synced =
      OsdiClient.stream(external_client, "events")
      |> Stream.filter(&is_in_future/1)
      |> Stream.filter(fn ~m(status) -> status == "confirmed" end)
      |> Stream.filter(fn ev -> keys_not_nil(ev, [~w(location postal_code)]) end)
      |> Stream.filter(filter_by(schema || json_schema_filter))
      |> Stream.map(fn ev -> add_source_tags(ev, reference_name) end)
      |> Stream.map(&remove_html/1)
      |> Stream.map(&try_update_or_add/1)
      |> Stream.reject(fn result -> match?({:error, _}, result) end)
      |> Stream.map(fn notice -> notify(notice, candidate_events_url, point_of_contact) end)
      |> Enum.to_list()

    if sync_rsvps do
      spawn(fn ->
        Enum.map(their_events_synced, &set_suppress_confirmation/1)
      end)
    end

    Logger.info("Synced #{length(their_events_synced)} events")

    # Delete events in actionkit without a corresponding event in external system for candidate
    if @do_delete do
      deleted =
        OsdiClient.stream(ak_client(), "events")
        |> Stream.filter(&is_in_future/1)
        |> Stream.filter(fn ~m(status) -> status == "confirmed" end)
        |> Stream.filter(fn ev -> is_for_candidate(ev, reference_name) end)
        |> Stream.filter(fn ev -> should_delete(ev, their_events_synced) end)
        |> Stream.map(&delete_event/1)
        |> Stream.map(fn notice -> notify(notice, candidate_events_url, point_of_contact) end)
        |> Enum.to_list()

      Logger.info("Deleting #{length(deleted)} events")
    end
  end

  def is_in_future(~m(start_date)) do
    case DateTime.from_iso8601(start_date) do
      {:ok, dt, _} -> Timex.now() |> Timex.shift(days: -1) |> Timex.before?(dt)
      _ -> false
    end
  end

  def is_for_candidate(~m(tags), candidate) do
    Enum.filter(tags, fn t -> String.contains?(t, candidate) end)
    |> length()
    |> (&(&1 > 0)).()
  end

  def should_delete(event, external_event_list) do
    external_id_list =
      Enum.map(external_event_list, fn ~m(identifiers) ->
        Enum.filter(identifiers, &(not String.contains?(&1, "actionkit"))) |> List.first()
      end)

    external_id =
      event["identifiers"]
      |> Enum.filter(&(not String.contains?(&1, "actionkit")))
      |> List.first()

    cond do
      # If it doesn't have an external id, it must come from a form (not sync)
      external_id == nil ->
        false

      # If it's still there, don't delete it
      Enum.member?(external_id_list, external_id) ->
        false

      true ->
        true
    end
  end

  def delete_event(event = ~m(id)) do
    case OsdiClient.put(ak_client(), "events/#{id}", %{
           "status" => "cancelled",
           "tags" => ["Sync: Cancelled" | tags_for(event)]
         }) do
      %{status: 200} ->
        {:deleted, event}

      _else ->
        {:could_not_delete, event}
    end
  end

  def filter_by(schema) do
    fn ev ->
      case schema |> Poison.decode!() |> ExJsonSchema.Validator.validate(ev) do
        :ok ->
          true

        {:error, msg_list} ->
          Logger.info("Will not sync #{inspect(ev["identifiers"])}: #{inspect(msg_list)}")
          false
      end
    end
  end

  def add_source_tags(event, reference_name) do
    %{"metadata" => ~m(local_chapter_leader_list)} = Cosmic.get("jd-esm-config")
    local_leader_emails = String.split(local_chapter_leader_list, "\n")
    email = get_in(event, ~w(contact email_address))

    extra =
      if Enum.member?(local_leader_emails, email) do
        ["Calendar: Local Chapter"]
      else
        []
      end

    tags = Enum.concat([tags_for(event), ["Calendar: #{reference_name}", "Source: Sync"], extra])
    Map.put(event, "tags", tags)
  end

  def remove_html(event) do
    ~w(description instructions)
    |> Enum.reduce(event, fn key, acc ->
      Map.update(acc, key, "", &HtmlSanitizeEx.strip_tags/1)
    end)
  end

  def keys_not_nil(map, keys_list) do
    keys_list
    |> Enum.map(fn keys -> get_in(map, keys) end)
    |> Enum.map(fn val -> val != nil end)
    |> Enum.all?()
  end

  def try_update_or_add(event) do
    try do
      update_or_add(event)
    rescue
      _e -> {:error, event}
    end
  end

  def update_or_add(event) do
    {status, event} =
      case find_id_of_event_with_external_id(event) do
        nil ->
          {:created, create_event(event)}

        id ->
          {:updated, update_event(id, event)}
      end

    {status, event}
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
    # We only want to sync events marked as cancelled that have the tag "Sync: Cancelled"
    case OsdiClient.get(ak_client(), "events/#{id}").body do
      %{"status" => "cancelled", "id" => id, "tags" => tags} ->
        if Enum.member?(tags, "Sync: Cancelled") do
          OsdiClient.put(ak_client(), "events/#{id}", event)
        else
          Logger.info("Will not resync #{inspect(event["identifiers"])}")
        end

      _ ->
        OsdiClient.put(ak_client(), "events/#{id}", event)
    end

    OsdiClient.get(ak_client(), "events/#{id}").body
  end

  def create_event(event) do
    case OsdiClient.post(ak_client(), "events", event) do
      %{status: 200, body: body} -> body
      _ -> raise("Error")
    end
  end

  def notify({:created, event}, candidate_events_url, point_of_contact) do
    transformed =
      event
      |> Map.put("candidate_events_url", candidate_events_url)
      |> Map.put("point_of_contact", point_of_contact)
      |> Cartographer.FetchEvents.add_date_line()

    if @send_email do
      Application.get_env(:cartographer, :event_synced_webhook)
      |> HTTPotion.post(body: Poison.encode!(transformed))
    end

    Logger.info("Created event #{event["id"]}")
    event
  end

  def notify({:updated, event}, _candidate_events_url, _point_of_contact) do
    Logger.info("Event #{event["id"]} was updated. No webhook sent.")
    event
  end

  def notify({:deleted, event}, _candidate_events_url, _point_of_contact) do
    Application.get_env(:cartographer, :event_deleted_webhook)
    |> HTTPotion.post(body: Poison.encode!(event))

    event
  end

  def notify({:error, event}, _candidate_events_url, _point_of_contact) do
    Logger.error("Could not sync event: #{inspect(event)}")
  end

  def notify({:could_not_delete, event}) do
    Logger.info("Could not delete #{inspect(event)}")
    event
  end

  def tags_for(event) do
    event["tags"] || []
  end

  def set_suppress_confirmation(~m(id)) do
    found =
      Ak.Api.stream(
        "eventfield",
        query: %{
          "name" => "no_confirmation",
          "event" => id
        }
      )
      |> Enum.to_list()
      |> List.first()

    case found do
      %{} ->
        :ok

      nil ->
        Ak.Api.post(
          "eventfield",
          body: %{
            "name" => "no_confirmation",
            "event" => id,
            "value" => 1
          }
        )

        :ok
    end
  end
end
