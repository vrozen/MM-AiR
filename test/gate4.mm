/*
  This test demonstrates gates can trigger other nodes.
*/

source tick
auto pool count
tick --> count

all source s
auto gate g
pool p
g .*.> s
s --> p

assert ends : count < 10 "ok"

assert sane : count == 0 || active s "automatic gates without input can trigger other nodes"

