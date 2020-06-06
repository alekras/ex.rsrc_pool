defmodule TestResourceState do
  defstruct valid: true,
    active: false,
    id: 0
end

defmodule TestResource do
  use GenServer

  def create() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def set_id(pid, id) do
    GenServer.call(pid, {:set_id, id})
  end

  def get_id(pid) do
    GenServer.call(pid, :get_id)
  end

  def set_valid(pid, valid) do
    GenServer.call(pid, {:set_valid, valid})
  end

  def valid?(pid) do
    GenServer.call(pid, :is_valid)
  end

  def set_active(pid, active) do
    GenServer.call(pid, {:set_active, active})
  end

  def active?(pid) do
    GenServer.call(pid, :is_active)
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

## Gen Server Callbacks:
  @impl true
  def init([]) do
    {:ok, %TestResourceState{}}
  end

  @impl true
  def handle_call(:is_valid, _from, state) do
    {:reply, state.valid, state}
  end

  def handle_call(:is_active, _from, state) do
    {:reply, state.active, state}
  end

  def handle_call(:get_id, _from, state) do
    {:reply, state.id, state}
  end

  def handle_call({:set_id, id}, _from, state) do
    {:reply, id, %TestResourceState{state | id: id}}
  end

  def handle_call({:set_valid, valid}, _from, state) do
    {:reply, valid, %TestResourceState{state | valid: valid}}
  end

  def handle_call({:set_active, active}, _from, state) do
    {:reply, active, %TestResourceState{state | active: active}}
  end

  def handle_call(_, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

end
