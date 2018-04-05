defmodule District.Parser do
  def load_geojsons do
    districts =
      "./lib/district/geojsons"
      |> File.ls!()
      |> Enum.filter(&(not String.contains?(&1, ".DS_Store")))

    geojsons =
      districts
      |> Enum.map(fn district ->
        IO.puts(district)
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
