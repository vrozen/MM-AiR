source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

auto all source S
pool A
pool B
S --> A
S -3-> B

assert sane : A == 0 || B == 3*A "flow works"
