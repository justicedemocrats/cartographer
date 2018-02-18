defmodule Cartographer.Airtable do
  use AirtableConfig
  import ShortMaps

  def key, do: Application.get_env(:cartographer, :airtable_key)
  def base, do: Application.get_env(:cartographer, :airtable_base)
  def table, do: Application.get_env(:cartographer, :airtable_table_name)
  def view, do: "Grid view"
  def into_what, do: %{} |> IO.inspect()

  def filter_record(~m(fields)) do
    Map.has_key?(fields, "OSDI API Token")
  end

  def process_record(~m(fields)) do
    osdi_api_token = fields["OSDI API Token"]
    endpoint = fields["Endpoint"]
    json_schema_filter = fields["JSON Schema Filter"]
    {slugify(fields["Reference Name"]), ~m(osdi_api_token endpoint json_schema_filter)}
  end

  def slugify(reference_name) do
    reference_name
    |> String.downcase()
    |> String.replace(" ", "-")
  end
end
