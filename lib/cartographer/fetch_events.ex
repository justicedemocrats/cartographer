defmodule Cartographer.FetchEvents do
  import AkClient
  import ShortMaps

  def all do
    if Application.get_env(:cartographer, :osdi_base_url) == nil do
      %{body: events} = HTTPotion.get("https://map.justicedemocrats.com/api/events")
      Poison.decode!(events)
    else
      OsdiClient.stream(ak_client(), "events")
      |> Stream.filter(&(&1["status"] == "confirmed"))
      |> Stream.filter(&is_not_in_past/1)
      |> Enum.to_list()
    end
  end

  def is_not_in_past(e = %{"end_date" => end_date, "time_zone" => time_zone})
      when is_binary(end_date) and is_binary(time_zone) do
    end_dt = extract_end_date(e)
    Timex.now() |> Timex.shift(hours: 2) |> Timex.before?(end_dt)
  end

  def is_not_in_past(_) do
    false
  end

  def extract_end_date(e) do
    ~m(offset_utc)a = Timex.Timezone.get(e["time_zone"]) |> Map.take([:offset_utc])
    parse(e["end_date"], offset_utc)
  end

  def parse(dt, offset) do
    iso = if String.ends_with?(dt, "Z"), do: dt, else: dt <> "Z"
    {:ok, result, _} = DateTime.from_iso8601(iso)

    timestamp = Timex.to_unix(result)
    with_offset = timestamp - offset

    Timex.from_unix(with_offset)
  end
end
