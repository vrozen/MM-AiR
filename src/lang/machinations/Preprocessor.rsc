module lang::machinations::Preprocessor
/* The preprocessor processes a machinations structure and calculate constants that are necessary during run-time phases. */

import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Evaluator;
import lang::machinations::Serialize;
import IO;
import List;
import Set;
import util::Math;

public Element getElement(Mach2 m2, int l)
  = m2.elements[l];

public list[Element] getInflow (Mach2 m2, int l)
  = m2.inflow[l];

public list[Element] getOutflow (Mach2 m2, int l)
  = m2.outflow[l];

public list[int] getInflowLabels (Mach2 m2, int l)
  = m2.inflowLabels[l];
  
public list[int] getOutflowLabels(Mach2 m2, int l)
  = m2.outflowLabels[l];

public list[Element] getTriggers (Mach2 m2, int l)
  = m2.triggers[l];
  
public list[Element] getActivators (Mach2 m2, int l)
  = m2.activators[l];
  
public set[list[int]] getInterleavings(Mach2 m2)
  = m2.interleavings;
  
public bool isSource(Mach2 m2, int l)
  = l in m2.sources;

public bool isDrain(Mach2 m2, int l)
  = l in m2.drains;
  
public bool isGate(Mach2 m2, int l)
  = l in m2.gates;
  
public bool isPool(Mach2 m2, int l)
  = l in m2.pools;
  
public bool isNode(Mach2 m2, int l)
  = isPool(m2,l) || isGate(m2,l) || isSource(m2,l) || isDrain(m2,l);
  
public set[int] getNodes(Mach2 m2)
  = m2.nodes;
  
public set[int] getPullNodes(Mach2 m2)
  = m2.pullNodes;

public set[int] getPushNodes(Mach2 m2)
  = m2.pushNodes;

public Cond getCondition (Mach2 m2, int l)
{
  if(l in m2.conditions)
  {
    return m2.conditions[l];
  }
  else
  {
    return noc();
  };
}

public State NEW_State(Mach2 m2)
  = <
      //(p@l : p.at.v | p <- m2.m.elements, isPool(m2,p@l)),
      [getElement(m2,l).at.v | l <- [0..size(m2.pools)]],  //FIXME off by one
      (e@l : <0,0>  | e <- m2.m.elements, isGate(m2,e@l)),
      {}
    >;

public TempState NEW_TempState(Mach2 m2)
  = (e@l : 0 | e <- m2.m.elements, isGate(m2, e@l));

public void printTrace(list[tuple[State,Transition]] trace, Mach2 m2)
{
  for(<s,t> <- trace)
  {
    printTransition(t,m2);
    printState(s,m2);
  }
}

public str toString(State s, Mach2 m2)
{
  str r = "--[State]---------------------------------------\n";
  TempState ts = NEW_TempState(m2);
  r += "  Pools:";
  for(l <- [0..size(s.pools)]) //FIXME off by one
  {
    r += "\t<toString(getElement(m2,l).name)>\t: <state_retrieve(s, ts, m2, l)>\n";
  }
  r += "  Activated:";
  for(l <- s.activated) //FIXME off by one
  {
    r += "\t<toString(getElement(m2,l).name)>\n";
  }
  return r;
}

public void printState(State s, Mach2 m2)
{
  print(toString(s,m2));  
}

public void printTransition(Transition t, Mach2 m2)
{
  println("--[Transition]----------------------------------");
  for(<src,f,tgt> <- t)
  {
    println("\t<toString(getElement(m2,src).name)>\t-<f>-\>\t<toString(getElement(m2,tgt).name)>");
  }
}

public Mach2 machinations_preprocess(Machinations m)
{
  Mach2 m2 = NEW_Mach2;  
  m2.m = m;
  
  m2.sources = {e@l | Element e <- m.elements, isSource(e)};  
  m2.drains = {e@l | Element e <- m.elements, isDrain(e)};
  m2.gates = {e@l | Element e <- m.elements, isGate(e)};
  m2.pools = {e@l | Element e <- m.elements, isPool(e)};  
  m2.nodes = {e@l | Element e <- m.elements, (isGate(e) || isPool(e) || isSource(e) || isDrain(e))};
  
  //for checking triggers / activating nodes in a next step
  m2.pullNodes = {e@l | e <- m.elements, ((isGate(e) || isPool(e)) && e.act == act_pull()) || isDrain(e) };   
  m2.pushNodes = {e@l | e <- m.elements, ((isGate(e) || isPool(e)) && e.act == act_push()) || isSource(e)};   

  m2.elements = (e@l : e | e <- m.elements);

  m2.inflow     = (e@l : inFlow(m2, e)     | Element e <- m.elements, (isGate(e) || isPool(e) || isSource(e) || isDrain(e)));            
  m2.outflow    = (e@l : outFlow(m2, e)    | Element e <- m.elements, (isGate(e) || isPool(e) || isSource(e) || isDrain(e)));  
  m2.activators = (e@l : activators(m2, e) | Element e <- m.elements, (isGate(e) || isPool(e) || isSource(e) || isDrain(e)));
  m2.triggers   = (e@l : triggers(m2, e)   | Element e <- m.elements, (isGate(e) || isPool(e) || isSource(e) || isDrain(e)));

  //for checking triggers / activating nodes in a next step
  m2.inflowLabels =  (l : [f.s@l | f <- m2.inflow[l]] | int l <- m2.inflow);
  m2.outflowLabels =  (l : [f.t@l | f <- m2.outflow[l]] | int l <- m2.outflow);

  State s = NEW_State(m2); //temporary new state
  TempState ts = NEW_TempState(m2);
  m2.conditions = (e@l : generateCondition(s, ts, m2, e) | e <- m.elements,
   (isGate(e) || isPool(e) || isSource(e) || isDrain(e)) && hasConstantConditions(m2,e));

  m2.interleavings = interleavings(m2);

  //println("pools: <m2.pools>");
  //println("triggers: <for(t <-m2.triggers){><t> <}>");  
  println("interleavings: <m2.interleavings>");
  
  return m2;
}
  
