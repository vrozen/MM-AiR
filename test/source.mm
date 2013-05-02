/*
  This test demonstates flow from sources can trigger other flows.
*/

source tick
source tock
auto pool count
pool idea
tick --> count
tick .*.> idea
tock --> idea

assert ends : count < 10
  "ok"

assert sane : count == 0 || idea == count - 1
  "Flow from sources can trigger other flows"