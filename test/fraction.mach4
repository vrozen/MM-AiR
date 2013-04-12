auto source tick
pool count
tick --> count
assert ends : count < 20 "ok"


//Not quite correct yet
/*
auto source S
auto push all pool P1
converter C
pool P2 add (P1 / 2)
S --> P1
P1 -2-> C
C -1-> P2
*/

pool In
pool Out

//In - 2 / 3 -> Out //flow 2 resources from in to out every three turns

gate G
auto drain D
pool N
source S

source S2
S --> N
S2 --> Out

//assert sane : P2 == (count / 2) "1/2"
