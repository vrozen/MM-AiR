/*
  This test demonstrates deactivation of pools.
 */
source tick
auto pool count
tick --> count
assert ends : count < 4 "ok" 

pool A at 10
auto drain B 
A -5-> B
A .>5.> B

assert sane : A > 4 "sane"

//assert sane : count == 0 || ! active B "condition edges deactivate pools if the condition is false"
//FIXME: translation to promela fails on active ID
