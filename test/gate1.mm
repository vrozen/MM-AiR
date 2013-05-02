/*
  This test demonstrates gates hold no resources.
  Every step G pulls a resource from A and distributes it back.
*/

source tick
auto pool count
tick --> count
assert ends : count < 10 "ok"

pool A at 1
auto gate G
A --> G
G --> A

assert sane : G == 0
  "Gates never hold resources"
  
assert sane : A == 1
  "Gates never hold, generate or consume resources"
