/*
  This test demonstrates gates can distribute via other gates.
*/

auto source tick
pool count
tick --> count

pool P at 12
pool A
pool B
auto gate G
gate H

P --> G
G -2-> H
G --> A
H --> A
H --> B

assert ends : count < 20 "ok"
assert sane : P != 0 || A == 8 && B == 4 "gates can distribute via gates"