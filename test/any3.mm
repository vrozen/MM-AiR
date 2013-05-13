source tick
auto pool count
tick --> count
assert ends : count < 3 "ok"

pool A at 4
auto pool B max 3
A -2-> B

assert sane : count != 1 || (A == 2 && B == 2) "any amount will flow up to the maximum defined by the flow"

assert sane : count < 2 || (A == 1 && B == 3) "any amount will flow up to the maximum defined by the flow"

assert sane : A + B == 4 "pulling any amount does not generate or delete resources"