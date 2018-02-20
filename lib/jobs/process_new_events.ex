defmodule Jobs.ProcessNewEvents do
  import ShortMaps
  import AkClient
  require Logger

  @interval [minutes: -5]
  @turnout_survey_page 858

  def go do
    handle_new_events()
    handle_new_turnout_requests()
  end

  def handle_new_events do
    order_by = "-created_at"

    recent_events =
      Ak.Api.stream("event", query: ~m(order_by))
      |> Enum.take_while(&is_within_interval/1)

    Logger.info("Got #{length(recent_events)} events in past 5 minutes")

    recent_events
    |> Enum.map(&wrap_event/1)
    |> Enum.map(&pipeline/1)
  end

  def process_single_id(id) do
    Ak.Api.get("event/#{id}").body
    |> wrap_event()
    |> pipeline()
  end

  def handle_new_turnout_requests do
    order_by = "-created_at"
    page = @turnout_survey_page

    Ak.Api.stream("action", query: ~m(order_by page))
    |> Enum.take_while(&is_within_interval/1)
    |> Enum.map(&fetch_corresponding_event/1)
    |> Enum.map(&send_out/1)
  end

  def is_within_interval(~m(created_at)) do
    {_, created_dt, _} = DateTime.from_iso8601(created_at <> "Z")
    benchmark = Timex.now() |> Timex.shift(@interval)
    Timex.before?(benchmark, created_dt)
  end

  def wrap_event(event) do
    ~m(event)
  end

  def pipeline(event) do
    event
    |> ensure_attributes()
    |> add_local_organizer_tag()
    |> auto_publish()

    # |> send_out_if_volunteer()
  end

  def ensure_attributes(%{"event" => ~m(creator id)}) do
    "/rest/v1/user/" <> creator_id = creator
    ~m(email first_name last_name phone) = creator = fetch_contact_info(creator_id)

    OsdiClient.put(ak_client(), "events/#{id}", %{
      contact: %{
        email_address: email,
        name: "#{first_name} #{last_name}",
        phone_number: phone
      }
    })

    event = Ak.Api.get("event/#{id}").body
    ~m(event creator)
  end

  def add_local_organizer_tag(param = %{"event" => ~m(id), "creator" => ~m(email)}) do
    %{"metadata" => ~m(local_chapter_leader_list)} = Cosmic.get("jd-esm-config")
    local_leader_emails = String.split(local_chapter_leader_list, "\n")

    if Enum.member?(local_leader_emails, email) do
      %{body: event} = OsdiClient.get(ak_client(), "events/#{id}")

      new_tags =
        if not Enum.member?(event.tags, "Calendar: Local Chapter") do
          ["Calendar: Local Chapter" | event.tags]
        else
          event.tags
        end

      OsdiClient.put(ak_client(), "events/#{id}", %{"tags" => new_tags})
    end

    param
  end

  def auto_publish(params = %{"event" => ak_event = ~m(id)}) do
    %{body: event} = OsdiClient.get(ak_client(), "events/#{id}")

    tags =
      case event.tags do
        [] -> get_event_tags(ak_event)
        more_things -> more_things
      end

    type =
      case event.type do
        "Unknown" -> get_event_type(ak_event)
        type -> type
      end

    body =
      if Enum.member?(tags, "Source: Direct Publish") do
        Logger.info("Auto publishing #{id}")
        status = "confirmed"
        ~m(status tags type)
      else
        Logger.info("#{id} is a vol event")
        status = "tentative"
        ~m(status tags type)
      end

    OsdiClient.put(ak_client(), "events/#{id}", body)
    event = Ak.Api.get("event/#{id}").body
    Map.put(params, "event", event)
  end

  # CURRENTLY UNSUED
  def send_out_if_volunteer(params = %{"event" => %{"is_approved" => false, "id" => id}}) do
    %{body: osdi_format} = OsdiClient.get(ak_client(), "events/#{id}")
    %{"metadata" => ~m(vol_event_submission)} = Cosmic.get("jd-esm-config")
    body = Poison.encode!(osdi_format)

    Logger.info("Sending out volunteer event hook for #{id}")
    HTTPotion.post(vol_event_submission, body: body)
    params
  end

  def send_out_if_volunteer(params) do
    params
  end

  def get_event_tags(~m(fields)) do
    case Enum.filter(fields, fn f -> f["name"] == "event_tags" end) |> List.first() do
      ~m(value) -> Poison.decode!(value)
      nil -> "Unknown"
    end
  end

  def get_event_type(~m(fields)) do
    case Enum.filter(fields, fn f -> f["name"] == "event_type" end) |> List.first() do
      ~m(value) -> value
      nil -> []
    end
  end

  def send_out(:error) do
    nil
  end

  def send_out({survey, event_id}) do
    %{"metadata" => ~m(turnout_request)} = Cosmic.get("jd-esm-config")
    %{body: event} = OsdiClient.get(ak_client(), "events/#{event_id}")
    body = Poison.encode!(~m(survey event))
    IO.inspect(HTTPotion.post(turnout_request, body: body))
  end

  def fetch_corresponding_event(survey = ~m(user fields)) do
    "/rest/v1/user/" <> user_id = user
    order_by = "-created_at"

    match =
      Ak.Api.stream("event", query: ~m(order_by))
      |> Enum.reduce_while(nil, fn e, _acc ->
        if e["creator"] == user do
          {:halt, e}
        else
          {:cont, nil}
        end
      end)

    case match do
      ~m(id) ->
        contact_info = fetch_contact_info(user_id)
        {Map.merge(fields, contact_info), id}

      _ ->
        %{"metadata" => ~m(turnout_request_error)} = Cosmic.get("jd-esm-config")
        body = Poison.encode!(survey)
        HTTPotion.post(turnout_request_error, body: body)
        :error
    end
  end

  def fetch_contact_info(user_id) do
    ~m(email first_name last_name phones) = Ak.Api.get("user/#{user_id}").body
    phone = primary_phone(phones)
    ~m(email first_name last_name phone)
  end

  defp primary_phone(_phones = []) do
    nil
  end

  defp primary_phone(_phones = ["/rest/v1/" <> phone_url | _]) do
    ~m(normalized_phone) = Ak.Api.get(phone_url).body
    normalized_phone
  end
end
