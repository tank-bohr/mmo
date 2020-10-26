defmodule Mmo.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      MmoWeb.Telemetry,
      {Phoenix.PubSub, name: Mmo.PubSub},
      MmoWeb.Endpoint,
      Mmo.GameSupervisor
    ]

    opts = [strategy: :one_for_one, name: Mmo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    MmoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
