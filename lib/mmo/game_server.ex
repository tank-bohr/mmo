defmodule Mmo.GameServer do
  use GenServer

  alias Mmo.PubSub
  alias Mmo.Hero
  alias Mmo.HeroServer
  alias Mmo.HeroesRegistry

  require Logger

  @wally %{wall?: true}
  @empty %{wall?: false}
  @grid [
    [@wally, @wally, @wally, @wally, @wally, @wally, @wally, @wally, @wally, @wally],
    [@wally, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @wally],
    [@wally, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @wally],
    [@wally, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @wally],
    [@wally, @wally, @empty, @wally, @wally, @wally, @wally, @empty, @empty, @wally],
    [@wally, @empty, @empty, @empty, @wally, @empty, @empty, @empty, @empty, @wally],
    [@wally, @empty, @empty, @empty, @wally, @empty, @empty, @empty, @empty, @wally],
    [@wally, @empty, @empty, @empty, @wally, @empty, @empty, @empty, @empty, @wally],
    [@wally, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @empty, @wally],
    [@wally, @wally, @wally, @wally, @wally, @wally, @wally, @wally, @wally, @wally]
  ]

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def connect(name, tile \\ :random) do
    Phoenix.PubSub.subscribe(PubSub, "game")
    GenServer.call(__MODULE__, {:connect, name, tile})
  end

  def move_hero(name, direction) do
    GenServer.call(__MODULE__, {:move, name, direction})
  end

  def attack(name) do
    GenServer.call(__MODULE__, {:attack, name})
  end

  @impl true
  def init(_options) do
    walkable_tiles = get_walkable_tiles(@grid)

    {:ok,
     %{
       grid: @grid,
       walkable_tiles: walkable_tiles,
       walkable_tiles_set: MapSet.new(walkable_tiles)
     }}
  end

  @impl true
  def handle_call({:connect, name, tile}, {client, _}, state) do
    {pid, _hero} = find_or_create_hero(name, tile, state)
    :ok = HeroServer.increase_counter(pid, client)
    {:reply, notify_clients(state), state}
  end

  def handle_call({:move, name, direction}, _from, state) do
    {pid, hero} = find_hero(name)
    new_tile = move(hero.tile, direction)
    if tile_available?(new_tile, state), do: HeroServer.update_tile(pid, new_tile)
    {:reply, notify_clients(state), state}
  end

  def handle_call({:attack, name}, _from, state) do
    {_pid, attacker} = find_hero(name)
    destruction(attacker)
    {:reply, notify_clients(state), state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    :ok = notify_clients(state)
    {:noreply, state}
  end

  def handle_info({:revive, pid}, %{walkable_tiles: walkable_tiles} = state) do
    tile = Enum.random(walkable_tiles)
    :ok = HeroServer.revive_hero(pid, tile)
    :ok = notify_clients(state)
    {:noreply, state}
  end

  defp find_or_create_hero(name, tile, %{walkable_tiles: walkable_tiles}) do
    case find_hero(name) do
      :not_found ->
        create_hero(name, tile, walkable_tiles)

      found ->
        found
    end
  end

  defp find_hero(name) do
    case Registry.lookup(HeroesRegistry, name) do
      [] ->
        :not_found

      [{pid, hero}] ->
        {pid, hero}
    end
  end

  defp create_hero(name, tile, walkable_tiles) do
    tile =
      case tile do
        :random -> Enum.random(walkable_tiles)
        {i, j} -> {i, j}
      end

    hero = %Hero{name: name, tile: tile}
    {:ok, pid} = HeroServer.create(hero)
    Process.monitor(pid)
    {pid, hero}
  end

  defp get_current_world(%{grid: grid}) do
    heroes = grouped_heroes()

    traverse(grid, fn tile, i, j ->
      case Map.fetch(heroes, {i, j}) do
        {:ok, list} ->
          Map.put(tile, :heroes, list)

        :error ->
          Map.put(tile, :heroes, [])
      end
    end)
  end

  defp destruction(attacker) do
    HeroesRegistry
    |> Registry.select([
      {
        {:"$1", :"$2", :"$3"},
        [
          {:"=/=", :"$1", attacker.name},
          {:map_get, :alive?, :"$3"}
        ],
        [{{:"$2", :"$3"}}]
      }
    ])
    |> Enum.filter(fn {_pid, hero} -> attack_covers?(hero.tile, attacker.tile) end)
    |> Enum.each(fn {pid, _hero} ->
      :ok = HeroServer.kill_hero(pid)
      Process.send_after(self(), {:revive, pid}, :timer.seconds(5))
    end)
  end

  defp grouped_heroes() do
    HeroesRegistry
    |> Registry.select([{{:_, :_, :"$1"}, [], [:"$1"]}])
    |> Enum.group_by(fn hero -> hero.tile end)
  end

  defp traverse(grid, f) do
    grid
    |> Enum.with_index()
    |> Enum.map(fn {row, i} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {tile, j} -> f.(tile, i, j) end)
    end)
  end

  defp get_walkable_tiles(grid) do
    grid
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, i} ->
      row
      |> Enum.with_index()
      |> Enum.reject(fn {tile, _} -> tile.wall? end)
      |> Enum.map(fn {_, j} -> {i, j} end)
    end)
  end

  defp move({i, j}, :up), do: {i - 1, j}
  defp move({i, j}, :down), do: {i + 1, j}
  defp move({i, j}, :left), do: {i, j - 1}
  defp move({i, j}, :right), do: {i, j + 1}

  defp tile_available?({i, j}, _state) when i < 0 or j < 0, do: false
  defp tile_available?(tile, %{walkable_tiles_set: set}), do: MapSet.member?(set, tile)

  defp attack_covers?({i, j}, {attack_i, attack_j}) do
    i <= attack_i + 1 &&
      i >= attack_i - 1 &&
      j <= attack_j + 1 &&
      j >= attack_j - 1
  end

  defp notify_clients(state) do
    world = get_current_world(state)
    :ok = Phoenix.PubSub.broadcast(PubSub, "game", {:update, world})
  end
end
