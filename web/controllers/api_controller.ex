defmodule Cartographer.ApiController do
  import ShortMaps
  use Cartographer.Web, :controller

  def events(conn, ~m(candidate)) do
    json(conn, Cartographer.EventCache.for(candidate))
  end

  def events(conn, _params) do
    json(conn, Cartographer.EventCache.all())
  end

  def district(conn, ~m(address)) do
    body =
      case District.from_address(address) do
        nil ->
          %{"error" => "Could not match address to district"}

        district when is_binary(district) ->
          candidate = District.get_candidate(district)

          geojson =
            District.get_polygon_of(district)
            |> Geo.JSON.encode()

          ~m(district geojson candidate)
      end

    json(conn, body)
  end

  def district(conn, ~m(district)) do
    body =
      case District.from_unknown(district) do
        nil ->
          %{"error" => "Could not parse district from #{district}"}

        normalized when is_binary(normalized) ->
          geojson = District.get_polygon_of(normalized)
          candidate = District.get_candidate(normalized)
          district = normalized
          ~m(district geojson candidate)
      end

    json(conn, body)
  end
end
