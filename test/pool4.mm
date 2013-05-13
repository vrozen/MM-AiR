/*
  This test demonstrates that pools can trigger other nodes
  but that unactivated nodes cannot trigger other nodes.
*/

source tick
auto pool count
tick --> count

auto pool P at 1
pool P2
P .*.> P2
P --> P2

assert ends : count < 10 "ok"
assert trigger : count < 2 || P2 == 1
  "state from an active pool without inflow triggers automatically"
assert trigger : count < 1 || active P
  "state from an active pool without inflow triggers automatically"