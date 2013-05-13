/*
  This test demonstrates the counting ability of gates.
  The gate G pulls 2 resources from source S each step.
  Gate G alternates between distributing 2 resources to A and B, starting at A.  
  Since B starts at 1, this ensures that either A is one resource ahead, or B is.
*/

source tick
auto pool count
tick --> count

source S
auto gate G
pool A 
pool B at 1
S -2-> G
G -2-> A
G -2-> B

assert ends : count < 100 "ok"
assert sane : A == B - 1 || B == A - 1 "gates count starting at the first flow"