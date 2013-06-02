/*
  This test demonstrates pulling of resources and activators.
*/

source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

pool A at 4
auto pool B at 0
auto pool C at 0
auto gate D

B .==3.> C
A -1-> B
B -2-> C
C -all-> D
D -all-> A

assert sane : A+B+C == 4           "there are 4 resources"
assert sane : C <= 3               "C never contains more than 3 resources"
assert sane : D != 2               "D never contains 2 resources"
assert sane : ! active C || B == 3 "C is only activated when B contains 3 resources"
