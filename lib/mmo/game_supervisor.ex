defmodule Mmo.GameSupervisor do
  use Supervisor

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children = [
      {Registry, keys: :unique, name: Mmo.HeroesRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Mmo.HeroesSupervisor},
      Mmo.GameServer
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
