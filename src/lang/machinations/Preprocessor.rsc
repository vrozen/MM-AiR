@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Preprocessor  --> is actually a static analyzer
* @package      lang::machinations
* @file         Preprocessor.rsc
* @brief        The preprocessor processes an AST and calculates constants
*               that are necessary during run-time phases. 
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/

module lang::machinations::Preprocessor

import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Evaluator;
import lang::machinations::Serialize;
import IO;
import List;
import Set;
import util::Math;

public Mach2 mm_limit(Mach2 m2, int max)
{
  return visit(m2)
  {
    case max_none():
    {
      insert max_val(max);
    }
  }
}

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
  
public tuple
    [
      set[list[int]] pullAllI,
      set[list[int]] pullAnyI,
      set[list[int]] pushAllI,
      set[list[int]] pushAnyI
    ] getInterleavings(Mach2 m2)
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
 
public set[int] getPullAllNodes(Mach2 m2)
  = m2.pullAllNodes;
  
public set[int] getPullAnyNodes(Mach2 m2)
  = m2.pullAnyNodes;
  
public set[int] getPushAllNodes(Mach2 m2)
  = m2.pushAllNodes;

public set[int] getPushAnyNodes(Mach2 m2)
  = m2.pushAnyNodes;

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

public str toString(State s, Mach2 m2) =
  "--[State]---------------------------------------
  '  Pools:<for(l <- [0..size(s.pools)]){>
  '    <toString(getElement(m2,l).name)>\t: <state_retrieve(s, NEW_TempState(m2), m2, l)><}>
  '  Activated:<for(l <- activeNodes(s, NEW_TempState(m2), m2)){>
  '    <toString(getElement(m2,l).name)><}>\n";

public str toString(Transition t, Mach2 m2) =
  "--[Transition]----------------------------------<for(<src,f,tgt> <- t){>
  '  <toString(getElement(m2,src).name)>\t-<f>-\>\t<toString(getElement(m2,tgt).name)><}>\n";
  
public str toString(list[tuple[State,Transition]] trace, Mach2 m2) =
  "<for(<s,t> <- trace){><toString(t, m2)><toString(s, m2)><}>";

public void printState(State s, Mach2 m2)
{
  println(toString(s,m2));  
}

public void printTransition(Transition t, Mach2 m2)
{
  println(toString(t,m2));
}

public Mach2 mm_preprocess(Machinations m)
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

  m2.pullAllNodes = {e@l | e <- m.elements, isNode(e) && e.act == act_pull() && e.how == how_all()};
  m2.pullAnyNodes = {e@l | e <- m.elements, isNode(e) && e.act == act_pull() && e.how == how_any()};
  m2.pushAllNodes = {e@l | e <- m.elements, isNode(e) && e.act == act_push() && e.how == how_all()};
  m2.pushAnyNodes = {e@l | e <- m.elements, isNode(e) && e.act == act_push() && e.how == how_any()};

  m2.elements = (e@l : e | e <- m.elements);

  m2.inflow     = (e@l : inFlow(m2, e)     | Element e <- m.elements, isNode(e));            
  m2.outflow    = (e@l : outFlow(m2, e)    | Element e <- m.elements, isNode(e));  
  m2.activators = (e@l : activators(m2, e) | Element e <- m.elements, isNode(e));
  m2.triggers   = (e@l : triggers(m2, e)   | Element e <- m.elements, isNode(e));

  //for checking triggers / activating nodes in a next step
  m2.inflowLabels =  (l : [f.s@l | f <- m2.inflow[l]] | int l <- m2.inflow);
  m2.outflowLabels =  (l : [f.t@l | f <- m2.outflow[l]] | int l <- m2.outflow);

  State s = NEW_State(m2); //temporary new state
  TempState ts = NEW_TempState(m2);
  m2.conditions = (e@l : generateCondition(s, ts, m2, e) | e <- m.elements,
   (isGate(e) || isPool(e) || isSource(e) || isDrain(e)) && hasConstantConditions(m2,e));


  m2.pullAllGroups = groups(m2, act_pull(), how_all());
  m2.pullAnyGroups = groups(m2, act_pull(), how_any());
  m2.pushAllGroups = groups(m2, act_push(), how_all());
  m2.pushAnyGroups = groups(m2, act_push(), how_any());
  
  m2.pullAllRemainder = {l | int l <- m2.pullAllNodes, l notin {*g | set[int] g <- m2.pullAllGroups}};
  m2.pullAnyRemainder = {l | int l <- m2.pullAnyNodes, l notin {*g | set[int] g <- m2.pullAnyGroups}};
  m2.pushAllRemainder = {l | int l <- m2.pushAllNodes, l notin {*g | set[int] g <- m2.pushAllGroups}};
  m2.pushAnyRemainder = {l | int l <- m2.pushAnyNodes, l notin {*g | set[int] g <- m2.pushAnyGroups}};
  

  println("1: pull all groups: <m2.pullAllGroups>");
  println("2: pull all remainder: <m2.pullAllRemainder>");
  
  println("3: pull any groups: <m2.pullAnyGroups>");
  println("4: pull any remainder: <m2.pullAnyRemainder>");

  println("5: push all groups: <m2.pushAllGroups>");
  println("6: push all remainder: <m2.pushAllRemainder>");
  
  println("7: push any groups: <m2.pushAnyGroups>");
  println("8: push any remainder: <m2.pushAnyRemainder>");
  

  //println("pools: <m2.pools>");
  //println("triggers: <for(t <-m2.triggers){><t> <}>");  
  //println("interleavings: <m2.interleavings>");
  
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
    tgt == n.name && exp != e_trigger() && exp != e_ref() /*&& isPool(getElement(m2,src@l))*/];

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

