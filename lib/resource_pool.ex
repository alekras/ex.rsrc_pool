defmodule Options do
  defmacro names do
    [:max_active, :max_idle, :min_idle, :test_on_borrow, :test_on_return, :fifo, :when_exhausted_action, :max_wait, :max_idle_time]
  end
end

defmodule ResourcePool do
  @moduledoc """
  Documentation for ResourcePool.
  """
  require Options

  @doc """
  """
  def new(pool_name, factory_module, resource_metadata) do
    new(pool_name, factory_module, resource_metadata, [])
  end

  @doc """
  """
  def new(pool_name, factory_module, resource_metadata, options) do
    failedOptions =
    for {key, _} <- options, not Enum.member?(Options.names, key) do
      key
    end
    case failedOptions do
      [] ->
        case factory?(factory_module) do
          true ->
            GenServer.start_link(ResourcePool.GenServer,
              {options, factory_module, resource_metadata}, [timeout: 300000, name: pool_name])
          {:error, _} = er -> er
        end
      t ->
        {:error, "Wrong options: " <> Enum.join(Enum.map(t, fn(key) -> Atom.to_string(key) end), ", ")}
    end
  end

  defp factory?(factory_module) do
    moduleInfo = try do
      apply(factory_module, :__info__, [:attributes])
    rescue _ -> []
    end
    case moduleInfo do
      [] -> {:error, :factory_does_not_exist}
      _  ->
        behaviours = Keyword.get(moduleInfo, :behaviour, [])
        case Enum.member?(behaviours, ResourceFactory) do
          true -> true
          false -> {:error, :not_factory}
        end
    end
  end

  def borrow(pool_name) do
    case GenServer.call(pool_name, :borrow, 300000) do
      {:ok, resource} -> resource
      {:error, _} = r -> r
      {:wait, max_wait} ->
        recv =
        receive do
          {:ok, pid} -> pid
        after max_wait -> {:error, :pool_timeout}
        end
        GenServer.call(pool_name, {:ack_borrow, recv}, 300000)
        # flush message that probably came to the mailbox after timeout
        receive do
          {:ok, _} -> :ok
        after 0 -> :ok
        end
        recv
    end
  end

  def return(pool_name, resource) do
    GenServer.cast(pool_name, {:return, resource, self()})
  end

  def add(pool_name) do
    GenServer.cast(pool_name, :add)
  end

  def invalidate(pool_name, resource) do
    GenServer.call(pool_name, {:invalidate, resource}, 300000)
  end

  def get_num_active(pool_name) do
    GenServer.call(pool_name, :get_num_active, 300000)
  end

  def get_num_idle(pool_name) do
    GenServer.call(pool_name, :get_num_idle, 300000)
  end

  def get_number(pool_name) do
    GenServer.call(pool_name, :get_number, 300000)
  end

  def clear(pool_name) do
    GenServer.cast(pool_name, :clear)
  end

  def close(pool_name) do
    GenServer.cast(pool_name, :close)
  end

end

