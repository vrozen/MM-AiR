module lang::machinations::Checker

import lang::machinations::Preprocessor;
import lang::machinations::Serialize;
import lang::machinations::Message;
import lang::machinations::State;
import lang::machinations::AST;
import lang::machinations::Syntax;
import lang::machinations::ToPromela;
import lang::machinations::Writer;
import List;
import Set;
import IO;
import String;
import lang::promela::Spin;
import ParseTree;

/*
The contextual analyzer should check for
- absence of missing names (done by the labeler now)
- existence of types and (done by instantiator now)
- definedness of component references (done by instantiator now)
- correctness of units of measurement (this is low priority)
- OK: maximum one flow between two nodes
- OK: absence of flow to sources
- OK: absence of flow from drains
- OK: absence of pushing gates
- OK: absence of pulling on gates 
- OK: two nodes acting upon the same flow edge
- OK: no nodes ever acting upon a flow edge

// partial static analysis possible
- flow must be positive
- flow can never fit in pool
*/

//The reach map structure defines which lines
//must be reached in order for a node to be reached.
//* all nodes have - one reach_all
//* any nodes have - one reach_all and three reach any's
//* nodes can have triggers
//Note: inhibitor edges are currently missing
public alias ReachMap
  = map
  [
    int l,           //node label
    set[Reach] edges //pieces of code generated for edges the node operates on
  ];


//Reach defines which lines of promela
//must be reached for a node to operate on flows and triggers.
//Note: flow can be operated on by src and tgt nodes,
//      which results in separate pieces of Promela code.
// src  = source label
// tgt  = target label
// line = Promela line
anno int Reach@line;
public data Reach
  = reach_flow_all (int l, int edge)
  | reach_flow_any (int l, int edge)
  | reach_trigger  (int l, int edge);

public list[Msg] mm_check(Mach2 m2)
  = checkFlow(m2)
  + checkGate(m2)
  + checkSource(m2)
  + checkDrain(m2);

private list[Msg] checkFlow(Mach2 m2)
{
  list[Msg] msgs = [];
  for(Element f1 <- m2.m.elements, isFlow(f1))
  {
    //check maximum one flow between two nodes
    for(Element f2 <- m2.m.elements - f1, isFlow(f2))
    {
      if(f1.s == f2.s && f1.t == f2.t)
      {
        msgs += [(msg_DuplicateFlow(f1,f2))];
      }
    }
    
    //check pushing and pulling on the same flow edge
    //check (surely) unused flow edge
    Element s = getElement(m2, f1.s@l);
    Element t = getElement(m2, f1.t@l);
    if(s.act == act_push() && t.act == act_pull()
       && (s.when != when_passive() || triggeredBy(m2, s@l) != {})
       && (t.when != when_passive() || triggeredBy(m2, t@l) != {}))
    {
      msgs += [msg_TwiceUsedFlowEdge(f1)];
    }
    else if(s.act == act_pull() && t.act == act_push())
    {
      msgs += [msg_UnusedFlowEdge(f1)];
    }
  }
  return msgs;
}

private list[Msg] checkTrigger(Mach2 m2)
{
  
  //list[Element] triggers = getTriggers (Mach2 m2, int l);
  
}

//for each gate, its Act sate is not act_push()
private list[Msg] checkGate(Mach2 m2)
{
  list[Msg] msgs = [];
  for(Element e <- m2.m.elements, isGate(e))
  {
    if(gate(When when, act_push(), How how, ID name, list[Unit] opt_u) := e)
    {
      msgs += [msg_PushingGate(e.name)];
    }
    
    for(flow(ID src, Exp f, ID tgt) <- getOutflow(m2, e@l))
    {
      Element e2 = getElement(m2, tgt@l);
      if(e2.act == act_pull() &&
         (e2.when != when_passive() || triggeredBy(m2, e2@l) != {}))
      {
        msgs += [msg_PullingOnGate(e2.name, e.name)];
      }
    }
  }
  return msgs;
}

//for each drain, its outflow is empty
private list[Msg] checkDrain(Mach2 m2)
{
  list[Msg] msgs = [];
  for(Element e <- m2.m.elements, isDrain(e))
  {
    for(Element f <- getOutflow(m2, e@l))
    {      
      msgs += [msg_DrainHasOutflow(e.name, f)];
    }
  }
  return msgs;
}

//for each source, its inflow is empty
private list[Msg] checkSource(Mach2 m2)
{
  list[Msg] msgs = [];
  for(Element e <- m2.m.elements, isSource(e))
  {
    for(Element f <- getInflow(m2, e@l))
    {
      msgs += [msg_SourceHasInflow(e.name, f)];
    }
  }
  return msgs;
}


public list[Element] mm_checkUnreachable (Mach2 m2)
{
  list[int] unreached_lines = []; 
  loc svr_file = |<m2.m@location.scheme>://<m2.m@location.authority><m2.m@location.path>|;
  svr_file.extension = "svr";
  //println("SVR file <svr_file>");
  
  Spin report = spin_implode(spin_parse(svr_file));
  
  visit(report)
  {
    case line 
    (
      str file,
      int line,
      int state,
      str text
    ):
    {
      unreached_lines += [line];
    }
  }
  println("Unreached lines <unreached_lines>");
  
  
  loc pml_file = |<m2.m@location.scheme>://<m2.m@location.authority><m2.m@location.path>|;
  pml_file.extension = "pml";
  //println("PML file <pml_file>");
 
  list[str] lines = readFileLines(pml_file); 
  
  //println("Analyze pml file");
    
  list[Reach] rs = [];
  int l = 0;
  for(str line <- lines)
  {
    l = l + 1;
    if(contains(line, "MM: reach"))
    {
      str reach = substring(line, findLast(line,"MM:") + 4, size(line));
      Tree t = parse(#lang::machinations::Syntax::Reach, reach);
      Reach r = implode(#Reach, t);
      rs = rs + [r[@line = l]];
    }
  }
 
  ReachMap r = (e@l: {r | r <- rs, r.l == e@l} | e <- m2.m.elements, isNode(e));  
  //println(r);
  
  list[Element] unreachable = [];
  for(int l <- r)
  {
    Element e = getElement(m2, l);
    set[Reach] elements = r[l];   
    set[int] anyFlow = {f@line | f: reach_flow_any (_,_) <- elements};
    set[int] allFlow = {f@line | f: reach_flow_all (_,_) <- elements};
    
    if(e.how == how_any() && anyFlow == {} && size(allFlow)==1)
    {
      println("Node <e.name.name> behaves like all instead of any at line <e@location.begin.line> column <e@location.begin.column>");
    }
    
    if((e.when != when_passive() || canBeTriggered(m2,e@l)) && anyFlow == {} && allFlow == {} )
    {
      if(e.act == act_pull())
      {
        println("Node <toString(e.name)> never pulls at line <e@location.begin.line> column <e@location.begin.column>");
      }
      else if(e.act == act_push())
      {
        println("Node <toString(e.name)> never pushes at line <e@location.begin.line> column <e@location.begin.column>");      
      }
    }

    for(trig: reach_trigger(_, int t) <- elements, trig@line == l)
    {
      Element trigger = getElement(m2,t);
      println("Trigger <toString(trigger)> never activates <toString(trigger.t)> at line <trigger@location.begin.line> column <trigger@location.begin.column>");
    }
    
  }
  
  return unreachable; 
}
