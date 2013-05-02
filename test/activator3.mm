
auto source tick
pool count
tick --> count
assert ends : count < 20 "ok"

pool A at 10
auto converter B
pool C

A --> B
B --> C
A .>5.>B

assert sane : count < 6 || C == 5 "pool activation timer"
