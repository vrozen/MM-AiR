/*
  This test demonstrates pushing of resources.
  This test demonstrates simultaneously pulling and pushing between two nodes.
*/

source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

auto push all pool C at 1
auto push all pool D
C --> D
D --> C

assert sane : (C == 1 && D == 0) || (C == 0 && D == 1)
  "resources should flow when pushed"

assert sane : C + D == 1
  "resources are not generated or consumed when they flow between pushing pools"

auto push all pool E at 2
auto pull all pool F at 0
E --> F

assert sane : E == 2 || F == 2
  "pulling and pushing via the same edge results in 2x the flow"