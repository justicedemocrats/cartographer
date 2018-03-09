defmodule District.Build do
  require Logger

  def build do
    Logger.info("Creating district data")
    composite = District.Parser.load_geojsons()
    Stash.set(:district_cache, "district", composite)
    Stash.persist(:district_cache, "./lib/district/district.ets")
  end
end
