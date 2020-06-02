defmodule NewResourcePoolTest do
  use ExUnit.Case, async: false

  def set(:default), do: {Factory, []}
  def set(:custom) do
    {Factory,
     [max_active: 16,
      max_idle: 12,
      min_idle: 3,
      test_on_borrow: true,
      test_on_return: true,
      fifo: true,
      when_exhausted_action: :grow,
      max_wait: 2500
      ]
    }
  end
  def set(:factory_not_exist), do: {Factory_1, []}
  def set(:not_factory), do: {NotFactory, []}
  def set(:wrong_option), do: {Factory, [wrong_option: 0, opt: 0, max_idle: 4]}
  def set(_), do: {Factory, []}

  setup %{test_name: testName} do
    {factory, options} = set(testName)
    r = case options do
      [] -> ResourcePool.new(:test_pool, factory, 0)
      _  -> ResourcePool.new(:test_pool, factory, 1, options)
    end
    case r do
      {:ok, pid} -> [pid: pid]
      {:error, _} -> [pid: r]
    end
  end

  @tag test_name: :default
  test "new default pool", %{pid: pool} do
    assert is_pid(pool)
    assert Process.alive?(pool)
    state = GenServer.call(pool, :get_state)

    assert %PoolState{active: [], idle: [], waiting: [], max_active: 8, max_idle: 8,
    min_idle: 0, test_on_borrow: false, test_on_return: false, fifo: false,
    when_exhausted_action: :block, max_wait: :infinity, max_idle_time: :infinity,
    factory_module: Factory, resource_metadata: 0}
    == state
  end

  @tag test_name: :custom
  test "new custom pool", %{pid: pool} do
    assert is_pid(pool)
    assert Process.alive?(pool)
    state = GenServer.call(pool, :get_state)

    assert %PoolState{active: [], idle: [], waiting: [], max_active: 16, max_idle: 12,
    min_idle: 3, test_on_borrow: true, test_on_return: true, fifo: true,
    when_exhausted_action: :grow, max_wait: 2500, max_idle_time: :infinity,
    factory_module: Factory, resource_metadata: 1}
    == state
  end

  @tag test_name: :factory_not_exist
  test "new pool with error: factory not exist", %{pid: pool} do
    assert {:error, :factory_does_not_exist} == pool
  end

  @tag test_name: :not_factory
  test "new pool with error: not factory", %{pid: pool} do
    assert {:error, :not_factory} == pool
  end

  @tag test_name: :wrong_option
  test "new pool with error: wrong options", %{pid: pool} do
    assert {:error, "Wrong options: wrong_option, opt"} == pool
  end

end
