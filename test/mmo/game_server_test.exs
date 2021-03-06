defmodule Mmo.GameServerTest do
  use ExUnit.Case

  alias Mmo.HeroServer
  alias Mmo.HeroesRegistry

  defp receive_update!(wait \\ 1) do
    receive do
      {:update, world} -> world
    after
      :timer.seconds(wait) ->
        raise "timeout"
    end
  end

  defp get_tile(world, {i, j}) do
    world
    |> Enum.at(i)
    |> Enum.at(j)
  end

  describe "connect" do
    test "subscribes to PubSup topic" do
      :ok = Mmo.GameServer.connect("funny frog")
      assert_receive({:update, _})
    end

    test "registers hero server in registry" do
      name = "curious hippo"
      :ok = Mmo.GameServer.connect(name)
      [{pid, hero}] = Registry.lookup(Mmo.HeroesRegistry, name)
      assert Process.alive?(pid)
      assert hero.name == name
    end
  end

  describe "move_hero" do
    test "change hero position" do
      name = "fluid beast"
      :ok = Mmo.GameServer.connect(name, {2, 2})

      assert(
        receive_update!()
        |> get_tile({1, 2})
        |> Map.get(:heroes)
        |> Enum.empty?()
      )

      :ok = Mmo.GameServer.move_hero(name, :up)

      assert [%{name: ^name}] =
               receive_update!()
               |> get_tile({1, 2})
               |> Map.get(:heroes)
    end
  end

  describe "attack" do
    test "kills neighbor" do
      parent = self()

      pid =
        spawn_link(fn ->
          :ok = Mmo.GameServer.connect("victim", {1, 2})

          send(parent, :ready)

          receive do
            :stop -> :ok
          end
        end)

      receive do
        :ready -> :ok
      after
        :timer.seconds(1) ->
          raise "timeout"
      end

      :ok = Mmo.GameServer.connect("attacker", {2, 2})

      assert [%{alive?: true}] =
               receive_update!()
               |> get_tile({1, 2})
               |> Map.get(:heroes)

      :ok = Mmo.GameServer.attack("attacker")

      assert [%{alive?: false}] =
               receive_update!()
               |> get_tile({1, 2})
               |> Map.get(:heroes)

      victim_revives = receive_update!(6)
      [{_pid, hero}] = Registry.lookup(Mmo.HeroesRegistry, "victim")

      assert %{alive?: true} =
               victim_revives
               |> get_tile(hero.tile)
               |> Map.get(:heroes)
               |> Enum.find(fn hero -> hero.name == "victim" end)

      send(pid, :stop)
      Process.sleep(500)
      _victim_disconnects = receive_update!()
      assert [] = Registry.lookup(Mmo.HeroesRegistry, "victim")
    end

    test "when hero is dead" do
      parent = self()

      pid =
        spawn_link(fn ->
          :ok = Mmo.GameServer.connect("victim", {1, 2})
          send(parent, :ready)

          receive do
            :stop -> :ok
          end
        end)

      receive do
        :ready -> :ok
      after
        :timer.seconds(1) ->
          raise "timeout"
      end

      :ok = Mmo.GameServer.connect("attacker", {2, 2})

      assert Enum.any?(receive_update!())

      [{hero_server, _}] = Registry.lookup(HeroesRegistry, "attacker")
      :ok = HeroServer.kill_hero(hero_server)
      :ok = Mmo.GameServer.attack("attacker")

      assert [%{alive?: true}] =
               receive_update!()
               |> get_tile({1, 2})
               |> Map.get(:heroes)

      send(pid, :stop)
    end
  end
end
