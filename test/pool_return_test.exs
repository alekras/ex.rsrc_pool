defmodule ReturnResourcePoolTest do
  use ExUnit.Case, async: false

  def check_activate_passivate(pool) do
    state = GenServer.call(pool, :get_state)
    for {rsrc, _} <- state.active, do: assert TestResource.active?(rsrc)
    for {rsrc, _} <- state.idle, do: assert not TestResource.active?(rsrc)
  end

  def set(:test_on), do: []
  def set(:test_on_true), do: [test_on_return: true]
  def set(:max_idle_time), do: [max_active: 2, max_idle_time: 200]
  def set(:max_idle_time_min_idle), do: [max_active: 2, max_idle: 8, min_idle: 2, max_idle_time: 200]
  def set(:max_idle_neg), do: [max_active: -1, max_idle: -1]
  def set(_), do: []

  setup %{test_name: testName} do
    options = set(testName)
    {:ok, pid} = ResourcePool.new(:test_pool, Factory, 0, options)
    [pid: pid]
  end

  @tag test_name: :max_idle_time
  test "return to pool with max_idle_time", %{pid: pool} do
    ResourcePool.borrow(pool)
    assert {1, 0} == Utils.f2(pool)
    ref_a = ResourcePool.borrow(pool)
    TestResource.set_id(ref_a, 7)
    assert {2, 0} == Utils.f2(pool)
    check_activate_passivate(pool)

    ResourcePool.return(pool, ref_a)
    assert Process.alive?(ref_a)
    assert {1, 1} == Utils.f2(pool)
    check_activate_passivate(pool)
    Process.sleep(250)
    assert {1, 0} == Utils.f2(pool)
    assert not Process.alive?(ref_a)
    check_activate_passivate(pool)
  end

  @tag test_name: :max_idle_time_min_idle
  test "return to pool with max_idle_time and min_idle", %{pid: pool} do
    ResourcePool.borrow(pool)
    assert {1, 2} == Utils.f2(pool)
    ref_a = ResourcePool.borrow(pool)
    assert {2, 2} == Utils.f2(pool)
    check_activate_passivate(pool)
    ResourcePool.return(pool, ref_a)
    assert {1, 3} == Utils.f2(pool)
    check_activate_passivate(pool)
    Process.sleep(250)
    assert {1, 2} == Utils.f2(pool)
    check_activate_passivate(pool)
  end

  @tag test_name: :max_idle_neg
  test "return to pool with negative max_idle", %{pid: pool} do
    resources = for _x <- 1..20, do: ResourcePool.borrow(pool)
    assert {20, 0} == Utils.f2(pool)
    check_activate_passivate(pool)
    for r <- resources, do: ResourcePool.return(pool, r)
    assert {0, 20} == Utils.f2(pool)
    check_activate_passivate(pool)
  end

  @tag test_name: :test_on
  test "return to pool with test_on", %{pid: pool} do
    rsrc = ResourcePool.borrow(pool)
    TestResource.set_valid(rsrc, false)
    ResourcePool.return(pool, rsrc)
    assert {0,1} == Utils.f2(pool)
    check_activate_passivate(pool)
    rsrc1 = ResourcePool.borrow(pool)
    assert Process.alive?(rsrc1)
    assert not TestResource.valid?(rsrc1)
    assert {1,0} == Utils.f2(pool)
    check_activate_passivate(pool)
  end

  @tag test_name: :test_on_true
  test "return to pool with test_on = true", %{pid: pool} do
    rsrc = ResourcePool.borrow(pool)
    TestResource.set_valid(rsrc, false)
    TestResource.set_id(rsrc, 7)
    ResourcePool.return(pool, rsrc)
    assert {0,0} == Utils.f2(pool)
    check_activate_passivate(pool)
    rsrc1 = ResourcePool.borrow(pool)
    assert Process.alive?(rsrc1)
    assert not Process.alive?(rsrc)
    assert 7 != TestResource.get_id(rsrc1)
    assert {1,0} == Utils.f2(pool)
    check_activate_passivate(pool)
  end

  @tag test_name: :owner
  test "return to pool with owner", %{pid: pool} do
    ResourcePool.borrow(pool)
    rsrc = ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    assert {4,0} == Utils.f2(pool)
    check_activate_passivate(pool)
    ResourcePool.return(pool, rsrc)
    assert {3,1} == Utils.f2(pool)
    ResourcePool.return(pool, Rsrc)
    assert {3,1} == Utils.f2(pool)
    check_activate_passivate(pool)

    self = self()
    spawn_link(fn() ->
                 rsrc1 = ResourcePool.borrow(pool)
                 send self, rsrc1
               end)
    receive do
      pid ->
        assert {4,0} == Utils.f2(pool)
        ResourcePool.return(pool, pid)
        assert {4,0} == Utils.f2(pool)
    end
    check_activate_passivate(pool)
  end

end
