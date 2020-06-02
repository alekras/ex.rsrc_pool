defmodule ResourcePoolTest do
  use ExUnit.Case, async: false

  def f(pool), do: ResourcePool.get_number(pool)

  def f2(pool), do: {ResourcePool.get_num_active(pool), ResourcePool.get_num_idle(pool)}

  def check_activate_passivate(pool) do
    state = GenServer.call(pool, :get_state)
    for {rsrc, _} <- state.active, do: assert TestResource.active?(rsrc)
    for {rsrc, _} <- state.idle, do: assert not TestResource.active?(rsrc)
  end

  setup do
    {:ok, pid} = ResourcePool.new(:test_pool, Factory, 0, [])
    [pid: pid]
  end

  test "pool", context do
    pool = context[:pid]
    rsrc = ResourcePool.borrow(pool)
    assert 1 == f(pool)
    assert {1, 0} == f2(pool)

    ResourcePool.return(pool, rsrc)
    assert 1 == f(pool)
    assert {0, 1} == f2(pool)

    rsrc1 = ResourcePool.borrow(pool)
    rsrc2 = ResourcePool.borrow(pool)
    rsrc3 = ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    assert 4 == f(pool)
    assert {4, 0} == f2(pool)

    ResourcePool.return(pool, rsrc1)
    assert 4 == f(pool)
    assert {3, 1} == f2(pool)

    ResourcePool.return(pool, rsrc1)
    assert 4 == f(pool)
    assert {3, 1} == f2(pool)

    ResourcePool.return(pool, rsrc2)
    assert 4 == f(pool)
    assert {2, 2} == f2(pool)

    ResourcePool.invalidate(pool, rsrc3)
    assert 3 == f(pool)
    assert {1, 2} == f2(pool)

    ResourcePool.clear(pool)
    assert 0 == f(pool)
    assert {0, 0} == f2(pool)
  end

  test "invalidate", context do
    pool = context[:pid]
    ResourcePool.borrow(pool)
    rsrc = ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    assert {4, 0} == f2(pool)
    ok = ResourcePool.invalidate(pool, rsrc)
    assert ok == :ok
    assert {3, 0} == f2(pool)
    er = ResourcePool.invalidate(pool, rsrc)
    assert er == {:error, :not_active}
    assert {3, 0} == f2(pool)
    self = self()
    spawn_link(
      fn() ->
        rsrc1 = ResourcePool.borrow(pool)
        send self, rsrc1
      end
    )
    receive do
      pid ->
        er1 = ResourcePool.invalidate(pool, pid)
        assert er1 == {:error, :not_owner}
        assert {4, 0} == f2(pool)
    end

  end

  test "clear_check", context do
    pool = context[:pid]
    ResourcePool.borrow(pool)
    ResourcePool.borrow(pool)
    ResourcePool.add(pool)
    ResourcePool.add(pool)
    assert {2, 2} == f2(pool)

    ResourcePool.clear(pool)
    assert {0, 0} == f2(pool)
  end

  test "stress test", %{pid: pool} do
    n = 100
    m = 50
    run_worker(n, m, pool)
    wait_for(n)
    state = GenServer.call(pool, :get_state)
    l = state.active ++ state.idle

    r = List.foldl(l, 0, fn({rsrc, _}, a) -> a + TestResource.get_id(rsrc) end)
    assert n * m == r

  end

  def run_worker(0, _, _), do: :ok

  def run_worker(n, m, pool) do
    spawn_link(__MODULE__, :worker, [m, pool, self()])
    run_worker(n - 1, m, pool)
  end

  def worker(0, _, parent) do
#    :io.format("~n~p:: Done~n", [self()])
    send parent, :done
  end

  def worker(n, pool, parent) do
    case ResourcePool.borrow(pool) do
      {:error, _e} ->
#  %      ?debug_Fmt("~p:: after Error ~p N:~p", [self(), _E, N]),
        worker(n, pool, parent)
      resource ->
#  %      ?debug_Fmt("~p:: after Borrow resource: ~p", [self(), Resource]),
        inc = TestResource.get_id(resource) + 1
        TestResource.set_id(resource, inc)
        ResourcePool.return(pool, resource)
#  %      ?debug_Fmt("~p:: after Return resource: ~p", [self(), Resource]),
        worker(n - 1, pool, parent)
    end
  end

  def wait_for(0), do: :ok

  def wait_for(n) do
    receive do
      :done -> wait_for(n - 1)
    end
  end

end
