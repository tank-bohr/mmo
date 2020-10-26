defmodule Mmo.GameServer do
  use GenServer

  alias Mmo.PubSub
  alias Mmo.Hero
  alias Mmo.HeroServer
  alias Mmo.HeroesRegistry

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

  def connect(name) do
    Phoenix.PubSub.subscribe(PubSub, "game")
    GenServer.call(__MODULE__, {:connect, name})
  end

  def move_hero(name, direction) do
    GenServer.call(__MODULE__, {:move, name, direction})
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
  def handle_call({:connect, name}, {client, _}, state) do
    {pid, _hero} = find_or_create_hero(name, state)
    HeroServer.increase_counter(pid, client)
    world = get_current_world(state)
    :ok = notify_clients(world)
    {:reply, world, state}
  end

  def handle_call({:move, name, direction}, _from, state) do
    {pid, hero} = find_hero(name)
    new_tile = move(hero.tile, direction)
    if tile_available?(new_tile, state), do: HeroServer.update_tile(pid, new_tile)
    world = get_current_world(state)
    :ok = notify_clients(world)
    {:reply, world, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    state
    |> get_current_world()
    |> notify_clients()

    {:noreply, state}
  end

  defp find_or_create_hero(name, %{walkable_tiles: walkable_tiles}) do
    case find_hero(name) do
      :not_found ->
        create_hero(name, walkable_tiles)

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

  defp create_hero(name, walkable_tiles) do
    tile = Enum.random(walkable_tiles)
    hero = %Hero{name: name, tile: tile}
    {:ok, pid} = HeroServer.create(hero)
    Process.monitor(pid)
    {pid, hero}
  end

  defp get_current_world(%{grid: grid}) do
    heroes = Enum.group_by(get_heroes(), fn hero -> hero.tile end, fn hero -> hero.name end)

    traverse(grid, fn tile, i, j ->
      case Map.fetch(heroes, {i, j}) do
        {:ok, list} ->
          Map.put(tile, :heroes, list)

        :error ->
          Map.put(tile, :heroes, [])
      end
    end)
  end

  defp get_heroes() do
    Registry.select(HeroesRegistry, [{{:_, :_, :"$1"}, [], [:"$1"]}])
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

  defp notify_clients(world) do
    Phoenix.PubSub.broadcast(PubSub, "game", {:update, world})
  end
end
