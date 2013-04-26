@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Machinations Evaluator
* @package      lang::machinations
* @file         Evaluator.rsc
* @brief        Defines how given a state, its successors are calculated.
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Evaluator

import IO;
import List;
import Set;
import util::Math;
import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Preprocessor;
import lang::machinations::Serialize;
import lang::machinations::Message;

public tuple[list[tuple[State,Transition]],list[Msg]]  machinations_simulate (Mach2 m2, int depth)
{
  println("Random simulation to maximum depth <depth> started.\n");

  list[tuple[State,Transition]] trace = [];
  State s = NEW_State(m2);
  TempState ts = NEW_TempState(m2);
  list[Msg] msgs = [];
  int j = 0;
  //perform automatic random simulation
  trace = 
  for(i <- [1..depth])
  {
    j+=1;
    <s,tr> = simulate_step(s,ts,m2);    
    append <s,tr>;    
    msgs = testAssertions(s,ts,m2);
    if(msgs != []){ break; }
  }
  return <trace, msgs>;
}

public list[Msg] testAssertions (State s, TempState ts, Mach2 m2)
  = [msg_AssertionViolated(s,n) | n: always(ID name, Exp e, str msg) <- m2.m.elements, evalBool(s, ts, m2, e) == false];
   
public tuple[State, Transition] simulate_step(State s, TempState ts, Mach2 m2)
{ 
  //1: Calculate the set of active nodes. (auto  || activated) && not deactivated
  set[int] active_nodes 
    = activeNodes(s, ts, m2);

  //println("active nodes: <active_nodes>");
    
  //2: Calculate a set of conditions
  list[tuple[int, Cond]] conditions
    =  [<l, generateCacheCondition(s, ts, m2, getElement(m2,l))> | l <- active_nodes];
  
  //3: TODO: if synchronous: "and" conditions that pull at the same node
  //not that easy... or(rany(...)) changes to and(rall(...)) ==> strange
   
  //println("interleaving selected <interleaving>");

  //4: Choose one node ordering / interleaving
  list[int] interleaving = getOneFrom(getInterleavings(m2));
  
  //5. Create States
  State s2 = s;      //add flow to here
  TempState ts2 = ts; //add flow to here
  Transition tr_n;   //generated transition parts

  //println("begin");

  //6: Solve conditions
  list[Transition] tr = [];
  tr =
  for(label <- [i | i <- interleaving, i in active_nodes] +
               [a | a <- active_nodes, a notin interleaving],
     <label, cond> <- conditions)
  {
    //println("label <label> : <toString(getElement(m2,label).name)>");
    //6.1: for each condition try if it can be validated. if yes then add a flow element to the transition
    <s, ts, s2, ts2, tr_n> = solveCond(s, ts, s2, ts2, m2, label, cond);    
    //6.2: perform subtractions. NOTE: already done!
    //<s, ts> = state_sub(s, ts, m2, tr_n);
    append tr_n;
  }
  //println("end");
  
  //7: Flatten transition list  
  Transition t = [*tn | tn <- tr];
  
  //8: Perform additions.
  //<s, ts> = state_add(s, ts, m2, t);
  s = s2;   //s2 has all the additions already
  ts = ts2; //ts2 has all the additions already  
  
  //9: Redistribute resources accumulated in gates.
  <s, tr_g> = redistributeGates(s, ts, [], m2);
  
  Transition t_all = t + tr_g;
  
  //9: Activate nodes
  s = activateNodes (s, m2, t_all);  
  
  //for(a <- active_nodes)
  //{
  //  println("ACTIVE <getElement(m2,a).name.name>");
  //}
  //println("__");
   
  return <s, t_all>;
}

public set[int] activeNodes (State s, TempState ts, Mach2 m2)
    = {l | l <- getNodes(m2),                                            //retrieve labels of each node
      (getElement(m2, l).when == when_auto() || l in s.activated)        //that automatically activates or is activated
      && (false notin {evalBool(s, ts, m2, a) | a <- getActivators(m2,l)})}; //and not disabled

