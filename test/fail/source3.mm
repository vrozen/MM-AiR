//now results in a checker error
source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

auto all source A
auto pool B
A --> B

assert sane : B == count * 2 "pull and push flow at the same time"
