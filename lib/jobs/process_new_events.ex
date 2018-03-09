defmodule Jobs.ProcessNewEvents do
  import ShortMaps
  import AkClient
  require Logger

  @interval [minutes: -6]
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
    |> Enum.filter(&is_not_from_sync/1)
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
    |> Stream.map(&turnout_request_fork/1)
    |> Stream.map(&send_out/1)
    |> Enum.to_list()
  end

  def turnout_request_fork(survey = ~m(user fields)) do
    event_id =
      case get_event_id(survey) do
        :not_found ->
          survey
          |> fetch_corresponding_event()

        event_id ->
          event_id
      end

    "/rest/v1/user/" <> user_id = user
    contact_info = fetch_contact_info(user_id)

    {Map.merge(fields, contact_info), event_id}
    |> join_event_id_and_survey()
  end

  def turnout_requests_with_event_id do
    order_by = "-created_at"
    page = @turnout_survey_page

    Ak.Api.stream("action", query: ~m(order_by page))
    |> Stream.filter(fn ~m(fields) -> Map.has_key?(fields, "event_id") end)
    |> Enum.take(2)
  end

  def is_within_interval(~m(created_at)) do
    {_, created_dt, _} = DateTime.from_iso8601(created_at <> "Z")
    benchmark = Timex.now() |> Timex.shift(@interval)
    Timex.before?(benchmark, created_dt)
  end

  def wrap_event(event) do
    ~m(event)
  end

  def is_not_from_sync(~m(event)) do
    not (get_event_tags(event)
         |> Enum.member?("Source: Sync"))
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
        if not Enum.member?(event["tags"], "Calendar: Local Chapter") do
          ["Calendar: Local Chapter" | event["tags"]]
        else
          event["tags"]
        end

      OsdiClient.put(ak_client(), "events/#{id}", %{"tags" => new_tags})
    end

    param
  end

  def auto_publish(params = %{"event" => ak_event = ~m(id)}) do
    %{body: event} = OsdiClient.get(ak_client(), "events/#{id}")

    # Add candidate tag
    candidate_tags =
      case get_event_candidate(ak_event) do
        nil -> []
        "" -> []
        candidate -> ["Calendar: #{candidate}"]
      end

    tags =
      Enum.concat([
        get_event_tags(ak_event),
        event["tags"],
        candidate_tags
      ])
      |> MapSet.new()
      |> Enum.to_list()

    type =
      case event["type"] do
        "Unknown" -> get_event_type(ak_event)
        type -> type
      end

    body =
      if Enum.member?(tags, "Source: Direct Publish") or Enum.member?(tags, "Source: Sync") do
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

  def get_event_tags(event) do
    string_val = get_value_of_event_field(event, "event_tags")

    case Poison.decode(string_val) do
      {:ok, map} -> map
      _ -> string_val
    end
  end

  def get_event_type(event) do
    get_value_of_event_field(event, "event_type")
  end

  def get_event_candidate(event) do
    get_value_of_event_field(event, "event_candidate")
  end

  def get_value_of_event_field(~m(fields), field) do
    case Enum.filter(fields, fn f -> f["name"] == field end) |> List.first() do
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
    candidate = Enum.filter(event["tags"], &is_candidate_tag/1) |> List.first() |> get_candidate()
    body = Poison.encode!(~m(survey event candidate))
    HTTPotion.post(turnout_request, body: body)
  end

  def is_candidate_tag("Calendar: " <> candidate) do
    not (String.contains?(candidate, "Brand New Congress") or
           String.contains?(candidate, "Justice Democrats"))
  end

  def is_candidate_tag(_other) do
    false
  end

  def get_candidate("Calendar: " <> candidate), do: candidate
  def get_candidate(_other), do: nil

  def get_event_id(~m(fields)), do: Map.get(fields, "event_id", :not_found)

  def fetch_corresponding_event(survey = ~m(user fields)) do
    order_by = "-created_at"

    if Map.has_key?(fields, "event_id") do
      fields["event_id"]
    else
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
          id

        _ ->
          %{"metadata" => ~m(turnout_request_error)} = Cosmic.get("jd-esm-config")
          body = Poison.encode!(survey)
          HTTPotion.post(turnout_request_error, body: body)
          :error
      end
    end
  end

  def join_event_id_and_survey({survey, event_id}) do
    survey_action_uri = "surveyaction/#{survey["id"]}"
    fields = Map.drop(survey, ~w(phone email first_name last_name id))

    add_event_id_to_survey_task =
      Task.async(fn ->
        new_fields = Map.put(fields, "event_id", event_id)
        Ak.Api.put(survey_action_uri, body: %{"fields" => new_fields})
        survey
      end)

    add_survey_id_to_event_task =
      Task.async(fn ->
        Ak.Api.post(
          "eventfield",
          body: %{
            "value" => survey["id"],
            "event" => "/event/#{event_id}/",
            "name" => "survey_id"
          }
        )

        event_id
      end)

    [a, b] = Enum.map([add_event_id_to_survey_task, add_survey_id_to_event_task], &Task.await/1)
    {a, b}
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
