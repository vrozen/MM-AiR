module lang::machinations::Generator

import IO;
import List;
import Set;
import util::Math;

import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Preprocessor;
import lang::machinations::Serialize;




public set[State] machinations_generate (Mach2 m2)
{
  State s = NEW_State(m2);
  TempState ts = NEW_TempState(m2);
  set[State] space = {};
   
  work = [s];  
  while(work != [])
  { 
    <s, work> = headTail(work);    
    for(s_new <- generate_successors(s,ts,m2))
    {
      if(s_new notin space)
      {
        if(i % 100 == 0) println("State <i>");
        space += s_new;
        work += s_new;
      }
    }
  }
  println("All spaced out! :-)");
  
  return space;
}

public list[State] generation_step(State s, TempState ts, Mach2 m2)
{ 
  list[int] active_nodes
  = 
  //1.1 calculate the set of active pools and gates
  //(auto  || activated) && not deactivated
  //list[int] active_pools =
    [l | l <- getNodes(m2), //each pool / gate
     (getElement(m2, l).when == when_auto() || l in s.activated)    //that automatically activates or is activated
     && (false notin {evalBool(s, a) | a <- getActivators(m2,l)})]; //and not disabled
  
  //2. calculate a set of conditions
  list[tuple[int, Cond]] conditions
    =  [<l, generateCacheCondition(s, m2, getElement(m2,l))> | l <- active_nodes];
  
  //3. TODO: if synchronous: "and" conditions that pull at the same node
  
  //4. Choose one ordering / interleaving
  list[State] successors = [];

  successors =  
  for(interleaving <- getInterleavings(m2))
  {
    //6. solve conditions
    list[Transition] tr = [];
    tr =
    for(<label,cond> <- conditions, label <- [i | i <- interleaving, i in active_nodes] + [a | a <- active_nodes, a notin interleaving])
    {
      //3.2 for each condition try if it can be validated. if yes then add a flow element to the transition
      <s, tr_n> = solveCond(s, m2, label, cond);    
      //perform subtractions
      s = state_sub(s, m2, tr_n);
      append tr_n;
    }
  
    //flatten transition list  
    Transition t = [*tn | tn <- tr];
  
    //perform additions
    s = state_add(s, m2, t);
    append s;
  }
  
  return successors;
}



