source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

pool A at 5
auto gate G
pool B
B .<3.> G
A --> G
G --> B

assert sane: count < 4 || B == 3 && A == 2 "gates deactivate"