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

  @tag test_name: :max_active_neg
  test "borrow from pool with negative max_active", %{pid: pool} do
    for _ <- 1..10, do: ResourcePool.borrow(pool)
    rsrc = ResourcePool.borrow(pool)
    assert {11, 0} == ResourcePoolTest.f2(pool)
    assert Process.alive?(rsrc)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :max_idle_neg
  test "borrow from pool with negative max_idle", %{pid: pool} do
    resources = for _ <- 1..10, do: ResourcePool.borrow(pool)
    assert {10, 0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    for r <- resources, do: ResourcePool.return(pool, r)
    assert {0, 10} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    resources1 = for _ <- 1..10, do: ResourcePool.borrow(pool)
    for _ <- 1..10, do: ResourcePool.add(pool)
    assert {10, 10} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    for r <- resources1, do: ResourcePool.return(pool, r)
    assert {0, 20} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :fail_max_active
  test "borrow from pool with fail on max_active", %{pid: pool} do
    ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    ref = ResourcePool.borrow(pool)

    assert {2, 0} == ResourcePoolTest.f2(pool)
    assert {:error, :pool_exhausted} == ref
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :grow_max_active
  test "borrow from pool with grow on max_active", %{pid: pool} do
    ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    rsrc = ResourcePool.borrow(pool)

    assert {3, 0} == ResourcePoolTest.f2(pool)
    assert Process.alive?(rsrc)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :block_max_active
  test "borrow from pool with block on max_active", %{pid: pool} do
    spawn_link(fn() ->
                 rsrc_a = ResourcePool.borrow(pool)
                 Process.sleep(1000)
                 ResourcePool.return(pool, rsrc_a)
               end)
    ResourcePool.borrow(pool)
    rsrc_b = ResourcePool.borrow(pool)
    assert {2, 0} == ResourcePoolTest.f2(pool)
    assert Process.alive?(rsrc_b)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :block_max_wait_timeout
  test "borrow from pool with block on max_wait_timeout", %{pid: pool} do
    ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    ref = ResourcePool.borrow(pool)

    assert {2, 0} == ResourcePoolTest.f2(pool)
    assert {:error, :pool_timeout} == ref
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :block_max_wait
  test "borrow from pool with block on max_wait", %{pid: pool} do
    spawn_link(fn() ->
                 rsrc_a = ResourcePool.borrow(pool)
                 Process.sleep(1000)
                 ResourcePool.return(pool, rsrc_a)
              end)
    ResourcePool.borrow(pool)
    rsrc_b = ResourcePool.borrow(pool)

    assert {2, 0} == ResourcePoolTest.f2(pool)
    assert Process.alive?(rsrc_b)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :test_on
  test "borrow from pool with test on borrow", %{pid: pool} do
      rsrc = ResourcePool.borrow(pool)
      TestResource.set_valid(rsrc, false)
      ResourcePool.return(pool, rsrc)
      assert {0,1} == ResourcePoolTest.f2(pool)
      ResourcePoolTest.check_activate_passivate(pool)
      rsrc1 = ResourcePool.borrow(pool)
      assert Process.alive?(rsrc1)
      assert not TestResource.valid?(rsrc1)
      assert {1,0} == ResourcePoolTest.f2(pool)
      ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :block_test_on
  test "borrow from pool with block on test on borrow", %{pid: pool} do
    spawn_link(fn() ->
                 rsrc_a = ResourcePool.borrow(pool)
                 TestResource.set_id(rsrc_a, 7)
                 TestResource.set_valid(rsrc_a, false)
                 Process.sleep(100)
                 ResourcePool.return(pool, rsrc_a)
               end)
    ResourcePool.borrow(pool)
    rsrc_b = ResourcePool.borrow(pool)
    assert {2, 0} == ResourcePoolTest.f2(pool)
    assert Process.alive?(rsrc_b)
    assert not TestResource.valid?(rsrc_b)
    assert 7 == TestResource.get_id(rsrc_b)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :test_on_true
  test "borrow from pool with test on true", %{pid: pool} do
    rsrc = ResourcePool.borrow(pool)
    TestResource.set_valid(rsrc, false)
    TestResource.set_id(rsrc, 7)
    ResourcePool.return(pool, rsrc)
    assert {0,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
    rsrc1 = ResourcePool.borrow(pool)
    assert Process.alive?(rsrc1)
    assert 7 != TestResource.get_id(rsrc1)
    assert not Process.alive?(rsrc)
    assert {1,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :block_test_on_true
  test "borrow from pool with block on test on = true", %{pid: pool} do
    spawn_link(fn() ->
                 rsrc_d = ResourcePool.borrow(pool)
                 TestResource.set_id(rsrc_d, 7)
                 TestResource.set_valid(rsrc_d, false)
                 Process.sleep(100)
                 ResourcePool.return(pool, rsrc_d)
              end)
    ResourcePool.borrow(pool)
    rsrc_e = ResourcePool.borrow(pool)
    assert {1, 0} == ResourcePoolTest.f2(pool)
    assert {:error, :pool_timeout} == rsrc_e
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :lifo
  test "borrow from pool with lifo", %{pid: pool} do
    rsrc = ResourcePool.borrow(pool)
    assert is_pid(rsrc)
    TestResource.set_id(rsrc, 0)
    assert 1 == ResourcePoolTest.f(pool)
    assert {1,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc)
    assert 1 == ResourcePoolTest.f(pool)
    assert {0,1} == ResourcePoolTest.f2(pool)
    rsrc0 = ResourcePool.borrow(pool)
    assert 0 == TestResource.get_id(rsrc0)
    rsrc1 = ResourcePool.borrow(pool)
    TestResource.set_id(rsrc1, 1)
    rsrc2 = ResourcePool.borrow(pool)
    TestResource.set_id(rsrc2, 2)
    rsrc3 = ResourcePool.borrow(pool)
    TestResource.set_id(rsrc3, 3)
    assert 4 == ResourcePoolTest.f(pool)
    assert {4,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc1)
    assert 4 == ResourcePoolTest.f(pool)
    assert {3,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc1)
    assert 4 == ResourcePoolTest.f(pool)
    assert {3,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc0)
    assert 4 == ResourcePoolTest.f(pool)
    assert {2,2} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    rsrc5 = ResourcePool.borrow(pool)
    assert 4 == ResourcePoolTest.f(pool)
    assert {3,1} == ResourcePoolTest.f2(pool)
    assert 0 == TestResource.get_id(rsrc5)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.invalidate(pool, rsrc2)
    assert 3 == ResourcePoolTest.f(pool)
    assert {2,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.clear(pool)
    assert 0 == ResourcePoolTest.f(pool)
    assert {0,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)
  end

  @tag test_name: :fifo
  test "borrow from pool with fifo", %{pid: pool} do
    rsrc = ResourcePool.borrow(pool)
    assert is_pid(rsrc)
    TestResource.set_id(rsrc, 0)
    assert 1 == ResourcePoolTest.f(pool)
    assert {1,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc)
    assert 1 == ResourcePoolTest.f(pool)
    assert {0,1} == ResourcePoolTest.f2(pool)
    rsrc0 = ResourcePool.borrow(pool)
    assert 0 == TestResource.get_id(rsrc0)
    rsrc1 = ResourcePool.borrow(pool)
    TestResource.set_id(rsrc1, 1)
    rsrc2 = ResourcePool.borrow(pool)
    TestResource.set_id(rsrc2, 2)
    rsrc3 = ResourcePool.borrow(pool)
    TestResource.set_id(rsrc3, 3)
    assert 4 == ResourcePoolTest.f(pool)
    assert {4,0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc1)
    assert 4 == ResourcePoolTest.f(pool)
    assert {3,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc1)
    assert 4 == ResourcePoolTest.f(pool)
    assert {3,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.return(pool, rsrc0)
    assert 4 == ResourcePoolTest.f(pool)
    assert {2,2} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    rsrc5 = ResourcePool.borrow(pool)
    assert 4 == ResourcePoolTest.f(pool)
    assert {3,1} == ResourcePoolTest.f2(pool)
    assert 1 == TestResource.get_id(rsrc5)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.invalidate(pool, rsrc2)
    assert 3 == ResourcePoolTest.f(pool)
    assert {2,1} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

    ResourcePool.clear(pool)
    assert 0 == ResourcePoolTest.f(pool)
    assert {0, 0} == ResourcePoolTest.f2(pool)
    ResourcePoolTest.check_activate_passivate(pool)

  end

end
