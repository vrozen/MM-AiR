source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

auto all source S1
auto all source S2
pool A
pool B

S1 --> A
S2 --> B
A .*.> S2

assert sane : A == B "cannot be activated twice"
