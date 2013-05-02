auto source tick
pool count
tick --> count
assert ends : count < 20 "ok"

auto push pool A at 6
auto push pool B
pool C

A --> B
B --> C
A .>5.>B

assert sane : C == 0 "pool activation timer"
