# Resource Pool (rsrc_pool)
Resource pool project is written in Elixir as a tiny library. The goal of the tool is reduce the overhead of creating new resources by reusing of the same resources among multiple processes. Achieving result is better performance and throughput. The resource pool was inspired by Java Apache's commons pool and adopts API and main principals from this project. Database connection is most popular example for pooling resource.

## Introduction
Resource pool project was inspired by Apache Commons Pool library and API was borrowed from there. But internal 
implementation is completely different, written in Elixir and it is using Erlang OTP design principles and Erlang concurrent model. Resource Pool is Elixir application library.   

## Structure
<ul>
  <li><code>ResourcePool.GenServer (resource_pool_srv.ex)</code> is a main module of Resource Pool. It is generic server and implements 
almost all Pool functionality.</li>
  <li><code>ResourcePool (resource_pool.ex)</code> is a facade for GenServer and exposes all API functions.</li>
  <li><code>ResourceFactory (resource_factory.ex)</code> defines <i>resource_factory</i> behaviour.</li>
</ul>

## Getting started
<ol>
  <li>Create instance of Resource Pool<br/> 
    <pre>{:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, [])</pre>
    where: 
    <ul style="list-style-type:none;">
      <li><code>:test_pool</code> - registered name of the new pool;</li>
      <li><code>ResourceFactory</code> - name of a module that implements ResourceFactory behaviour.</li>
    </ul>
    New resource pool is usually shared between few processes.  
  </li>
  <li>Borrow resource from pool<br/>
    <pre>resource = ResourcePool.borrow(:test_pool)</pre>
    The process can use the borrowed resource and has to return to pool after finish. 
  </li>
  <li>Return resource to pool<br/>
      <pre>:ok = ResourcePool.return(:test_pool, resource)</pre>
      The process cannot use the <code>resource</code> anymore.
  </li>
  <li>Pool can be created with options:<br/>
    <pre>options = [max_active: 10, when_exhausted_action: fail]</pre>
    <pre>{:ok, pid} = ResourcePool.new(:test_pool, ResourceFactory, options)</pre>
    See ResourcePool for more details about options. 
  </li>
</ol>

See [Resource Pool](README_1.md) article for details and [http://erlpool.sourceforge.net/](http://erlpool.sourceforge.net/).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rsrc_pool` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rsrc_pool, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/rsrc_pool](https://hexdocs.pm/rsrc_pool).

