defmodule OsdiClient do
  use Tesla
  import ShortMaps

  def build_client(base, osdi_api_token) do
    Tesla.build_client([
      {Tesla.Middleware.JSON, decode_content_types: ["application/hal+json"]},
      {Tesla.Middleware.Headers, %{"OSDI-API-Token" => osdi_api_token}},
      {Tesla.Middleware.BaseUrl, base}
    ])
  end

  def stream(client, url) do
    %{body: first_response} = get(client, url)
    Stream.unfold({client, first_response, 0}, &unfolder/1)
  end

  def unfolder({client, prev_response, next_idx}) do
    case item_at_idx(prev_response, next_idx) do
      {:ok, item} ->
        {item, {client, prev_response, next_idx + 1}}

      {:error, :out_of_items} ->
        if is_last_page(prev_response) do
          nil
        else
          %{body: next_request} = get(client, get_in(prev_response, ~w(_links next href)))
          unfolder({client, next_request, 0})
        end
    end
  end

  def item_at_idx(body, idx) do
    case Enum.at(extract_embedded_items(body), idx) do
      nil -> {:error, :out_of_items}
      m when is_map(m) -> {:ok, m}
    end
  end

  def extract_embedded_items(body) do
    key =
      body
      |> Map.get("_embedded")
      |> Map.keys()
      |> Enum.filter(fn
        "osdi:" <> _rest -> true
        _ -> false
      end)
      |> List.first()

    get_in(body, ["_embedded", key])
  end

  def is_last_page(~m(total_pages page)) do
    total_pages == page
  end
end
