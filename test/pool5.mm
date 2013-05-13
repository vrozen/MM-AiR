/*
  This test demonstrates that pools can trigger other nodes
  but that unactivated nodes cannot trigger other nodes.
*/

source tick
auto pool count
tick --> count

pool P at 1
pool P2
P .*.> P2
P --> P2

assert ends : count < 10 "ok"

assert trigger : P2 == 0 
  "state from unactivated nodes does not trigger"
assert trigger : ! active P2
  "state from unactivated nodes does not trigger"