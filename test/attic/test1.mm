//foo(coins p1, gold p2)
foo
{
  drain d1
  drain d2 of gold //declare drains d1, d2 of type gold
  source s             //delcare a source s (untyped)
  pool p1
  pool p2          //declare pool p1 and p2 (untyped)  
  s --> p1             //flow (untyped) from s to p1
  p1 .3.> p2           //
  p2 --> d2            //flow from p2 to d2
  p1 -3->d1            //flow from 3 times p1 to d3
  p2 .1.>d1            //
}

//bar(gold gp1, oil op1) //declare function foo with arguments gp1 and gp2 
bar
{
  source os of oil      //declare an oil source named os
  pool gp1 of gold
  pool gp2 of gold //declare pools named gp1 and gp2 of type gold
  pool op3 of oil
  pool op4 of oil  //declare pools named op1 and op1 of type oil  
  os --> op3            //flow oil from os to op3  
  gp1 -3*op3-> gp2      //flow 3 times op3 gold from gp1 to gp2  
  op3 --> op4           //flow oil from op3 to op4  
  gp1 .1.> op3          //
}
