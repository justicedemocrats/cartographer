defmodule Jobs.PairEvents do
  import ShortMaps

  @primary OsdiClient.build_client(
             "endpoint",
             "osdi_api_token"
           )
  @secondary OsdiClient.build_client(
               "endpoint",
               "osdi_api_token"
             )

  @secondary_identifier_prefix "district-district-system"
  @tags ["Calendar: Someone", "Source: Sync"]

  def go do
    secondary_url_maps =
      OsdiClient.stream(@secondary, "events")
      |> Enum.reduce(%{}, fn ~m(browser_url id), acc ->
        Map.put(acc, browser_url, id)
      end)

    primary_secondary_id_pairs =
      get_pairs()
      |> Enum.map(fn {primary_id, secondary_url} ->
        secondary_id = Map.get(secondary_url_maps, secondary_url, false) |> IO.inspect()
        {primary_id, secondary_id}
      end)

    Enum.map(primary_secondary_id_pairs, fn {p, s} ->
      identifiers = [@secondary_identifier_prefix <> ":" <> s]
      tags = @tags
      {p, ~m(identifiers tags)}
    end)
    |> Enum.each(fn {id, body} ->
      IO.inspect(OsdiClient.put(@primary, "events/#{id}", body))
    end)
  end

  def get_pairs do
    [
      {2363, "https://actionnetwork.org/events/test-event-161"},
      {2114,
       "https://actionnetwork.org/events/june-24th-ocasio-2018-astoria-final-sunday-canvass"},
      {2113,
       "https://actionnetwork.org/events/june-23rd-ocasio-2018-astoria-final-saturday-canvass"},
      {2112, "https://actionnetwork.org/events/june-17th-ocasio-2018-astoria-canvass"},
      {2111, "https://actionnetwork.org/events/june-16th-ocasio-2018-astoria-canvass"},
      {2110, "https://actionnetwork.org/events/june-10th-ocasio-2018-astoria-canvass"},
      {2295, "https://actionnetwork.org/events/610-postering-for-ocasio-in-south-ozone-park"},
      {2298, "https://actionnetwork.org/events/0610-textingpostcards-for-ocasio-campaign"},
      {2109, "https://actionnetwork.org/events/june-9th-ocasio-2018-astoria-canvass"},
      {2294, "https://actionnetwork.org/events/63-postering-for-ocasio-in-south-ozone-park"},
      {2297,
       "https://actionnetwork.org/events/0603-textingpostcards-for-ocasio-campaign-for-congress"},
      {2106, "https://actionnetwork.org/events/june-2nd-ocasio-2018-astoria-canvass"},
      {2107, "https://actionnetwork.org/events/june-2nd-ocasio-2018-astoria-canvass"},
      {2412, "https://actionnetwork.org/events/530-parkchester-door-knocking-ocasio2018"},
      {2428, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-14"},
      {2105, "https://actionnetwork.org/events/may-27th-ocasio-2018-astoria-canvass"},
      {2267, "https://actionnetwork.org/events/527-door-knocking-for-ocasio-in-queens"},
      {2293, "https://actionnetwork.org/events/527-postering-for-ocasio-in-south-ozone-park"},
      {2296, "https://actionnetwork.org/events/0527-textingpostering-ocasio-for-congress"},
      {2413, "https://actionnetwork.org/events/527-parkchester-door-knocking-ocasio2018"},
      {2429, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-13"},
      {2104, "https://actionnetwork.org/events/may-26th-ocasio-2018-astoria-canvass"},
      {2254, "https://actionnetwork.org/events/526-door-knocking-for-ocasio-in-astoria"},
      {2414, "https://actionnetwork.org/events/526-parkchester-door-knocking-ocasio2018"},
      {2430, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-12"},
      {2191, "https://actionnetwork.org/events/may-25th-bergn-beer-hall-blowout"},
      {2415, "https://actionnetwork.org/events/523-parkchester-door-knocking-ocasio2018"},
      {2431, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-11"},
      {2236,
       "https://actionnetwork.org/events/521-postering-for-ocasio-in-woodsidejackson-heights"},
      {2416, "https://actionnetwork.org/events/521-parkchester-door-knocking-ocasio2018"},
      {2432, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-10"},
      {2103, "https://actionnetwork.org/events/may-20th-ocasio-2018-astoria-canvass"},
      {2253, "https://actionnetwork.org/events/520-door-knocking-for-ocasio-in-astoria"},
      {2261, "https://actionnetwork.org/events/520-phonebank-for-ocasio-in-astoria"},
      {2266, "https://actionnetwork.org/events/520-door-knocking-for-ocasio-in-queens"},
      {2417, "https://actionnetwork.org/events/520-parkchester-door-knocking-ocasio2018"},
      {2433, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-9"},
      {2102, "https://actionnetwork.org/events/may-19th-ocasio-2018-astoria-canvass"},
      {2252, "https://actionnetwork.org/events/519-door-knocking-for-ocasio-in-astoria"},
      {2286, "https://actionnetwork.org/events/0519-postering-event-for-alexandria-ocasio-cortez"},
      {2418, "https://actionnetwork.org/events/519-parkchester-door-knocking-ocasio2018"},
      {2434, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-8"},
      {2239, "https://actionnetwork.org/events/518-doorknocking-for-ocasio-in-jackson-heights"},
      {2453, "https://actionnetwork.org/events/ocasio-phone-bank-in-jamaica"},
      {2419, "https://actionnetwork.org/events/516-parkchester-door-knocking-ocasio2018"},
      {2435, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-7"},
      {2235,
       "https://actionnetwork.org/events/514-postering-for-ocasio-in-woodsidejackson-heights"},
      {2420, "https://actionnetwork.org/events/514-parkchester-door-knocking-ocasio2018"},
      {2436, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-6"},
      {2178, "https://actionnetwork.org/events/0513-door-knocking-for-ocasio2018-in-sunnyside"},
      {2250, "https://actionnetwork.org/events/513-door-knocking-for-ocasio-in-astoria"},
      {2258, "https://actionnetwork.org/events/513-postering-for-ocasio-in-brooklyn"},
      {2259,
       "https://actionnetwork.org/events/513-postering-in-astoria-for-alexandria-ocasio-cortez"},
      {2265, "https://actionnetwork.org/events/513-door-knocking-for-ocasio-in-queens"},
      {2292, "https://actionnetwork.org/events/513-postering-for-ocasio-in-south-ozone-park"},
      {2302, "https://actionnetwork.org/events/0513-postering-event-for-ocasio-cortez-campaign"},
      {2421, "https://actionnetwork.org/events/513-parkchester-door-knocking-ocasio2018"},
      {2437, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-5"},
      {2101, "https://actionnetwork.org/events/may-12th-ocasio-2018-astoria-canvass"},
      {2249, "https://actionnetwork.org/events/512-door-knocking-for-ocasio-in-astoria"},
      {2256, "https://actionnetwork.org/events/512-postering-for-ocasio-in-brooklyn"},
      {2287, "https://actionnetwork.org/events/0512-door-knocking-in-jackson-heights-for-ocasio"},
      {2288, "https://actionnetwork.org/events/512-door-knocking-for-ocasio-in-woodside"},
      {2422, "https://actionnetwork.org/events/512-parkchester-door-knocking-ocasio2018"},
      {2438, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-4"},
      {2455, "https://actionnetwork.org/events/ocasio-phone-bank-in-jackson-heights"},
      {2454, "https://actionnetwork.org/events/ocasio-phone-bank-in-the-bronx"},
      {2177, "https://actionnetwork.org/events/0509-door-knocking-for-ocasio2018-in-sunnyside"},
      {2218, "https://actionnetwork.org/events/59-phonebank-for-alex-ocasio"},
      {2439, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-3"},
      {2443, "https://actionnetwork.org/events/phone-banking-for-ocasio-with-jake"},
      {2176, "https://actionnetwork.org/events/0508-door-knocking-for-ocasio2018-in-sunnyside"},
      {2244, "https://actionnetwork.org/events/phone-bank-in-jackson-heights-for-ocasio"},
      {2440, "https://actionnetwork.org/events/door-knocking-for-ocasio2018-with-tim-2"}
    ]
  end
end
