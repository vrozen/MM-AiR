source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

auto source S1
all source S2
pool A
pool B

S1 --> A
S2 --> B
A .*.> S2

assert sane : A == 0 || A - 1 == B "cannot be activated twice"
