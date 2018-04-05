defmodule Cartographer.Router do
  use Cartographer.Web, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", Cartographer do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)
  end

  scope "/api", Cartographer do
    pipe_through(:api)

    get("/events", ApiController, :events)
    get("/geocode", ApiController, :district)
  end

  # Other scopes may use custom stacks.
  # scope "/api", Cartographer do
  #   pipe_through :api
  # end
end