public State activateNodes (State s, Mach2 m2, Transition t)
{
  //calculate which node's inputs are 'satisfied'
  //this set is the set of node labels for which all flow edges they operate on are satisfied at the same time
  //this semantics is a bit strange since we also have the 'all' and 'any' modifiers
  //therefore we might expect any nodes to trigger when any flow is satisfied, but this is not true!

  //satisfied nodes are
    //1. pulling nodes
        //either each inflow is satisfied and it has inflow
        //or the node has no inflow and it is active (auto or activated)
    //2. pushing nodes
        //either each outflow is satisfied and it has outflow
        //or the node has no outflow and it is active (auto or activated)
  
  set[int] satisfied =
    {n | n <- getPullNodes(m2),              //each pulling node for which
       {src | src <- getInflowLabels(m2, n), //there are no source flow labels
          {tn | tn: <src,_,n> <- t} == {}    //for which no flow is in the transition
       } == {} && getInflowLabels(m2,n) != []
    } +
    {n | n <- getPushNodes(m2),
       {tgt | tgt <- getOutflowLabels(m2, n), 
         {tn | tn: <n,_,tgt> <- t} == {}
       } == {} && getOutflowLabels(m2,n) != []
    } +
    {n | n <- getPullNodes(m2),              //each pulling node for which
       {src | src <- getInflowLabels(m2, n), //there are no source flow labels
          {tn | tn: <src,_,n> <- t} == {}    //for which no flow is in the transition
       } == {} && getInflowLabels(m2,n) == [] && (getElement(m2,n).when == when_auto() || n in s.activated)
    } +
    {n | n <- getPushNodes(m2),
       {tgt | tgt <- getOutflowLabels(m2, n), 
         {tn | tn: <n,_,tgt> <- t} == {}
       } == {} && getOutflowLabels(m2,n) == [] && (getElement(m2,n).when == when_auto() || n in s.activated)
    };

  s.activated = {te.t@l | te <- {*tn | tn <- {getTriggers(m2,l) | l <- satisfied }}};
  return s;
}

//each condtion must be valid and each condition is a rall
//read from the old state s to test min values and > 0 (availability)
//write to the new state s2 to test max values (does it fit?)
//generate transition tr to update s when all is done
public tuple[State,TempState,State,TempState,Transition] solveCond
  (State s1, TempState ts1, State s2, TempState ts2, Mach2 m2, int label, and(cs))
{
  bool success = true;
  State s1_try = s1;
  State s2_try = s2;
  TempState ts1_try = ts1;
  TempState ts2_try = ts2;
  Transition tr = [];
  
  tr =
  for(alt(cs2) <- cs)
  {
    c = getOneFrom(cs2); //pick an alternative  NOTE: results in random simulation, if there is more than one alternative
    Element e = getElement(m2, c.tgt);
    
    int src_amount = state_retrieve(s1_try, ts1_try, m2, c.src);
    int tgt_amount = state_retrieve(s2_try, ts2_try, m2, c.tgt);

    if(src_amount - c.f >= 0 && c.f > 0)
    {
      if(/*(!e.min? || e.min == min_none() || src_amount - c.f >= e.min.v) &&*/
         (!e.max? || e.max == max_none() || tgt_amount + c.f <= e.max.v))           
      {
        tr_n = <c.src, c.f, c.tgt>;
        <s1_try, ts1_try> = state_sub(s1_try, ts1_try, m2, [tr_n]);
        <s2_try, ts2_try> = state_add(s2_try, ts2_try, m2, [tr_n]);
        <s2_try, ts2_try> = state_sub(s2_try, ts2_try, m2, [tr_n]);        
        append tr_n;
      }
      else
      {
        //println("and: fail (min or) max reached");
        success = false;
        break;
      }
    }
    else
    {
      //println("and: fail lack of resources");
      success = false;
      break;
    }
  }
  if(success == true)
  {
    //s_try = activateTriggers(s_try, m2, label);
    return <s1_try, ts1_try, s2_try, ts2_try, tr>;
  }
  else
  {
    return <s1, ts1, s2, ts2, []>;
  }
}

