defmodule MmoWeb.GameLiveTest do
  use MmoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    hero = "critical hero"
    {:ok, page_live, _disconnected_html} = live(conn, Routes.game_path(conn, :index, name: hero))
    assert render(page_live) =~ hero
  end
end
