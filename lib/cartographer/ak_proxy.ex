defmodule AkProxy do
  use HTTPotion.Base

  def base, do: Application.get_env(:cartographer, :osdi_base_url)
  def secret, do: Application.get_env(:cartographer, :osdi_api_token)

  def process_url(url) do
    "#{base()}/#{url}"
  end

  def process_options(opts) do
    Keyword.put(opts, :timeout, 60_000)
  end

  def process_request_body(map) when is_map(map) do
    Poison.encode!(map)
  end

  def process_request_body(text) do
    text
  end

  defp process_request_headers(hdrs) do
    Enum.into(
      hdrs,
      Accept: "application/json",
      "Content-Type": "application/json",
      "OSDI-API-Token": secret()
    )
  end

  defp process_response_body(raw) do
    case Poison.Parser.parse(raw, keys: :atoms) do
      {:ok, map} -> map
      {:error, _reason} -> raw
    end
  end

  def stream(url) do
    stream(url, [], 0)
  end

  def stream(url, previous_results, page) do
    %{body: current_results} = get(url, query: %{page: page})

    if length(current_results) == 0 do
      Enum.concat(previous_results, current_results)
    else
      stream(url, Enum.concat(previous_results, current_results), page + 1)
    end
  end
end