//each condition is a rany
public tuple[State,TempState,State,TempState,Transition] solveCond
  (State s1, TempState ts1, State s2, TempState ts2, Mach2 m2, int label, i_or(cs))
{
  Transition tr = [];

  tr = 
  for(alt(cs2) <- cs)
  {
    c = getOneFrom(cs2); //pick an alternative   NOTE: results in random simulation, if there is more than one alternative
    Element e = getElement(m2, c.tgt);

    int src_amount = state_retrieve(s1, ts1, m2, c.src);
    int tgt_amount = state_retrieve(s2, ts2, m2, c.tgt);
    
    if(c.f > 0 &&            //the evaluated expression leads to positive flow
      src_amount > 0 &&      //and the source can provide resources
      (!e.max? || e.max == max_none() || tgt_amount < e.max.v))  //and the target has storage capacity
    {
      tuple[int,int,int] tr_n;    
      if(src_amount >= c.f) //the source has enough for full flow
      {
        if(/*(! e.min? || e.min == min_none() || src_amount - c.f >= e.min.v)  Min was removed &&*/
           (! e.max? || e.max == max_none() || tgt_amount + c.f <= e.max.v))     
        {
          //the full flow fits inside the target
          tr_n = <c.src, c.f, c.tgt>;
        }
        else
        {
          //target has capacity for less than the full flow
          tr_n = <c.src, e.max.v - tgt_amount, c.tgt>;
        }
      }
      else
      {
        if(/*(! e.min? ||e.min == min_none() || src_amount - c.f >= e.min.v) && Min was removed*/
           (! e.max? || e.max == max_none() || tgt_amount + src_amount /*was c.f*/ <= e.max.v))   
        {
          //the target accepts whatever the source can provide     
          tr_n = <c.src, src_amount, c.tgt>;      
        }
        else
        {
          //target accepts less than whatever the source can provide
          tr_n = <c.src, e.max.v - tgt_amount, c.tgt>;
        }
      }
      <s1, ts1> = state_sub(s1, ts1, m2, [tr_n]);
      <s2, ts2> = state_add(s2, ts2, m2, [tr_n]);
      <s2, ts2> = state_sub(s2, ts2, m2, [tr_n]);
      append tr_n;
    }
  }
        
  return <s1, ts1, s2, ts2, tr>;
}

public tuple[State,TempState,State,TempState,Transition] solveCond
  (State s1, TempState ts1, State s2, TempState ts2, Mach2 m2, int label, d_or(cs))
  = solveCond(s1, ts1, s2, ts2, m2, label, i_or(cs));

public Cond generateCacheCondition(State s, TempState ts, Mach2 m2, Element e)
{
  Cond c = getCondition(m2, e@l);
  if(c != noc())
  {
    return c;
  }
  else
  {
    return generateCondition(s,ts,m2,e);
  }
}

//Pushing source (no pulling sources exist)
public Cond generateCondition(State s, TempState ts, Mach2 m2,
  e: source(When when, Act act, How how, ID name, list[Unit] opt_u))
 = generateCondition(s, ts, m2, getOutflow(m2, e@l), act_push(), how);

//Pulling drain (no pushing drains exist)
public Cond generateCondition(State s, TempState ts, Mach2 m2,
  e: drain(When when, Act act, How how, ID name, list[Unit] opt_u))
 = generateCondition(s, ts, m2, getInflow(m2, e@l), act_push(), how);

