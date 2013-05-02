/*
  This test demonstrates gates can trigger other nodes.
*/

auto source tick
pool count
tick --> count

source s
auto gate g
pool p
g .*.> s
s --> p

assert ends : count < 100 "ok"

assert sane : count == 0 || active s "automatic gates without input can trigger other nodes"

