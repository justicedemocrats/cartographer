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
      |> Stream.map(&add_date_line/1)
      |> Enum.to_list()
    end
  end

  def is_not_in_past(e = %{"end_date" => end_date, "location" => ~m(time_zone)})
      when is_binary(end_date) and is_binary(time_zone) do
    end_dt = extract_end_date(e)
    Timex.now() |> Timex.shift(hours: 2) |> Timex.before?(end_dt)
  end

  def is_not_in_past(_e) do
    false
  end

  def extract_end_date(e) do
    ~m(offset_utc)a =
      get_in(e, ~w(location time_zone))
      |> Timex.Timezone.get()
      |> Map.take([:offset_utc])

    parse(e["end_date"], offset_utc)
  end

  def add_date_line(event) do
    date_line =
      humanize_date(event["start_date"]) <>
        "from " <>
        humanize_time(event["start_date"], get_in(event, ~w(location time_zone))) <>
        " - " <> humanize_time(event["end_date"], get_in(event, ~w(location time_zone)))

    Map.put(event, "date_line", date_line)
  end

  defp humanize_date(dt) do
    %DateTime{month: month, day: day} = parse(dt)

    month =
      [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
      ]
      |> Enum.at(month - 1)

    "#{month}, #{day} "
  end

  defp humanize_time(dt, tz) do
    zone = Timex.Timezone.get(tz)
    %DateTime{hour: hour, minute: minute} = parse(dt) |> Timex.Timezone.convert(zone)
    hour = if hour == 0, do: 12, else: hour
    minute = if minute == 0, do: "", else: ":#{minute}"
    {hour, am_pm} = if hour >= 12, do: {hour - 12, "PM"}, else: {hour, "AM"}
    hour = if hour == 0, do: 12, else: hour
    "#{hour}#{minute} " <> am_pm
  end

  defp humanize_time(dt) do
    %DateTime{hour: hour, minute: minute} = parse(dt)

    {hour, am_pm} = if hour >= 12, do: {hour - 12, "PM"}, else: {hour, "AM"}
    hour = if hour == 0, do: 12, else: hour
    minute = if minute == 0, do: "", else: ":#{minute}"

    "#{hour}#{minute} " <> am_pm
  end

  def set_browser_url(ev = %{name: name}), do: Map.put(ev, :browser_url, "/events/#{name}")

  def date_compare(%{"start_date" => d1}, %{"start_date" => d2}) do
    case DateTime.compare(d1, d2) do
      :gt -> false
      _ -> true
    end
  end

  def parse(dt, _offset \\ 0) do
    case DateTime.from_iso8601(dt) do
      {:ok, result, _} ->
        result

      _ ->
        case DateTime.from_iso8601(dt <> "Z") do
          {:ok, result, _} -> result
          _ -> Timex.now()
        end
    end
  end
end
