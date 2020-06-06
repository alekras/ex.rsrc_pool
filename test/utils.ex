defmodule Utils do

  def f(pool), do: ResourcePool.get_number(pool)

  def f2(pool), do: {ResourcePool.get_num_active(pool), ResourcePool.get_num_idle(pool)}

end