//Pulling pool
public Cond generateCondition(State s, TempState ts, Mach2 m2,
  e: pool(When when, act_pull(), How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
  = generateCondition(s, ts, m2, getInflow(m2, e@l), act_pull(), how);

//Pushing pool
public Cond generateCondition(State s, TempState ts, Mach2 m2,
  e: pool(When when, act_push(), How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
  = generateCondition(s, ts, m2, getOutflow(m2, e@l), act_push(), how);

//Pulling gate
public Cond generateCondition(State s, TempState ts, Mach2 m2,
  e: gate(When when, act_pull(), How how, ID name, list[Unit] opt_u))
  = generateCondition(s, ts, m2, getInflow(m2, e@l), act_pull(), how);  

//Pushing gate
public Cond generateCondition(State s, TempState ts, Mach2 m2,
  e: gate(When when, act_push(), How how, ID name, list[Unit] opt_u))
{
  throw "pushing gate <toString(name)> not supported";
}

//Any condition yielding independently ordered conditions (one cannot disable another)
private Cond generateCondition(State s, TempState ts, Mach2 m2, list[Element] flow /*inFlow or outFlow*/, act_pull(), how_any())
  = i_or([alt([rany(f.s@l,toInt(val),f.t@l) | val <- eval(s,ts,m2,f)]) | f <- flow]);

//Any condition yielding dependently ordered conditions (one can disable another)
private Cond generateCondition(State s, TempState ts, Mach2 m2, list[Element] flow /*inFlow or outFlow*/, act_push(), how_any())
  = d_or([alt([rany(f.s@l,toInt(val),f.t@l) | val <- eval(s,ts,m2,f)]) | f <- flow]);

//All condition
private Cond generateCondition(State s, TempState ts, Mach2 m2, list[Element] flow /*inFlow or outFlow*/, /*pull or push*/ _, how_all())
  = and([alt([rall(f.s@l,toInt(val),f.t@l) | val <- eval(s,ts,m2,f)]) | f <- flow]);


//--------------------------------------------------------------------------------
//Spawn and delete components at run-time
//--------------------------------------------------------------------------------
private Mach2 delete (Mach2 m2, int l)
{
  //its name is componentName_delete
  //for now: search through m2 and simply delete each label with the name prefix
  //the state actually stays intact... leaving 'clutter'
   
  //design decision: states have a static footprint
  //implications
  //- pools of instances can be used
  //- states never grow or shrink
  //- memory pointers can become available
  //- memory pointers cannot become invalid
  
  //wish: i want to decouple where the information is stored from the label it has
  //      labels are unique identifiers for nodes and edges
  //      storage locations are determined by the storage system
  //      storage locations can be reused, identifiers cannot
  
}

//--------------------------------------------------------------------------------
//evaluate Boolean Expressions
//--------------------------------------------------------------------------------
public bool evalBool (State s, TempState ts, Mach2 m2, state(ID src, Exp e, ID tgt))
  = evalBool(s,ts,m2,e);

//added for conditions
private bool evalBool (State s, TempState ts, Mach2 m2, e_and(Exp e1, Exp e2))
  = evalBool(s,ts,m2,e1) && evalBool(s,ts,m2,e2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_or(Exp e1, Exp e2))
  = evalBool(s,ts,m2,e1) || evalBool(s,ts,m2,e2);

//added for testing
private bool evalBool (State s, TempState ts, Mach2 m2, e_active(ID name))
  = (name@l in s.activated) || (getElement(m2,name@l).when == when_auto()) &&
    (false notin {evalBool(s, ts, m2, a) | a <- getActivators(m2,name@l)});

//non-syntactic sugar boolean expressions
private bool evalBool (State s, TempState ts, Mach2 m2, e_lt(Exp e1, Exp e2))
  = (v1 := eval(s,ts,m2,e1) && v2 := eval(s,ts,m2,e2) && v1 < v2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_gt(Exp e1, Exp e2))
  = (v1 := eval(s,ts,m2,e1) && v2 := eval(s,ts,m2,e2) && v1 > v2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_le(Exp e1, Exp e2))
  = (v1 := eval(s,ts,m2,e1) && v2 := eval(s,ts,m2,e2) && v1 <= v2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_ge(Exp e1, Exp e2))
  = (v1 := eval(s,ts,m2,e1) && v2 := eval(s,ts,m2,e2) && v1 >= v2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_eq(Exp e1, Exp e2))
  = (v1 := eval(s,ts,m2,e1) && v2 := eval(s,ts,m2,e2) && v1 == v2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_neq(Exp e1, Exp e2))
  = (v1 := eval(s,ts,m2,e1) && v2 := eval(s,ts,m2,e2) && v1 != v2);

private bool evalBool (State s, TempState ts, Mach2 m2, e_override(Exp e))
  = evalBool(s,ts,m2,e);

private bool evalBool (State s, TempState ts, Mach2 m2, e_not(Exp e))
  = ! evalBool(s,ts,m2,e);

private bool evalBool (State s, TempState ts, Mach2 m2, e_true())
  = true;

private bool evalBool (State s, TempState ts, Mach2 m2, e_false())
  = false;
  
private bool evalBool (State s, TempState ts, Mach2 m2, e)
{
  throw "Element <toString(e)> <e> not supported in evalBool.";
}
  
//--------------------------------------------------------------------------------
//evaluate flow expressions
//these flows are used to generate conditions which can be either true or false
//a condition can be satisfied by a flow of resources in a transition
//--------------------------------------------------------------------------------
private real eval(State s, TempState ts, Mach2 m2, Exp e)
{
  //iprintln(e)
  if({v} := eval(s, ts, m2,
      flow
      (
        id("")[@location = e@location],
        e,
        id("")[@location=e@location]
      )[@location = e@location])
    )
  {
    return v;
  }
  else
  {
    throw "Expression not supported in bool context";
  }
}

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_range(int low, int high), ID tgt))
  = {toReal(v) | v <- [low..high+1]}; //FIME excluse .. semantics

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_val(real v, list[Unit] opt_u), ID tgt))
  = {v};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_name(ID name), ID tgt))
  = {toReal(state_retrieve(s, ts, m2, name@l))};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_percent(Exp e), ID tgt))
  = {state_retrieve(s, m2, src@l) * p | p <- { v / 100 | v <- eval(s, ts, m2, flow(src,e,tgt)[@location = f@location]), v > 0 && v <= 100}};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_override(Exp e), ID tgt))
