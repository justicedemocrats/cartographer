defmodule Cartographer.ApiController do
  import ShortMaps
  use Cartographer.Web, :controller

  def events(conn, ~m(candidate)) do
    json(conn, Cartographer.EventCache.for(candidate))
  end

  def events(conn, _params) do
    json(conn, Cartographer.EventCache.all())
  end

  def geocode(conn, ~m(q)) do
    body =
      case District.from_address(q) do
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

  def geocode(conn, _) do
    conn
    |> put_status(400)
    |> json(%{"error" => "missing query – proper usage is /district/search?q=address"})
  end

  def district(conn, ~m(district)) do
    body =
      case District.from_unknown(district) do
        nil ->
          %{"error" => "Could not parse district from #{district}"}

        {normalized, _} when is_binary(normalized) ->
          geojson =
            District.get_polygon_of(district)
            |> Geo.JSON.encode()

          candidate = District.get_candidate(normalized)
          district = normalized
          ~m(district geojson candidate)
      end

    json(conn, body)
  end

  def district(conn, _) do
    conn
    |> put_status(404)
    |> json(%{"error" => "missing district - proper usage is /district/:district"})
  end

  def all_districts(conn, _) do
    districts_with_candidates =
      District.get_gjs()
      |> Map.keys()
      |> Enum.map(&District.get_candidate(&1))
      |> Enum.reject(&(&1 == nil))
      |> IO.inspect()

    json(conn, districts_with_candidates)
  end
end
