defmodule PoolState do
  defstruct active: [],
            idle: [],
            waiting: [],
            max_active: 8,
            max_idle: 8,
            min_idle: 0,
            test_on_borrow: false,
            test_on_return: false,
            fifo: false,
            when_exhausted_action: :block, # :fail | :grow | :block
            max_wait: :infinity, # integer() | :infinity,
            max_idle_time: :infinity, # integer() | :infinity,
            factory_module: nil,
            resource_metadata: nil
end

defmodule ResourcePool.GenServer do
  @moduledoc """
  Documentation for ResourcePool.GenServer.
  """
  use GenServer

  @doc """
  """
  @impl true
  def init({options, factory_module, resource_metadata}) do
    max_active = Keyword.get(options, :max_active, 8)
    state = %PoolState{
      max_active: max_active,
      max_idle: Keyword.get(options, :max_idle, max_active),
      min_idle: Keyword.get(options, :min_idle, 0),
      max_wait: Keyword.get(options, :max_wait, :infinity),
      max_idle_time: Keyword.get(options, :max_idle_time, :infinity),
      when_exhausted_action: Keyword.get(options, :when_exhausted_action, :block),
      test_on_borrow: Keyword.get(options, :test_on_borrow, false),
      test_on_return: Keyword.get(options, :test_on_return, false),
      fifo: Keyword.get(options, :fifo, false),
      factory_module: factory_module,
      resource_metadata: resource_metadata
    }
    {:ok, state}
  end

  @doc """
  """
  @impl true
  def handle_call(:borrow, from, %PoolState{active: active, idle: idle} = state) do
    num_active = length(active)
    num_idle = length(idle)
    process_borrow(from, state, num_active, num_idle)
  end

  def handle_call({:ack_borrow, {:error, :pool_timeout}}, {waiting_client, _}, %PoolState{active: active, waiting: waiting} = state) do
    case List.keytake(active, {:tmp, waiting_client}, 1) do
      nil -> {:reply, :ok, %PoolState{state | waiting: List.delete(waiting, waiting_client)}} # pure timeout
      {{resource, _}, new_active} -> {:reply, :ok, %PoolState{state | active: new_active, idle: add_to_idle(resource, state)}}
    end
  end

  def handle_call({:ack_borrow, resource}, {waiting_client, _}, %PoolState{active: active} = state) do
    #  io:format(user, " >>> resource_pool_srv:handle_call(ack_borrow, ..) from: ~p receive:~p active:~p~n", [Waiting_client, Receive, Active]),
    {:reply, :ok, %PoolState{state | active: List.keyreplace(active, {:tmp, waiting_client}, 1, {resource, waiting_client})}}
  end

  def handle_call(:get_all_resources, _from, state) do
    {:reply, Enum.map(state.active ++ state.idle, fn({r, _}) -> r end), state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_number, _from, %PoolState{active: active, idle: idle} = state) do
    {:reply, length(active) + length(idle), state}
  end

  def handle_call(:get_num_active, _from, %PoolState{active: active} = state) do
    {:reply, length(active), state}
  end

  def handle_call(:get_num_idle, _from, %PoolState{idle: idle} = state) do
    {:reply, length(idle), state}
  end

  def handle_call({:invalidate, resource}, {requester, _}, %PoolState{active: active, factory_module: factory_mod, resource_metadata: rsrc_MD} = state) do
    case List.keyfind(active, resource, 0) do
      {resource, owner} when requester === owner ->
        factory_mod.destroy(rsrc_MD, resource)
        {:reply, :ok, %PoolState{state | active: List.keydelete(active, resource, 0)}}
      {_, _} -> {:reply, {:error, :not_owner}, state}
      nil  -> {:reply, {:error, :not_active}, state}
    end
  end

  @impl true
  def handle_cast({:return, resource, requester}, state) do
    %PoolState{active: active, idle: idle, factory_module: factory_mod, resource_metadata: rsrc_MD, waiting: waiting} = state
    resource_tuple = List.keyfind(active, resource, 0)
