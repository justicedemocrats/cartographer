defmodule District.Parser do
  def load_geojsons do
    {:ok, districts} = "./lib/district/geojsons" |> File.ls()

    geojsons =
      districts
      |> Enum.filter(&(not String.contains?(&1, ".DS_Store")))
      |> Enum.map(fn district ->
        {:ok, file} = "./lib/district/geojsons/#{district}" |> File.read()
        {:ok, %{"geometry" => geometry}} = file |> Poison.decode()

        geometry
        |> Geo.JSON.decode()
      end)

    districts
    |> Enum.map(fn str -> str |> String.split(".") |> List.first() end)
    |> Enum.zip(geojsons)
    |> Enum.into(%{})
  end
end
