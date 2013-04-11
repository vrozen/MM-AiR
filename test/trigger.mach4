auto source tick
pool count
tick --> count
assert ends : count < 20 "ok"

auto source S1
auto source S2
pool A
pool B

S1 --> A
S2 --> B
A .*.> S2

//Fixed in active nodes bug ->
//list comprehension to set comprehension
assert sane : A == B "cannot be activated twice"
