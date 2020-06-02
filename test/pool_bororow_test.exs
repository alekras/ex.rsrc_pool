defmodule BorrowResourcePoolTest do
  use ExUnit.Case, async: false

  def set(:min_idle), do: [max_active: 4, min_idle: 2, when_exhausted_action: :fail]
  def set(:max_active_neg), do: [max_active: -1, when_exhausted_action: :fail]
  def set(:max_idle_neg), do: [max_idle: -1, when_exhausted_action: :grow]
  def set(:fail_max_active), do: [max_active: 2, when_exhausted_action: :fail]
  def set(:grow_max_active), do: [max_active: 2, when_exhausted_action: :grow]
  def set(:block_max_active), do: [max_active: 2, when_exhausted_action: :block]
  def set(:block_max_wait_timeout), do: [max_active: 2, when_exhausted_action: :block, max_wait: 2000]
  def set(:block_max_wait), do: [max_active: 2, when_exhausted_action: :block, max_wait: 2000]
  def set(:test_on), do: []
  def set(:block_test_on), do: [max_active: 2, when_exhausted_action: :block, max_wait: 200]
  def set(:test_on_true), do: [test_on_borrow: true]
  def set(:block_test_on_true), do: [max_active: 2, test_on_borrow: true, when_exhausted_action: :block, max_wait: 200]
  def set(:lifo), do: []
  def set(:fifo), do: [fifo: true]
  def set(_), do: []

  setup %{test_name: testName} do
    options = set(testName)
    {:ok, pid} = ResourcePool.new(:test_pool, Factory, 0, options)
    [pid: pid]
  end

  @tag test_name: :min_idle
  test "borrow from pool with min_idle", %{pid: pool} do
    ResourcePool.borrow(pool)
    assert {1, 2} == ResourcePoolTest.f2(pool)
    ResourcePool.borrow(pool)
    assert {2, 2} == ResourcePoolTest.f2(pool)
    ResourcePool.borrow(pool)
    assert {3, 2} == ResourcePoolTest.f2(pool)
    ResourcePool.borrow(pool)
    assert {4, 2} == ResourcePoolTest.f2(pool)
    ref = ResourcePool.borrow(pool)
    assert {4, 2} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
    assert {:error, :pool_exhausted} == ref
  end

  @tag test_name: :max_idle_neg
  test "borrow from pool with negative max_idle", %{pid: pool} do
    for _ <- 1..10, do: ResourcePool.borrow(pool)
    rsrc = ResourcePool.borrow(pool)
    assert {11, 0} == ResourcePoolTest.f2(pool)
    assert Process.alive?(rsrc)
    ResourcePoolTest.check_activate_passivate(pool)
  end

end
