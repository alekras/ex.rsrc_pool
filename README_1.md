# Resource Pool

## Introduction
Some software resources have time and memory cost to create and reusing them can dramatically improve application performance.
Resource pooling is widely used for resource reusing in different platform and languages. This project was inspired by 
Apache Commons Pool Java library. API and main functioning principals was borrowed from there, but internal 
implementation is completely different and is using Erlang OTP design principles and Erlang/Elixir concurrent model.

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
line **-{0,0}-** show the load of containers: **-{N_active,N_idle}-**, 

where:
 - **N_active** - number of active resorces;
 - **N_idle** - number of idle resources.


