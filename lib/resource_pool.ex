defmodule Options do
  @moduledoc false

  @doc """
  List that represents an available option names for new pool creation.
  """
  @spec names :: [
          :fifo
          | :max_active
          | :max_idle
          | :max_idle_time
          | :max_wait
          | :min_idle
          | :test_on_borrow
          | :test_on_return
          | :when_exhausted_action
          | :max_wait
          | :max_idle_time
        ]
  defmacro names do
    [:max_active, :max_idle, :min_idle, :test_on_borrow, :test_on_return, :fifo, :when_exhausted_action, :max_wait, :max_idle_time]
  end
end

defmodule ResourcePool do
  @moduledoc """
  Facade for resource pool.
  """
  require Options

  @doc """
  Creates and runs new generic server for ResourcePool with registered name `pool_name`. The new resource pool will use
  `factory_module` as a resource factory and `resource_metadata` as a metadata to create a new resource.
  """
  @spec new((atom | pid), module(), list()) :: :ignore | {:error, any} | {:ok, pid}
  def new(pool_name, factory_module, resource_metadata) do
    new(pool_name, factory_module, resource_metadata, [])
  end

  @doc """
  Creates and runs new generic server for ResourcePool with registered name `pool_name`. The new resource pool will use
  `factory_module` as a resource factory and `resource_metadata` as a metadata to create a new resource.
  `options` defines behaviour of the pool.
  The available options are:
  * `max_active: integer()` - defines the maximum number of resource instances that can be allocated by the pool at a given time.
    If non-positive, there is no limit to the number of instances that can be managed by the pool at one time.
    When `max_active` is reached, the pool is said to be exhausted.
    The default setting for this parameter is 8.

  * `max_idle: integer()` defines the maximum number of objects that can sit idle in the pool at any time.
    If negative, there is no limit to the number of objects that may be idle at one time.
    The default setting for this parameter equals `max_active`.

  * `min_idle: integer()` defines the minimum number of "sleeping" instances in the pool. Default value is 0.

  * `test_on_borrow: boolean()` If true the pool will attempt to validate each resource before it is returned from the borrow function
    (Using the provided resource factory's validate function).
    Instances that fail to validate will be dropped from the pool, and a different object will
    be borrowed. The default setting for this parameter is `false.`

  * `test_on_return: boolean()` If true the pool will attempt to validate each resource instance before it is returned to the pool in the
    return function (Using the provided resource factory's validate function). Objects that fail to validate
    will be dropped from the pool. The default setting for this option is `false.`

  * `fifo: boolean()` The pool can act as a LIFO queue with respect to idle resource instances
    always returning the most recently used resource from the pool,
    or as a FIFO queue, where borrow always returns the oldest instance from the idle resource list.
    `fifo` determines whether or not the pool returns idle objects in
    first-in-first-out order. The default setting for this parameter is `false.`

  * `when_exhausted_action: (:fail | :block | :grow)` specifies the behaviour of the `borrow` function when the pool is exhausted:
     * `:fail` will return an error.
     * `:block` will block until a new or idle object is available. If a positive `max_wait`
       value is supplied, then `borrow` will block for at most that many milliseconds,
       after which an error will be returned. If `max_wait` is non-positive,
       the `borrow` function will block infinitely.
     * `:grow` will create a new object and return it (essentially making `max_active` meaningless.)
    The default `when_exhausted_action:` setting is `:block` and
    the default `max_wait:` setting is `:infinity`. By default, therefore, `borrow` will
    block infinitely until an idle instance becomes available.

  * `max_wait: (integer() | infinity)` The maximum amount of time to wait when the `borrow` function
    is invoked, the pool is exhausted (the maximum number
    of "active" resource instances has been reached) and `when_exhausted_action:` equals `:block`.

  * `max_idle_time: (integer() | infinity)` The maximum amount of time an resource instance may sit idle in the pool,
    with the extra condition that at least `min_idle` amount of object remain in the pool.
    When infinity, no instances will be evicted from the pool due to maximum idle time limit.
  """
  @spec new((atom | pid), module(), list(), list()) :: :ignore | {:error, any} | {:ok, pid}
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

  # Check `factory_module` if it implements resource_factory behaviour?
  defp factory?(factory_module) do
    moduleInfo = try do
      factory_module.__info__(:attributes)
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

  @doc """
  Borrows resource from pool. Returns resource `pid` for client use.
  """
  @spec borrow(atom | pid) :: pid | {:error, any}
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

  @doc """
  The function sends `resource` to the pool's `idle` container after client does not need it any more.
  """
  @spec return(atom | pid, pid) :: :ok
  def return(pool_name, resource) do
    GenServer.cast(pool_name, {:return, resource, self()})
  end

  @doc """
  Adds one more resource to pool (as an idle resource).
  """
  @spec add(atom | pid) :: :ok
  def add(pool_name) do
    GenServer.cast(pool_name, :add)
  end

  @doc """
  Invalidates resource - makes it ready to dispose.
  """
  @spec invalidate(atom | pid, pid) :: :ok
  def invalidate(pool_name, resource) do
    GenServer.call(pool_name, {:invalidate, resource}, 300000)
  end

  @doc """
  Returns number of active (busy) resources in pool.
  """
  @spec get_num_active(atom | pid) :: integer
  def get_num_active(pool_name) do
    GenServer.call(pool_name, :get_num_active, 300000)
  end

  @doc """
  Returns number of idle (ready to use) resources in pool.
  """
  @spec get_num_idle(atom | pid) :: integer
  def get_num_idle(pool_name) do
    GenServer.call(pool_name, :get_num_idle, 300000)
  end

  @doc """
  Returns total number of resources in pool as a tuple {active, idle}.
  """
  @spec get_number(atom | pid) :: {integer, integer}
  def get_number(pool_name) do
    GenServer.call(pool_name, :get_number, 300000)
  end

  @doc """
  Disposes all resources from the pool.
  """
  @spec clear(atom | pid) :: :ok
  def clear(pool_name) do
    GenServer.cast(pool_name, :clear)
  end

  @doc """
  Disposes all resources from the pool and close the pool (shut down generic server).
  """
  @spec close(atom | pid) :: :ok
  def close(pool_name) do
    GenServer.cast(pool_name, :close)
  end

end