= eval(s, ts, m2, flow(src, e, tgt)[@location = f@location]);

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_unm(Exp e), ID tgt))
= {-i | i <- eval(s, ts, m2, flow(src, e, tgt)[@location = f@location])};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_mul(Exp e1, Exp e2), ID tgt))
= {v1 * v2 | v1 <- eval(s, ts, m2, flow(src,e1,tgt)[@location = f@location]),
             v2 <- eval(s, ts, m2, flow(src,e2,tgt)[@location = f@location])};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_div(Exp e1, Exp e2), ID tgt))
= {v1 / v2 | v1 <- eval(s, ts, m2, flow(src,e1,tgt)[@location = f@location]),
             v2 <- eval(s, ts, m2, flow(src,e2,tgt)[@location = f@location])};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_add(Exp e1, Exp e2), ID tgt))
= {v1 + v2 | v1 <- eval(s, ts, m2, flow(src,e1,tgt)[@location = f@location]),
             v2 <- eval(s, ts, m2, flow(src,e2,tgt)[@location = f@location])};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_sub(Exp e1, Exp e2), ID tgt))
= {v1 - v2 | v1 <- eval(s, ts, m2, flow(src,e1,tgt)[@location = f@location]),
             v2 <- eval(s, ts, m2, flow(src,e2,tgt)[@location = f@location])};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_all(), ID tgt))
= {toReal(state_retrieve(s, ts, m2, src@l))};

private set[real] eval(State s, TempState ts, Mach2 m2, f: flow(ID src, exp: e_one(), ID tgt))
= {1.0};

private set[real] eval(State s, TempState ts, Mach2 m2, e)
{
  println("Element <toString(e)> not supported in eval.");
  iprintln(e);
  throw "Element <toString(e)> not supported in eval.";
}

//--------------------------------------------------------------------------------
//State manipulation functions
//--------------------------------------------------------------------------------
public int state_retrieve(State s, TempState ts, Mach2 m2, int l)
{
  if(isSource(m2, l))
  {
    //println("Source <l> = full");
    return MAX_INT;
  }
  else if(isDrain(m2, l))
  {
    //println("Drain <l> = empty");
    return 0;
  }
  else if(isGate(m2, l))
  {
    //println("Gate <l> = empty");
    return ts[l];
  }
  else
  {
    //println("Pool <l> = <s.pools[l]>");
    Element e = getElement(m2,l); //retrieve the pool
    if(add_exp(Exp e) := e.add)
    {
      return s.pools[l] + toInt(eval(s, ts, m2, e));
    }
    else
    {
      return s.pools[l];
    }
  } 
}

public tuple[State,TempState] state_add(State s, TempState ts, Mach2 m2, Transition t)
{
  for(<int src, int f, int tgt> <- t)
  {
    if(tgt <= size(s.pools)-1)
    {
      //println("Pool <tgt> += <f>");
      s.pools[tgt] += f; //store it in a pool
    }
    else if(tgt in s.gates)
    {
      ts += (tgt : ts[tgt] + f);
    }
    else
    {
      ;
      //otherwise it may only be a drain (not source)
      //s = activateTriggers(s, m2, tgt);
    }
  }
  return <s, ts>;
}

