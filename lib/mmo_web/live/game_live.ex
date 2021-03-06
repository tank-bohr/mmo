defmodule MmoWeb.GameLive do
  use MmoWeb, :live_view

  alias Mmo.GameServer
  alias Faker.Superhero

  require Logger

  @impl true
  def mount(params, _session, socket) do
    name = params["name"] || Superhero.name()
    :ok = GameServer.connect(name)
    {:ok, assign(socket, name: name, world: [])}
  end

  @impl true
  def handle_event("action", %{"key" => "ArrowUp"}, socket) do
    :ok = GameServer.move_hero(socket.assigns.name, :up)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "ArrowDown"}, socket) do
    :ok = GameServer.move_hero(socket.assigns.name, :down)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "ArrowLeft"}, socket) do
    :ok = GameServer.move_hero(socket.assigns.name, :left)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "ArrowRight"}, socket) do
    :ok = GameServer.move_hero(socket.assigns.name, :right)
    {:noreply, socket}
  end

  def handle_event("action", %{"key" => "Enter"}, socket) do
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
