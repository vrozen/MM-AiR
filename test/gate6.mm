/*
  This test demonstrates all gates.
*/

source tick
auto pool count
tick --> count

auto push all pool P at 2
pool P1
pool P2

auto all gate G

P --> P1
P --> P2
P1 --> G
P2 --> G

G -all-> P

assert dist : count == 0 && P == 2 && P1 == 0 && P2 == 0 ||
              count == 1 && P == 0 && P1 == 1 && P2 == 1 ||
              count == 2 && P == 2 && P1 == 0 && P2 == 0 ||
              count == 3 && P == 0 && P1 == 1 && P2 == 1 "distribution happens"

assert ends : count < 3 "ok"
              