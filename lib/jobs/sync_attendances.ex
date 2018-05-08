defmodule Jobs.SyncAttendances do
  import AkClient
  import ShortMaps
  require Logger
  @default_timeframe [hours: -2]
  @batch_size 10

  def sync_attendances_within(timeframe \\ @default_timeframe) do
    config = Cartographer.Airtable.get_all()
    Logger.info("Fetching events...")
    event_map = get_event_map()
    Logger.info("...fetched events. Fetching attendances...")

    count =
      attendances_since_timeframe(timeframe)
      |> Stream.map(fn a -> should_sync(a, event_map, config) end)
      |> Stream.reject(fn result -> result == false end)
      |> Stream.chunk_every(@batch_size)
      |> Stream.map(fn chunk ->
        chunk
        |> Enum.map(&Task.async(fn -> sync_attendance(&1, event_map, config) end))
        |> Enum.map(&Task.await(&1, 30_000))
      end)
      |> Enum.to_list()
      |> length()

    Logger.info("Synced #{count} rsvps")
  end

  def attendances_since_timeframe(timeframe) do
    order_by = "-created_at"
    before = Timex.shift(Timex.now(), timeframe)

    Ak.Api.stream("eventsignup", query: ~m(order_by))
    |> Enum.take_while(fn ~m(created_at) ->
      {_, created_dt, _} = DateTime.from_iso8601(created_at <> "Z")
      Timex.after?(created_dt, before)
    end)
  end

  def should_sync(signup, events, config) do
    event_id = Map.get(signup, "event") |> String.trim("/") |> String.split("/") |> List.last()
    user_id = Map.get(signup, "user") |> String.trim("/") |> String.split("/") |> List.last()

    case Map.get(events, event_id, nil) do
      nil ->
        false

      event ->
        case Enum.filter(event["tags"], &String.contains?(&1, "Sync")) do
          [] ->
            false

          [_sync_tag] ->
            candidate =
              Enum.filter(event["tags"], &String.starts_with?(&1, "Calendar"))
              |> Enum.map(&String.trim/1)
              |> Enum.filter(
                &(not String.starts_with?(&1, "Justice Democrats") and
                    not String.starts_with?(&1, "Brand New Congress"))
              )
              |> List.first()

            case candidate do
              nil ->
                false

              name_style ->
                candidate =
                  String.split(name_style, ":")
                  |> List.last()
                  |> String.trim()
                  |> String.downcase()
                  |> String.replace(" ", "-")

                case get_in(config, [candidate, "sync_rsvps"]) do
                  true -> ~m(candidate event_id user_id)
                  false -> false
                  nil -> false
                end
            end

          _ ->
            false
        end
    end
  end

  def get_event_map do
    OsdiClient.stream(ak_client(), "events")
    |> Enum.reduce(%{}, fn ev, acc ->
      Map.put(acc, "#{ev["id"]}", ev)
    end)
  end

  def sync_attendance(~m(event_id user_id candidate), events, config) do
    external_id =
      get_in(events, [event_id, "identifiers"])
      |> Enum.filter(&(not String.starts_with?(&1, "actionkit")))
      |> List.first()
      |> String.split(":")
      |> List.last()

    %{body: user} = Ak.Api.get("user/#{user_id}")

    phone_numbers =
      case user["phones"]
           |> List.first() do
        nil ->
          []

        phone_uri ->
          phone_id =
            phone_uri
            |> String.trim("/")
            |> String.split("/")
            |> List.last()

          %{body: phone} = Ak.Api.get("phone/#{phone_id}")
          [%{"number" => phone["normalized_phone"]}]
      end

    ~m(endpoint osdi_api_token) = Cartographer.Airtable.get_all()[candidate]
    external_client = OsdiClient.build_client(endpoint, osdi_api_token)

    %{body: body} = OsdiClient.get(external_client, "events/#{external_id}")
    attendance_helper_url = get_in(body, ["_links", "osdi:record_attendance_helper", "href"])

    attendance_helper_suffix =
      String.replace(attendance_helper_url, endpoint, "") |> String.trim("/")

    OsdiClient.post(external_client, attendance_helper_suffix, %{
      "person" => %{
        "given_name" => user["first_name"],
        "family_name" => user["last_name"],
        "email_addresses" => [
          %{
            "address" => user["email"]
          }
        ],
        "phone_numbers" => phone_numbers
      }
    })
  end
end
