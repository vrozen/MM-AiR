/*
  This test demonstrates gates distribute evenly.
  The gate G pulls 4 resources from source S each step,
  and distributes 2 resources to A and 2 resources to B.
  This ensures that both pools always contain the same amount of resources.
*/

source tick
auto pool count
tick --> count

source S
auto gate G
pool A
pool B
S -4-> G
G --> A
G --> B

assert ends : count < 100 "ok"
assert sane : A == B "gates distribute evenly"