//calculate groups of competing nodes (act the same, how the same)
private set[set[int]] groups (Mach2 m2, Act act, How how)
{
  set[set[int]] competitors =
    {competitors(m2,n@l,n.when,n.act,n.how) | n <- m2.m.elements, isNode(n) && n.act == act, n.how == how};

  println("Group competitors <competitors>");
  
  set[set[int]] groups
     = { d1 + d2 | d1 <- competitors, d2 <- competitors, d1 != d2, d1 & d2 != {}, size(d1) > 1, size(d2) > 1}
     + { d1, d2  | d1 <- competitors, d2 <- competitors, d1 != d2, d1 & d2 == {}, size(d1) > 1 || size(d2) > 1}
     + { d | d <- competitors, size(competitors) == 1};

  println("groups <groups>");
  
  for(g <- groups)
  {
    print("Competing group {");
    for(c <- g)
    {
      print("<getElement(m2,c).name.name> ");
    }
    println("}");
  }
 
  return groups;
}

//calculate push competitors of a node with label l
private set[int] competitors (Mach2 m2, int l /*node label*/, When when, act_push(), How how)
{
  set[int] competitors = {};
  if(when != when_passive() || canBeTriggered(m2, l))
  {
    for(flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, l))
    {
      Element target = getElement(m2, tgt@l);
      if(isPool(target) && max_val(int v) := target.max)
      {
        for(flow(ID src2, Exp exp2, ID tgt2) <- getInflow(m2, target@l), src2@l != l)
        {
          Element competitor = getElement(m2, src2@l);
          if(competitor.act == act_push() && competitor.how == how &&
            (competitor.when != when_passive() || canBeTriggered(m2, competitor@l)))
          {
            competitors += {competitor@l}; //node competitor competes with node e
          }
        }
      }
    }
  }
  
  println("Nodes competing with <l> <toString(how)> <getElement(m2,l).name.name> are {<for(int c <- competitors){><getElement(m2,c).name.name> <}>}");
  
  if(competitors != {})
  {
    competitors += {l};
  }
  
  return competitors; 
}

//calculate pull competitors of a node with label l
private set[int] competitors (Mach2 m2, int l /*node label*/, When when, act_pull(), How how)
{
  set[int] competitors = {};
  if(when != when_passive() || canBeTriggered(m2, l))
  {
    for(flow(ID src, Exp exp, ID tgt) <- getInflow(m2, l))
    {
      Element source = getElement(m2, src@l);
      if(isPool(source))
      {
        for(flow(ID src2, Exp exp2, ID tgt2) <- getOutflow(m2, source@l), tgt2@l != l)
        {
          Element competitor = getElement(m2, tgt2@l);     
          if(competitor.act == act_pull() && competitor.how == how &&
            (competitor.when != when_passive() || canBeTriggered(m2, competitor@l)))
          {
            competitors += {competitor@l}; //node competitor competes with node e
          }
        }
      }
    }
    
    //something that pulls and has a maximum competes with whatever pulls from it
    Element e = getElement(m2, l);
    if(isPool(e) && max_val(int v) := e.max) //I'm a pool and have a max, pulling and possibly active
    {
      for(flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, l))
      {
        Element competitor = getElement(m2, tgt@l);
        if(competitor.act == act_pull() && competitor.how == how &&
          (competitor.when != when_passive() || canBeTriggered(m2, competitor@l)))
        {
          competitors += {competitor@l};  
        }
      }
    }
  }
  
  println("Nodes competing with <l> <toString(how)> <getElement(m2,l).name.name> are {<for(int c <- competitors){><getElement(m2,c).name.name> <}>}");
  
  if(competitors != {})
  {
    competitors += {l};
  }
  
  return competitors; 
}

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

public set[int] triggeredBy(Mach2 m2, int l)
  = {s@l | e: state(ID s, e_trigger(), ID t) <- m2.m.elements, t@l == l};

public bool canBeTriggered(Mach2 m2, int l)
  = triggeredBy(m2,l) != {};