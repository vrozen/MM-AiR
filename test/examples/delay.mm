/*
  This test demonstrates delays hold resources for a specified amount of steps.
  Every step, a unit is built and building takes 5 steps.
  This ensures that defence is zero or counter minus 5.
  
  FIXME: it makes much more sense for edges to delay, not nodes
*/
source tick
auto pool count
tick --> count

auto source units
delay build by 5
auto pool defence
units --> build
build --> defence

assert ends : count < 100 "ok"
assert sane : defence == 0 || defence == count - 5 "delays delay by the specified amount"