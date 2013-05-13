source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

auto push all pool A at 6
auto push all pool B
pool C

A --> B
B --> C
A .>5.>B

assert sane : C == 0 "pool activation timer"
