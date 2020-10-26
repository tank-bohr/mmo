defmodule MmoWeb.GameLive do
  use MmoWeb, :live_view

  alias Mmo.GameServer

  require Logger

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    :ok = GameServer.connect(name)
    {:ok, assign(socket, name: name, world: [])}
  end

  @impl true
  def handle_event("action", %{"key" => "ArrowUp"}, socket) do
    Logger.debug("up")
    :ok = GameServer.move_hero(socket.assigns.name, :up)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "ArrowDown"}, socket) do
    Logger.debug("down")
    :ok = GameServer.move_hero(socket.assigns.name, :down)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "ArrowLeft"}, socket) do
    Logger.debug("left")
    :ok = GameServer.move_hero(socket.assigns.name, :left)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "ArrowRight"}, socket) do
    Logger.debug("right")
    :ok = GameServer.move_hero(socket.assigns.name, :right)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "Enter"}, socket) do
    Logger.debug("attack")
    :ok = GameServer.attack(socket.assigns.name)
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
