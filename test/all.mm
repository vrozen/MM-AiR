source tick
auto pool count max 3
tick --> count
assert ends : count < 2 "ok"

pool A at 3
auto all pool B max 10
auto all pool C max 10

A -2-> B
A -2-> C

assert sane : count == 0 || (count > 0 && B == 2) || (count > 0 && C == 2)
  "pulling pools compete for resources when they are scarce"