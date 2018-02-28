defmodule Cartographer.Airtable do
  use AirtableConfig
  import ShortMaps

  def key, do: Application.get_env(:cartographer, :airtable_key)
  def base, do: Application.get_env(:cartographer, :airtable_base)
  def table, do: Application.get_env(:cartographer, :airtable_table_name)
  def view, do: "Grid view"
  def into_what, do: %{}

  def filter_record(~m(fields)) do
    Map.has_key?(fields, "Candidate Events Url")
  end

  def process_record(~m(fields)) do
    osdi_api_token = fields["OSDI API Token"]
    endpoint = fields["Endpoint"]
    json_schema_filter = fields["JSON Schema Filter"]
    reference_name = fields["Reference Name"]
    candidate_events_url = fields["Candidate Events Url"]
    point_of_contact = fields["Point of Contact"]

    {slugify(reference_name),
     ~m(osdi_api_token endpoint json_schema_filter reference_name candidate_events_url point_of_contact)}
  end

  def slugify(reference_name) do
    reference_name
    |> String.downcase()
    |> String.replace(" ", "-")
  end
end
