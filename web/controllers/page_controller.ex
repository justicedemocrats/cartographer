defmodule Cartographer.PageController do
  use Cartographer.Web, :controller

  def index(conn, _params) do
    render(
      conn,
      "index.html",
      mapbox_api_access_token: Application.get_env(:cartographer, :mapbox_api_access_token)
    )
  end
end
