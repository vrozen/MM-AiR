source tick
auto pool count
tick --> count
assert ends : count < 2 "ok"

pool A at 4
auto pool B max 3
A -5-> B

assert sane : count < 1 || (B == 3 && A == 1) "any amount will flow up to the maximum defined by the flow"