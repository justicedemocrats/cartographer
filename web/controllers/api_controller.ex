defmodule Cartographer.ApiController do
  import ShortMaps
  use Cartographer.Web, :controller

  def events(conn, ~m(candidate)) do
    json(conn, Cartographer.EventCache.for(candidate))
  end

  def events(conn, _params) do
    json(conn, Cartographer.EventCache.all())
  end
end