#  :io.format(:user, "~n >>> resource_pool_srv.handle_cast(:return, ..): {~p, ~p} {rsrc, owner}:~p req-er:~p ~p~n", [length(active), length(idle), resource_tuple, requester, waiting])
    case resource_tuple do
      nil -> {:noreply, state}
      {resource, owner} when owner == requester ->
        case waiting do
          [] ->
            new_idle =
            case ((not state.test_on_return) or factory_mod.validate(rsrc_MD, resource))
                 and ((state.max_idle < 0) or (length(idle) < state.max_idle)) do
              true -> add_to_idle(resource, state)
              false ->
                factory_mod.destroy(rsrc_MD, resource)
                idle
            end
            {:noreply, %PoolState{state | active: List.keydelete(active, resource, 0), idle: new_idle}};
          _ ->
            {others, [waiting_client]} = Enum.split(waiting, length(waiting) - 1)
            case (not state.test_on_borrow) or factory_mod.validate(rsrc_MD, resource) do
              true ->
                factory_mod.passivate(rsrc_MD, resource)
                factory_mod.activate({rsrc_MD, waiting_client}, resource)
                send(waiting_client, {:ok, resource})
                {:noreply, %PoolState{state | active: List.keyreplace(active, resource, 0, {resource, {:tmp, waiting_client}}), waiting: others}};
              false ->
                factory_mod.destroy(rsrc_MD, resource)
                {:noreply, %PoolState{state | active: List.keydelete(active, resource, 0)}}
            end
        end
      {_, _} -> {:noreply, state}
    end
  end

  def handle_cast(:add, %PoolState{idle: idle, factory_module: factory_mod, resource_metadata: rsrc_MD} = state) do
    case ((state.max_idle < 0) or (length(idle) < state.max_idle)) do
      true ->
        case factory_mod.create(rsrc_MD) do
          {:ok, resource} ->
            {:noreply, %PoolState{state | idle: add_to_idle(resource, state)}}
          {:error, _err} ->
            {:noreply, state}
        end
      false -> {:noreply, state}
    end
  end

  def handle_cast({:remove, {resource, _}}, %PoolState{idle: idle, factory_module: factory_mod} = state) do
    if length(idle) <= state.min_idle do
      {:noreply, state}
    else
      case List.keytake(idle, resource, 0) do
        nil ->
          {:noreply, state}
        {_, new_idle} ->
          factory_mod.destroy(state.resource_metadata, resource)
          {:noreply, %PoolState{state | idle: new_idle}}
      end
    end
  end

  def handle_cast(:clear, %PoolState{active: active, idle: idle, factory_module: factory_mod, resource_metadata: rsrc_MD} = state) do
    for {rsrc, _} <- active, do: factory_mod.destroy(rsrc_MD, rsrc)
    for {rsrc, pid} <- idle do
      send(pid, :cancel)
      factory_mod.destroy(rsrc_MD, rsrc)
    end
    {:noreply, %PoolState{state | active: [], idle: []}}
  end

  def handle_cast(:close, %PoolState{active: active, idle: idle, factory_module: factory_mod, resource_metadata: rsrc_MD} = state) do
    for {rsrc, _} <- active, do: factory_mod.destroy(rsrc_MD, rsrc)
    for {rsrc, pid} <- idle do
      send(pid, :cancel)
      factory_mod.destroy(rsrc_MD, rsrc)
    end
    {:stop, :normal, state}
  end

  defp add_to_idle(resource, %PoolState{idle: idle, factory_module: factory_mod, resource_metadata: rsrc_MD} = state) do
    factory_mod.passivate(rsrc_MD, resource)
    self = self()
    pid = spawn_link(fn() ->
      receive do
        :cancel -> :ok
      after state.max_idle_time ->
        GenServer.cast(self, {:remove, {resource, self()}})
      end
    end)
    [{resource, pid} | idle]
  end

  @doc """
  """
  defp process_borrow({owner, _},
                      %PoolState{waiting: waiting, when_exhausted_action: action, max_active: max_active, } = state,
                      num_active, _num_idle)
    when (max_active > 0)
      and ((num_active >= max_active)
      and (action != :grow))
    do
      case action do
        :fail -> {:reply, {:error, :pool_exhausted}, state};
        :block ->
          case Enum.member?(waiting, owner) do
            true  -> {:reply, {:wait, state.max_wait}, state};
            false -> {:reply, {:wait, state.max_wait}, %PoolState{state | waiting: [owner | waiting]}}
          end
      end
  end

  defp process_borrow({owner, _} = from, %PoolState{active: active, factory_module: factory_mod, min_idle: min_idle, resource_metadata: rsrc_MD} = state, _num_active, num_idle)
    when num_idle <= min_idle
    do
      case factory_mod.create(rsrc_MD) do
        {:ok, resource} when (num_idle == min_idle) ->
          factory_mod.activate({rsrc_MD, owner}, resource)
          {:reply, {:ok, resource}, %PoolState{state | active: [{resource, owner} | active]}}
        {:ok, resource} ->
          handle_call(:borrow, from, %PoolState{state | idle: add_to_idle(resource, state)})
        {:error, err} ->
          {:reply, {:error, err}, state}
      end
  end

  defp process_borrow({owner, _} = from, %PoolState{active: active, idle: idle, factory_module: factory_mod, resource_metadata: rsrc_MD} = state, _num_active, num_idle) do
    {resource, pid, new_idle} =
      case state.fifo do
        false  ->
          [{rsrc, p} | n_idle] = idle
          {rsrc, p, n_idle}
        true ->
          {n_idle, [{rsrc, p}]} = Enum.split(idle, num_idle - 1) # lists:split(num_idle - 1, idle)
          {rsrc, p, n_idle}
      end
    send(pid, :cancel)
    case (not state.test_on_borrow) or factory_mod.validate(rsrc_MD, resource) do
      true ->
        factory_mod.activate({rsrc_MD, owner}, resource)
        {:reply, {:ok, resource}, %PoolState{state | idle: new_idle, active: [{resource, owner} | active]}}
      false ->
        factory_mod.destroy(rsrc_MD, resource)
        handle_call(:borrow, from, %PoolState{state | idle: new_idle})
    end
  end

end
