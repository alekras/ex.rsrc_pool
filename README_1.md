# Resource Pool

## Introduction
Some software resources have time and memory cost to create and reusing them can dramatically improve application performance. Resource pooling is widely used for resource reusing in different platform and languages. This project was inspired by Apache Commons Pool Java library. API and main functioning principals was borrowed from there, but internal implementation is completely different and is using Erlang OTP design principles and Erlang/Elixir concurrent model. See [Erlang resource pool](https://github.com/alekras/rsrc_pool) for Erlang implementation of the library.

## Design
Resource pool consists of two containers: `Active` and `Idle`. `Active` container keeps references to
resources that are actively used by some processes. Oppositely `Idle` container keeps resources that are not
used anywhere and they are in inactive state but ready to use.

      +-Pool-----------{0,0}-+
      |                      |
      | Active--+  Idle----+ |
      | |       |  |       | |
      | |       |  |       | |
      | |       |  |       | |
      | +-------+  +-------+ |
      +----------------------+

We will use a diagram above to explain operations with pool in following text. Symbols in right of first line `-{0,0}-` show the load of containers: `-{N_active,N_idle}-`,

where:
 - `N_active` - number of active resources;
 - `N_idle` - number of idle resources.

## Operations

First thing we have to do is create an instance of resource pool.

```elixir
  {:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, resource_metadata)
```

`:test_pool` is a registered name for the new pool and `ResourceFactory` is a name of a module 
that implements resource_factory behaviour. Now we can use `:test_pool`
or `pid` as a reference to pool instance. Resource factory module will be responsible for creating, checking and disposing of resource instances and is discussed in details in [Resource factory](#resource-factory) section below.

The common scenario of using of the resource pool is state with a few concurrently running processes shares the same pool to borrow resources from it.

### borrow
To retrieve a resource from pool process has to call function `borrow`.

```elixir
  resource = ResourcePool.borrow(:test_pool)
```

If `Idle` list is empty the pool creates new resource `<R.2>` and grants it to calling process.

      +-Pool-----------{1,0}-+          +-Pool-----------{2,0}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  |       | |          | |       |  |       | |
      | |       |  |       | |    =>    | | <R.2> |  |       | |
      | | <R.1> |  |       | |          | | <R.1> |  |       | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

If the pool has idle resource within `Idle` list an idle resource just transfers to `Active` list and
it is granted to caling process.

      +-Pool-----------{1,2}-+          +-Pool-----------{2,1}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  |       | |          | |       |  |       | |
      | |       |  | <R.2> | |    =>    | | <R.2> |  |       | |
      | | <R.1> |  | <R.3> | |          | | <R.1> |  | <R.3> | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

### return
Process has to return a resource to the pool after the process completes using a resource.
In other words the resource is moved from `Active` list to `Idle` list. Now other concurrent 
processes can borrow freed resource from the pool.

```elixir
  ResourcePool.return(:test_pool, resource)
```

      +-Pool-----------{2,1}-+          +-Pool-----------{1,2}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  |       | |          | |       |  |       | |
      | | <R.2> |  |       | |    =>    | |       |  | <R.2> | |
      | | <R.1> |  | <R.3> | |          | | <R.1> |  | <R.3> | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

### add
Sometimes we need just add new resource to pool. Function `add` creates new resource and
puts it into `Idle` list. 

```elixir
  ResourcePool.add(:test_pool)
```

      +-Pool-----------{2,1}-+          +-Pool-----------{2,2}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  |       | |          | |       |  |       | |
      | | <R.2> |  |       | |    =>    | | <R.2> |  | <R.4> | |
      | | <R.1> |  | <R.3> | |          | | <R.1> |  | <R.3> | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

### invalidate
If resource failed then a process has to let know about it to the pool. `invalidate` function marks failed resource
as unusable and pool will destroy it shortly.

```elixir
  ResourcePool.invalidate(:test_pool, resource)
```

      +-Pool-----------{2,1}-+          +-Pool-----------{1,1}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  |       | |          | |       |  |       | |
      | | <R.2> |  |       | |    =>    | |       |  |       | |
      | | <R.1> |  | <R.3> | |          | | <R.1> |  | <R.3> | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

### typical use case
Suppose that `Resource` module implements some operations under resource.

```elixir
  case ResourcePool.borrow(:test_pool) do
    {:error, e} -> IO.put("Error while borrow from pool, reason: #{e}")
    resource ->
      try do
        Resource.operation(resource)
        ResourcePool.return(:test_pool, resource)
      catch
        _ -> ResourcePool.invalidate(:test_pool, resource)
      end
  end
```

If everything is going well we see flow like this: borrow --> use --> return. When something wrong is happened during 
resource use then we have other flow: borrow --> use --> invalidate.
 
## Size limits
We can setup some features and parameters for a resource pool during instantiation by using `option` parameter
of `new` operation (see [new](#new)):

```elixir
  {:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, resource_metadata, options)
```

`options` list contains a few values those define scales, limitation and behavior of a pool. Some of those are
responsible for size of `Active` and `Idle` containers:

 max_active,
 max_idle,
 min_idle


```
             +-Pool-----------{0,0}-+
             |                      |
             | Active--+  Idle----+ |
             | |       |  |_______|_|__ max_idle
 max_active__|_|_______|  |       | |
             | |       |  |       | |
             | |       |  |_______|_|__ min_idle
             | |       |  |       | |
             | +-------+  +-------+ |
             +----------------------+
```

### max_active 
Maximum size of `Active` list is 8 by default. If it reaches the limit following `borrow` operation will be blocked or 
failed (see [Borrow with exhausted pool](#borrow-with-exhausted-pool) for details). The value -1 (or any negative) means no limitation on `Active` list size.
Example of use: 

```elixir
  {:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, [], [max_active: 20])
```

### max_idle
Maximum size of `Idle` list equals max_active by default. If it reaches the limit then following `return` operation 
will be finished with destroying of the returned resource. The value -1 (or any negative) means no limitation on `Idle` list maximum size.
Example of use: 

```elixir
  {:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, [], [max_active: 20, max_idle: 10])
```

### min_idle
Minimum size of `Idle` list is 0 by default. If it reaches the limit then following `borrow` operation will
successfully supplies a resource to invoker and then pool will additionally create new resource in `Idle` container to provide 
min_idle condition. The value -1 (or any negative) means no limitation on Idle list minimum size.
Example of use: 

```elixir
  {:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, [], [max_active: 20, max_idle: 10, min_idle: 3])
```

## Behaviour options
### Borrow with exhausted pool
When we set max_active greater then 0 and size of Active list reaches this value then the pool is exhausted and pool's behaiviour depends on when_exhausted_action option value:
 * **{:when_exhausted_action, :fail}** - `borrow` function on exhausted pool returns `{:error, :pool_exhausted}`.
 * **{:when_exhausted_action, :block}**  - `borrow` function on exhausted pool is blocked until a new or idle object is available.
   Waiting time period is limited by value of other option max_wait (see [Timing](#timing)).
 * **{:when_exhausted_action, :grow}** - `borrow` function on exhausted pool returns new resource and size of `Active` list grows. In this case `max_active` option is just ignored.

Default value is `block`. 
Example of use: 

```elixir
  {:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, [], [max_active: 20, when_exhausted_action: fail])
```

### Resource checking
Resource pool can check status of managed resources. Options `test_on_borrow` and `test_on_return`
control how pool tests resources: before providing resource to invoker `test_on_borrow: true` and after a resource was returned
to pool `test_on_return: true`. If pool finds that the resource is not alive during test then the resource will be destroyed.

### Resource order in idle container
Option `fifo` (first-input-first-output) controls order of extracting a resources from `Idle` list. Diagrams below illustrate this. Suppose we
fill out `Idle` list in order: <R.1> was first, <R.2> is next, then <R.3>. Resource <R.4> is active in given moment. If
`fifo: true` is set the `borrow` operation leads to situation below: resource <R.1> was came first and
it becomes active now (first out).

      +-Pool-----------{1,2}-+          +-Pool-----------{2,1}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  | <R.3> | |          | |       |  |       | |
      | |       |  | <R.2> | |    =>    | | <R.1> |  | <R.3> | |
      | | <R.4> |  | <R.1> | |          | | <R.4> |  | <R.2> | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

If `fifo: false` is set it means that order will be last-input-first-output. `borrow` operation makes active resource
<R.3> (last input).

      +-Pool-----------{1,2}-+          +-Pool-----------{2,1}-+
      |                      |          |                      |
      | Active--+  Idle----+ |          | Active--+  Idle----+ |
      | |       |  | <R.3> | |          | |       |  |       | |
      | |       |  | <R.2> | |    =>    | | <R.3> |  | <R.2> | |
      | | <R.4> |  | <R.1> | |          | | <R.4> |  | <R.1> | |
      | +-------+  +-------+ |          | +-------+  +-------+ |
      +----------------------+          +----------------------+

Default value for `fifo` is `false`.

### Timing
`max_wait` option defines the maximum amount of time to wait when the `borrow` function is invoked,
the pool is exhausted and `when_exhausted_action` equals `block`.

`max_idle_time` option defines non terminated period of time an resource instance may sit idle in the pool, 
with the extra condition that at least `min_idle` amount of object remain in the pool. No resources 
will be evicted from the pool due to maximum idle time limit if `max_idle_time` equals `infinity`.

## Maintenance of pool instance
### new
Lets look more closely at resource pool instantiation. `pool_name` is atom and multiple processes can use the
registered name to access the resource pool. `ResourceFactory` is module name that is responsible for creating and maintenance
of a resources. `resource_metadata` is an object that contains information for instantiation of an resource. The object is passed
as parameter to each function of `resource_factory` to help maintain an resources. 

```elixir
  {:ok, pid} = ResourcePool.new(:pool_name, ResourceFactory, resource_metadata)
```

### clear
The function sweep up (destroy) all resources from pool.

```elixir
  :ok = ResourcePool.clear(:pool_name)
```

### close
The function terminates pool process and destroys all resources from pool.

```elixir
  :ok = ResourcePool.close(:pool_name)
```

### get_num_active, get_num_idle, get_number
The functions return number of resources in `Active`, `Idle` containers and total number of resources.

## Resource factory
Before we do not go in details of an resources managed by pool. We was thinking about its as abstract resource without any
features and properties. It is not true in reality. Real resources (as connections, sockets, channels and so on) are living in pool
are composed objects with number of properties and they have an life cycle: we have to create them, test, use and dispose them.
Resource factory separate pool functionality from managed resources functionality and allows to easy customize pool for
different types of resources.

`ResourceFactory` module defines `behavior` of generic resource factory. We have to implement this 
`behavior` while designing of resource factory module for given resource. The module has to consist following functions:

 * **create(resource_metadata :: list())** - The function creates new instance of the resource. In Elixir world this is a new
   process in most cases. `resource_metadata` is a data structure that describes an resource. `resource_metadata` came
   to the pool from `new` operation and it has to be enough to create and manage the resource. Structure and contain of
   the `resource_metadata` is custom and it is used only by `ResourceFactory` but is kept as a pool state.
 * **destroy(resource_metadata::term(), resource::pid())** - The function destroys the resource represented by `resource` as a `Pid`.
 * **validate(resource_metadata::term(), resource::pid())** - The function check an `resource` and returns true if the resource is valid.
 * **activate(resource_metadata::term(), resource::pid())** - The function is callback that is fired when pool are moving `resource` from
   passive state to active (from idle list to active list).
 * **passivate(resource_metadata::term(), resource::pid())** - The function is callback that is fired when pool are moving `resource` from
   active state to passive (from active list to idle list).