public tuple[State,TempState] state_sub(State s, TempState ts, Mach2 m2, Transition t)
{
  for(<int src, int f, int tgt> <- t)
  {
    if(src <= size(s.pools)-1)
    {
      s.pools[src] -= f;
    }
    else
    {
      //otherwise it may only be a source (not drain)
      //s = activateTriggers(s, m2, src);
      ;
    }
  }
  return <s,ts>;
}


//--------------------------------------------------------------------------------
//redistribute resources accumulated in gates
//--------------------------------------------------------------------------------
public tuple[State, Transition] redistributeGates (State s, TempState ts, Transition tr, Mach2 m2)
{
  for(gate <- m2.gates)
  {       
    if(ts[gate] != 0)
    {
      list[Element] flows = getOutflow(m2, gate);        
      <s, ts, tr> = redistributeGate(s, ts, tr, m2, gate, flows);
      //s = activateTriggers(s, m2, gate);
    }
  }
  
  //iprintln(ts); //all values should be zero
  
  return <s, tr>;
}

private State activateGateTriggers(State s, Mach2 m2, int gate)
{
  list[Element] triggers = getTriggers(m2, gate); 
  for(trigger: state(ID src, Exp e, ID tgt) <- triggers)
  {
    if(evalBool(s, trigger) == true)
    {
      s.activates += tgt@l;
    }
  }
  return s;
}


//s = state
//ts = temp state
//tr = accumulated transition set[tuple[int src,int f,int tgt]
//m = machiantions model
//l = gate label
private tuple[State, TempState, Transition] redistributeGate
  (State s, TempState ts, Transition tr, Mach2 m2, int l /*gate*/, list[Element] outFlow)
{
  if(outFlow == [])
  {
    return <s, ts, []>;
  }

  int on = s.gates[l].on;
  int oc = s.gates[l].oc;
  //current flow
  Element f = outFlow[on];
  int src = f.s@l;
  int tgt = f.t@l;
  int val = ts[l];

  set[int] maxs = {toInt(v) | v <- eval(s,ts,m2,f)};
         
  //require one maximum count
  if(size(maxs) == 1)
  {
    int max = getOneFrom(maxs);

    if(val < max - oc) //it fits
    {
      //generate flow through this flow edge and store it in the transition
      t = <src, val, tgt>;
      tr += t;
      //println("AMOUNT <val>");


      //set val to zero in temp state
      ts += (l : 0);
      s.gates[l].oc += val;

      //store the value in the state
      <s, ts> = state_add(s, ts, m2, [t]);

      if(isGate(m2, tgt) == true)
      {
        //redistribute this gate also
        <s, ts, tr> = redistributeGate (s, ts, tr, m2, tgt, getOutflow(m2, tgt));
      }
       
    }
    else //it does not fit
    {
      int amount = max - oc;
      //println("AMOUNT <amount>");
      
      //generate flow through this flow edge and store it in the transition
      t = <src, amount, tgt>;
      tr += t;       
      
      //set val to new val in temp state
      ts += (l: ts[l] - amount);

      //set oc to zero
      s.gates[l].oc = 0;
        
      //set on to next
      if(s.gates[l].on == (size(outFlow)-1))
      {
        s.gates[l].on = 0;
      }
      else
      {
        s.gates[l].on = s.gates[l].on + 1;
      }
      
      //store the value in the state
      <s, ts> = state_add(s, ts, m2, [t]);
      
      if(isGate(m2, tgt) == true)
      {
        //redistribute this gate also
        //Element gate2 = getElement(m2, tgt);
        //list[Element] flows2 = getOutflow(m2, tgt);
        <s, ts, tr> = redistributeGate (s, ts, tr, m2, tgt, getOutflow(m2, tgt));
      }
                  
      //try to redistribute this gate again
      if(ts[l] != 0)
      {
        <s, ts, tr> = redistributeGate(s, ts, tr, m2, l, outFlow);
      }
    }
  }
  else
  {
    throw "Non-deterministic gate distribution not supported. Required value, found <vals>.";
  }
  
  return <s, ts, tr>;
}
