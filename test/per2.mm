/*
  This test demonstrates flows that happen once every so many steps.
*/

auto source tick
pool count
tick --> count
assert ends : count < 16 "ok"

//auto push pool P1 at 9
//pool P2
//P1 -3|4-> P2

auto pool P1 at 9
pool P2

source S
pool C
drain D
S --> C
C -all-> D
P1 .*.> S
C .*.> D
C .==4.> D
 
gate G
P1 -3-> G
G -3-> P2
C .==2.>G
C .*.> G

assert sane : P1 + P2 == 9 "edges do not buffer resources"

assert sane : count == 0 && P2 == 0 ||
              count == 1 && P2 == 0 ||
              count == 2 && P2 == 0 ||
              count == 3 && P2 == 0 ||
              count == 4 && P2 == 3 ||
              count == 5 && P2 == 3 ||
              count == 6 && P2 == 3 ||
              count == 7 && P2 == 3 ||
              count == 8 && P2 == 6 ||
              count == 9 && P2 == 6 ||
              count == 10 && P2 == 6 ||
              count == 11 && P2 == 6 ||
              count == 12 && P2 == 9 ||
              count == 13 && P2 == 9 ||
              count == 14 && P2 == 9 ||
              count == 15 && P2 == 9 ||
              count > 15
              "3 flow from units to defence every 4 turns"