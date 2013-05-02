auto source tick
pool count
tick --> count
assert ends : count < 20 "ok"

auto source A
auto pool B
A --> B

assert sane : B == count * 2 "pull and push flow at the same time"
