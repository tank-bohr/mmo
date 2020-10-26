defmodule MmoWeb.WelcomeController do
  use MmoWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", %{csrf_token: get_csrf_token()})
  end

  def create(conn, %{"name" => name}) do
    redirect(conn, to: Routes.game_path(conn, :index, name: name))
  end
end
