defmodule Mmo.HeroServer do
  use GenServer, restart: :transient

  alias Mmo.Hero
  alias Mmo.HeroesRegistry
  alias Mmo.HeroesSupervisor

  def create(hero) do
    DynamicSupervisor.start_child(HeroesSupervisor, {__MODULE__, hero})
  end

  def start_link(hero) do
    GenServer.start_link(__MODULE__, hero)
  end

  def update_tile(pid, tile) do
    GenServer.call(pid, {:update_tile, tile})
  end

  def kill_hero(pid) do
    GenServer.call(pid, :kill_hero)
  end

  def revive_hero(pid, tile) do
    GenServer.call(pid, {:revive_hero, tile})
  end

  def increase_counter(pid, client) do
    GenServer.call(pid, {:increase_counter, client})
  end

  @impl true
  def init(hero) do
    {:ok, _} = Registry.register(HeroesRegistry, hero.name, hero)
    {:ok, %{hero: hero, counter: 0}}
  end

  @impl true
  def handle_call({:increase_counter, client}, _from, %{counter: counter} = state) do
    Process.monitor(client)
    {:reply, :ok, %{state | counter: counter + 1}}
  end

  def handle_call({:revive_hero, tile}, _from, %{hero: %Hero{name: name}} = state) do
    {_, hero} =
      Registry.update_value(HeroesRegistry, name, fn prev ->
        %Hero{prev | alive?: true, tile: tile}
      end)

    {:reply, :ok, %{state | hero: hero}}
  end

  def handle_call(_request, _from, %{hero: %Hero{alive?: false}} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:update_tile, tile}, _from, %{hero: %Hero{name: name}} = state) do
    {_, hero} =
      Registry.update_value(HeroesRegistry, name, fn prev ->
        %Hero{prev | tile: tile}
      end)

    {:reply, :ok, %{state | hero: hero}}
  end

  def handle_call(:kill_hero, _from, %{hero: %Hero{name: name}} = state) do
    {_, hero} =
      Registry.update_value(HeroesRegistry, name, fn prev ->
        %Hero{prev | alive?: false}
      end)

    {:reply, :ok, %{state | hero: hero}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _client, _reason}, %{counter: counter} = state) do
    case %{state | counter: counter - 1} do
      %{counter: count} = new_state when count > 0 ->
        {:noreply, new_state}

      new_state ->
        {:stop, :normal, new_state}
    end
  end
end
