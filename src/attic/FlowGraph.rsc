module lang::machinations::FlowGraph

import lang::machinations::AST;
import lang::machinations::Labeler;
import lang::machinations::Message;
import IO;

alias DFSeg
  = tuple[set[int]           source,
          rel[int, int, int] flow,
          set[int]           drain];

alias ComponentTypeFlow = 
  tuple
  [
    DFSeg seg,
    map[int, Element] l2e
  ];

alias MachinationsFlow = 
  map[ID name, ComponentTypeFlow ctf];

public tuple[list[Msg],MachinationsFlow] getFlow (Machinations m, MachinationsInfo mi)
{
  MachinationsFlow mf = ();
  list[Msg] msgs = [];
  
  for(<n,<ct,cti>> <- {<n, mi[n]> | n <- mi})
  {
    <cmsgs, ctf> = getFlow(ct, cti);
    mf += (n: ctf);
    msgs += cmsgs;
  }

  return <msgs, mf>;
}

private tuple[list[Msg] msgs,ComponentTypeFlow flow] getFlow (ComponentType ct, ComponentTypeInfo cti)
{
  map[FLabel, Element] es = ();
  rel[FLabel,FLabel,FLabel] flow = {};
  set[FLabel] source = {};
  set[FLabel] drain = {};
  FLabel l = 0;  
  list[Msg] msgs = [];
  
  for(e: flow(ID src, Exp exp, ID tgt) <- ct.elements)
  {    
    if(src notin cti.n2l)
    {
      msgs += [nameError(src)];
    }
    else if(tgt notin cti.n2l)
    {
      msgs += [nameError(tgt)];
    }  
    else
    {
      l = l + 1;
      flow += {<cti.n2l[src], l, cti.n2l[tgt]>};
      es += (l : e);
    }
  }
  
  for(ns <- [names | source(list[ID] names, list[ID] opt_u)<- ct.elements])
  {
    source += {n@l | n <- ns};   
  }
  
  for(ns <- [names | drain(bool pullAll, list[ID] names, list[ID] opt_u) <- ct.elements])
  {
    drain += {n@l | n <- ns};
  }
  
  return <msgs, <<source, flow, drain>, es>>;
}
