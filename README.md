# Resource Pool

## Introduction
Some software resources have time and memory cost to create and reusing them can dramatically improve application performance.
Resource pooling is widely used for resource reusing in different platform and languages. This article deals with 
[http://sourceforge.net/projects/erlpool Erlang Resource Pool] project in Sourceforge that was inspired by 
Apache Commons Pool Java library. API and main functioning principals was borrowed from there, but internal 
implementation is completely different and is using Erlang OTP design principles and Erlang concurrent model.

## Design
Resource pool consists of two containers: **Active** and **Idle**. **Active** container keeps references to
resources that are actively used by some processes. Oppositely **Idle** container keeps resources that are not
used anywhere and they are in inactive state but ready to use.

      +-Pool-----------{0,0}-+
      |                      |
      | Active--+  Idle----+ |
      | |       |  |       | |
      | |       |  |       | |
      | |       |  |       | |
      | +-------+  +-------+ |
      +----------------------+

We will use a diagram above to explain operations with pool in following text. Symbols in right of first
line '''-{0,0}-''' show the load of containers: '''-{N_active,N_idle}-''', 

where:
 - '''N_active''' - number of active resorces;
 - '''N_idle''' - number of idle resources.

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

