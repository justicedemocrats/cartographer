defmodule Jobs.ProcessNewEvents do
  import ShortMaps
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
  end

  def ensure_attributes(%{"event" => ~m(creator id)}) do
    "/rest/v1/user/" <> creator_id = creator
    ~m(email first_name last_name phone) = creator = fetch_contact_info(creator_id)

    AkProxy.post(
      "events/#{id}",
      body: %{
        contact: %{
          email_address: email,
          name: "#{first_name} #{last_name}",
          phone_number: phone
        }
      }
    )

    event = Ak.Api.get("event/#{id}").body
    ~m(event creator)
  end

  def add_local_organizer_tag(param = %{"event" => ~m(id), "creator" => ~m(email)}) do
    %{"metadata" => ~m(local_chapter_leader_list)} = Cosmic.get("jd-esm-config")
    local_leader_emails = String.split(local_chapter_leader_list, "\n")

    if Enum.member?(local_leader_emails, email) do
      %{body: event} = AkProxy.get("events/#{id}")

      new_tags =
        if not Enum.member?(event.tags, "Calendar: Local Chapter") do
          ["Calendar: Local Chapter" | event.tags]
        else
          event.tags
        end

      AkProxy.post("events/#{id}", body: %{"tags" => new_tags})
    end

    param
  end

  def auto_publish(params = %{"event" => ~m(id)}) do
    %{body: event} = AkProxy.get("events/#{id}")

    if Enum.member?(event.tags, "Source: Direct Publish") do
      AkProxy.post("events/#{id}", body: %{"status" => "confirmed"})
    end

    event = Ak.Api.get("event/#{id}").body
    Map.put(params, "event", event)
  end

  def send_out(:error) do
    nil
  end

  def send_out({survey, event_id}) do
    %{"metadata" => ~m(turnout_request)} = Cosmic.get("jd-esm-config")
    %{body: event} = AkProxy.get("events/#{event_id}")
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
