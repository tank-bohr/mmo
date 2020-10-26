defmodule MmoWeb.GameLive do
  use MmoWeb, :live_view

  alias Mmo.GameServer

  require Logger

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    {:ok, assign(socket, name: name, world: GameServer.connect(name))}
  end

  @impl true
  def handle_event("action", %{"key" => "ArrowUp"}, socket) do
    Logger.debug("up")
    {:noreply, assign(socket, :world, GameServer.move_hero(socket.assigns.name, :up))}
  end

  def handle_event("action", %{"key" => "ArrowDown"}, socket) do
    Logger.debug("down")
    {:noreply, assign(socket, :world, GameServer.move_hero(socket.assigns.name, :down))}
  end

  def handle_event("action", %{"key" => "ArrowLeft"}, socket) do
    Logger.debug("left")
    {:noreply, assign(socket, :world, GameServer.move_hero(socket.assigns.name, :left))}
  end

  def handle_event("action", %{"key" => "ArrowRight"}, socket) do
    Logger.debug("right")
    {:noreply, assign(socket, :world, GameServer.move_hero(socket.assigns.name, :right))}
  end

  def handle_event("action", %{"key" => "Space"}, socket) do
    Logger.debug("attack")
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update, world}, socket) do
    {:noreply, assign(socket, :world, world)}
  end
end
