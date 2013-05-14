module lang::machinations::Checker

import lang::machinations::Preprocessor;
import lang::machinations::Message;
import lang::machinations::State;
import lang::machinations::AST;

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

