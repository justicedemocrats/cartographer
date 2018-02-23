use Mix.Config

# For production, we configure the host to read the PORT
# from the system environment. Therefore, you will need
# to set PORT=80 before running your server.
#
# You should also configure the url host to something
# meaningful, we use this information when generating URLs.
#
# Finally, we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the mix phoenix.digest task
# which you typically run after static files are built.
config :cartographer, Cartographer.Endpoint,
  http: [:inet6, port: {:system, "PORT"}],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Do not print debug messages in production
config :logger, level: :info

# Proxy layer + mongo
config :cartographer,
  osdi_base_url: "${OSDI_BASE_URL}",
  osdi_api_token: "${OSDI_API_TOKEN}"

config :cartographer,
  airtable_key: "${AIRTABLE_KEY}",
  airtable_base: "${AIRTABLE_BASE}",
  airtable_table_name: "${AIRTABLE_TABLE_NAME}"

config :actionkit,
  base: "${AK_BASE}",
  username: "${AK_USERNAME}",
  password: "${AK_PASSWORD}"

config :cartographer,
  event_synced_webhook: "${EVENT_SYNCED_WEBHOOK}",
  event_deleted_webhook: "${EVENT_DELETED_WEBHOOK}"
