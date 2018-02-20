defmodule AkClient do
  def base, do: Application.get_env(:cartographer, :osdi_base_url)
  def secret, do: Application.get_env(:cartographer, :osdi_api_token)

  def ak_client do
    OsdiClient.build_client(base(), secret())
  end
end
