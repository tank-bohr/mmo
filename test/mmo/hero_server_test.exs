defmodule Mmo.HeroServerTest do
  use ExUnit.Case

  alias Mmo.Hero
  alias Mmo.HeroesRegistry

  test "update_tile" do
    {:ok, pid} = Mmo.HeroServer.start_link(%Hero{name: "john", tile: {2, 1}})
    :ok = Mmo.HeroServer.update_tile(pid, {2, 2})
    [{^pid, hero}] = Registry.lookup(HeroesRegistry, "john")
    assert hero.tile == {2, 2}
  end

  test "kill_hero" do
    {:ok, pid} = Mmo.HeroServer.start_link(%Hero{name: "john", tile: {2, 1}})
    :ok = Mmo.HeroServer.kill_hero(pid)
    [{^pid, hero}] = Registry.lookup(HeroesRegistry, "john")
    refute hero.alive?
  end

  test "revive_hero" do
    {:ok, pid} = Mmo.HeroServer.start_link(%Hero{name: "john", tile: {2, 1}})
    :ok = Mmo.HeroServer.revive_hero(pid, {1, 10})
    [{^pid, hero}] = Registry.lookup(HeroesRegistry, "john")
    assert %Hero{alive?: true, tile: {1, 10}} = hero
  end
end
