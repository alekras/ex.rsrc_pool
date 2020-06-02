defmodule AddResourcePoolTest do
  use ExUnit.Case, async: false

  def set(:add), do: []
  def set(:add_max_idle), do: [max_active: 2, max_idle: 2]
  def set(:add_max_idle_neg), do: [max_idle: -1]
  def set(_), do: []

  setup %{test_name: testName} do
    options = set(testName)
    {:ok, pid} = ResourcePool.new(:test_pool, Factory, 0, options)
    [pid: pid]
  end

  @tag test_name: :add
  test "add", %{pid: pool} do
    ResourcePool.borrow(pool)
    ResourcePool.add(pool)
    assert 2 == ResourcePoolTest.f(pool)
    assert {1,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.borrow(pool)
    assert {2,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :add_max_idle
  test "add with max idle", %{pid: pool} do
    r1 = ResourcePool.borrow(pool)
    r2 = ResourcePool.borrow(pool)
    ResourcePool.return(pool, r1)
    ResourcePool.return(pool, r2)
    assert 2 == ResourcePoolTest.f(pool)
    assert {0,2} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.add(pool)
    assert 2 == ResourcePoolTest.f(pool)
    assert {0,2} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :add_max_idle_neg
  test "add with negative max idle", %{pid: pool} do
    for _x <- 1..10, do: ResourcePool.add(pool)
    assert {0, 10} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    for _x <- 1..10, do: ResourcePool.add(pool)
    assert {0, 20} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
  end

end
