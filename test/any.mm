source tick
auto pool count max 3
tick --> count
assert ends : count < 2 "ok"

pool A at 4
auto pool B max 3
A -3-> B

assert sane : count < 1 || B == 3 "any amount will flow up to the maximum defined by the flow"