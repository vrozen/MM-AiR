module lang::machinations::Generator

import IO;
import List;
import Set;
import util::Math;
import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Preprocessor;
import lang::machinations::Serialize;
import lang::machinations::Message;
import lang::machinations::Evaluator;

public set[State] machinations_generate (Mach2 m2)
{
  State s = NEW_State(m2);
  TempState ts = NEW_TempState(m2);
  
  list[Msg] msgs = [];  
  set[State] ss = {};
  list[list[State]] workStack = [[s]];
  list[State] trace = [];

  while(workStack != [])
  {
    //<work, worksStack> = headTail(workStack);
    work = head(workStack);
    println("\nState space: <size(ss)>. Violations: <size(msgs)>.\nDepth <size(workStack)>: amount of work <size(work)>.");

    if(work == [])
    {
      println("Out of work at depth <size(workStack)>");
      workStack = tail(workStack);
      continue;
    }
    <curState, work> = headTail(work);
    
    if(curState in ss)
    {
      if(work == [])
      {
        println("Out of work at depth <size(workStack)>");
        workStack = tail(workStack);
      }
      else
      {
        workStack[0] = work;
      }
      continue;
    }
    
    //printState(curState, m2);
    ss += curState;
    
    println("Test assertions");
    list[Msg] curMsgs = testAssertions(curState,ts,m2);    
    if(curMsgs != [])
    {
      msgs += curMsgs;
      println("Assertion violated <toString(curMsgs)>");
      printState(curState, m2);
      continue;
    }
      
    if(size(workStack) < 50)
    {
      println("\nGo in depth");
      list[State] successors = toList(generate_step(curState,ts,m2));    
      workStack = [successors, work] + tail(workStack);
    }
    else
    {
      println("\nAt max depth");
      workStack[0] = work;      
    }
  }

  if(msgs == [])
  {
    println("\nNo assertions violated.");
  }
  else
  {
    println("\nAssertion violated.");
    println(toString(msgs));
  }
  
  println("State space size <size(ss)>");
  
  return ss;
}


public set[tuple[State,Transition]] generate_step (State s, TempState ts, Mach2 m2)
{
  set[tuple[State,Transition]] successors = {};

  //1: Calculate the set of active nodes. (auto  || activated) && not deactivated
  set[int] active_nodes 
    = activeNodes(s, ts, m2);
    
  //2: Calculate a set of conditions
  list[tuple[int, Cond]] conditions
    = [<l, generateCacheCondition(s, ts, m2, getElement(m2,l))> | l <- active_nodes];
  
  //4: Choose one node ordering / interleaving
  for(interleaving <- getInterleavings(m2))
  {
    //println("interleaving selected <interleaving>");
    //5. Create States
    State s1 = s;       //sub flow from here
    State s2 = s;       //add flow to here
    TempState ts1 = ts; //sub flow from here
    TempState ts2 = ts; //add flow to here
    Transition tr_n;    //generated transition parts
    
    //6: Solve conditions
    list[Transition] tr = [];
    tr =
    for(label <- [i | i <- interleaving, i in active_nodes] +
                 [a | a <- active_nodes, a notin interleaving],
       <label, cond> <- conditions)
    {
      //println("label <label>");
      //6.1: for each condition try if it can be validated. if yes then add a flow element to the transition
      <s1, ts1, s2, ts2, tr_n> = solveCond(s1, ts1, s2, ts2, m2, label, cond);    
      //6.2: perform subtractions. NOTE: already done!
      //<suc, ts> = state_sub(suc, ts, m2, tr_n);
      append tr_n;
    }
    
    //7: Flatten transition list  
    Transition t = [*tn | tn <- tr];
  
    //8: Perform additions.
    <s1, ts1> = state_add(s1, ts1, m2, t);
    //s1 = s2;   //s2 has all the additions already
    //ts1 = ts2; //ts2 has all the additions already 
  
    //9: Redistribute resources accumulated in gates.
    <s1, tr_g> = redistributeGates(s1, ts1, [], m2);
  
    Transition t_all = t + tr_g;
  
    //10: Activate nodes
    s1 = activateNodes (s1, m2, t_all);

    successors += <s1,t_all>;
  }
  
  //println("Successors <successors>");
  return successors;
}
