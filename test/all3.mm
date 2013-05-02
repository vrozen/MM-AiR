source steps
auto pool count
steps --> count
assert ends : count < 2 "ok"

auto push all pool A at 5
pool B
pool C
A -2-> B
A -2-> C

assert sane : count == 0 || B == 2 && C == 2 "push all pools either provide all or no resources"