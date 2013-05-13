source tick
auto pool count
tick --> count
assert ends : count < 2 "ok"

auto push all pool A at 3
pool B
pool C
A -2-> B
A -2-> C

assert sane : B == 0 || C == 0 "push all pools either provide all or no resources"