//retrieve the incoming flow edges of a node
private list[Element] inFlow(Mach2 m2, Element n)
  = [f | f: flow(ID src, Exp exp, ID tgt) <- m2.m.elements, tgt == n.name];

//retrieve the outgoing flow edges of a node
private list[Element] outFlow(Mach2 m2, Element n)
  = [f | f: flow(ID src, Exp exp, ID tgt) <- m2.m.elements, src == n.name];

//Activators: the state edges that can deactivate this node n
//  the target is this Element n
//  the source must be a pool
//  the expression must not be a trigger
private list[Element] activators (Mach2 m2, Element n)
  = [s | s: state(ID src, Exp exp, ID tgt) <- m2.m.elements,
    tgt == n.name && exp != e_trigger() && exp != e_ref() && isPool(getElement(m2,src@l))];

//Triggers: the state edges from this pool p that can activate another node
private list[Element] triggers (Mach2 m2,
  pool (When when, Act act, How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
  = [ s | s: state(ID src, Exp exp, ID tgt) <- m2.m.elements, src == name && exp == e_trigger()];

//Triggers: the state edges from this pool p that can activate another node
private list[Element] triggers (Mach2 m2,
  source (When when, Act act, How how, ID name, list[Unit] opt_u))
  = [ s | s: state(ID src, Exp exp, ID tgt) <- m2.m.elements, src == name && exp == e_trigger()];
  
//Triggers: the state edges from this pool p that can activate another node
private list[Element] triggers (Mach2 m2,
  drain (When when, Act act, How how, ID name, list[Unit] opt_u))
  = [ s | s: state(ID src, Exp exp, ID tgt) <- m2.m.elements, src == name && exp == e_trigger()];

//Triggers: the state edges from this gate g that can activate another node
//NOTE: all state edges are triggers
private list[Element] triggers (Mach2 m2,
  gate (When when, Act act, How how, ID name, list[Unit] opt_u))
  = [ s | s: state(ID src, Exp exp, ID tgt) <- m2.m.elements, src == name];

private set[list[int]] interleavings (Mach2 m2)
{
  set[set[int]] deps = dependents(m2);
  //println("dependents <deps>");
  
  list[set[list[int]]] parts;  
  parts = 
  for(s <- deps, size(s) > 1)
  {
    set[list[int]] perms = permutations(toList(s));
    append perms;   
  }
  
  set[list[int]] prefixes = {[]};
  while(parts != [])
  {
    <part, parts> = headTail(parts);
    set[list[int]] prefixes_new = {};
    for(perm <- part)
    {
      for(prefix <- prefixes)
      {
        prefixes_new += {prefix + perm};
      }
    }
    prefixes = prefixes_new;
  }  

  return prefixes;
}

private set[set[int]] dependents (Mach2 m2)
{
  set[set[int]] deps = {dependents(m2,p) | p <- m2.m.elements, isPool(p)};
  deps = { d1 + d2 | d1 <- deps, d2 <- deps, d1 != d2, d1 & d2 != {}, size(d1) > 1, size(d2) > 1}
       + { d1, d2 | d1 <- deps, d2 <- deps, d1 != d2, d1 & d2 == {}, size(d1) > 1 || size(d2) > 1};
  return deps;
}

private set[int] dependents (Mach2 m2,
    p: pool(When when, act_pull(), How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
//  = {tgt@l | f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l), getElement(m2, tgt@l).act == act_pull()};
{
  //a = {{println(tgt); 1;} | f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l)};
  return {tgt@l | f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l), getElement(m2, tgt@l).act == act_pull()};
}

private set[int] dependents (Mach2 m2,
    p: pool(When when, act_push(), How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
  = {tgt@l | f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l)};

private bool hasConstantConditions (Mach2 m2, Element e)
{
  switch(e.act)
  {
    case act_pull():
    {
      return true notin {hasDynamics(f) | f <- getInflow(m2,e@l)};
    }
    case act_push():
    {
      return true notin {hasDynamics(f) | f <- getOutflow(m2,e@l)};
    }
  }
} 

bool hasDynamics(flow(ID src, Exp exp, ID tgt))
{
  visit(exp)
  {
    case e_name(ID name):
    {
      return true;
    }
    case e_percent(Exp e):
    {
      return true;
    }
    case e_all():
    {
      return true;
    }
  }
  return false;
}