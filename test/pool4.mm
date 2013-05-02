/*
  This test demonstrates that pools can trigger other nodes
  but that unactivated nodes cannot trigger other nodes.
*/

auto source tick
pool count
tick --> count

assert ends : count < 10 "ok"

auto pool P at 1
pool Q
P .*.> Q
P --> Q

assert trigger : count <= 2 && P == 1 || Q == 1
  "state from an active pool without inflow triggers automatically"
assert trigger : count < 1 || active Q
  "state from an active pool without inflow triggers automatically"

pool S at 1
pool T
S .*.> T
S --> T

assert trigger : T == 0     
  "state from unactivated nodes does not trigger"
assert trigger : ! active T
  "state from unactivated nodes does not trigger"