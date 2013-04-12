@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations to Promela Translation
* @package      lang::machinations
* @file         ToPromela.rsc
* @brief        Defines the translation of Micro-Machinations to Promela
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::ToPromela

import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Preprocessor;
import lang::machinations::Serialize;
import util::Math;

private int MAX_BIT   = 1;
private int MAX_BYTE  = 255;
private int MAX_SHORT = toInt(pow(2, 15)) - 1;

public str machinations_toPromela(Mach2 m2)
 = promelaModel(m2,storageTypes(m2));

private map[str,str] storageTypes(Mach2 m2)
{
  map[str,str] ts = ();
  //TODO: add gates  
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {
    str n = e.name.name;
    str t;  
    if(e.max? && max_value(v) := e.max)
    {
      if(v <= MAX_BIT)
      {
        t = "bit";  
      }
      else if (v <= MAX_BYTE)
      {
        t = "byte";
      }
      else if (v <= MAX_SHORT)
      {
        t = "short";
      }
      else
      {
        t = "int";
      }
    }
    else
    {
      t = "int";
    }
    ts += (n : t);
  }  
  return ts;
}

//globals
private str globals(Mach2 m2, map[str,str] ts)
{
  str globals = "//pool state values\n";

  //1. for each pool generate one global. TODO: gates.
  //   choosing the type according to the maximum value --> note: create a map[str,str] name2type for this
  //   if at is defined, initialize with that value
  //   otherwise, initialize with zero
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {
    str n = e.name.name;
    int v = 0;
    if(e.at? && at_val(at_v) := e.at)
    {
      v = at_v;
    }    
    globals += "<ts[n]> <n> = <v>;\n";
  }
  
  
  //TODO: Gates

  globals += "\n//node activation state\n";
  //2. for each node generate one activation guard of type bool <name>_act
  //   initialize the bit to true if the node.when is in {auto, user, start}
  //   initialize the bit to false if the node.when is passive  
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])
  {
    str n = e.name.name;    
    globals += "bool <n>_active = <e.when != when_passive()>;\n";
  }
  
  return globals;
}

//3.     generate one active proctype with the name of the model


//3.1    locals
//3.1.1  for each node generate one guard to check a step happened calling it <name>_step       
//3.1.2  for each pool generate one value to test availability for each pool calling it <name>_old
//3.1.2  for each pool and each gate generate one value to create the new state for each pool calling it <name>_new
//       note: global <name> will function als the old state and can be used in calculations
//       for each flow edge generate an int named flow_<src>_<tgt> to store
//       note: alternatively a bit is sufficient to check if a flow edge is satisfied
private str locals(Mach2 m2, map[str,str] ts)
{
  str locals = "  //sub-step guards:\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    locals += "  bool <n>_step = true;\n";
  }
  locals += "\n";
  
  locals += "  //old values for testing availability of resources:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) //TODO: gate
  {
    str n = e.name.name;
    locals += "  <ts[n]> <n>_old = 0;\n";  
  }
  locals += "\n";

  locals += "  //new values for testing maximum and contructing next state:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) //TODO: gate
  {
    str n = e.name.name;
    locals += "  <ts[n]> <n>_new = 0;\n";    
  }  
  locals += "\n";

  locals += "  //pull guards for each flow within a node alternative:\n";
  for(l <- getPullNodes(m2))
  {
    for(flow(src,exp,tgt) <- getInflow(m2,l))
    {
      locals += "  bool flow_<l>_<src@l>_<tgt@l> = true;\n"; 
    }
  }
  locals += "\n";

  locals += "  //push guards for each flow within a node alternative:\n";
  for(l <- getPushNodes(m2))
  {
    for(flow(src,exp,tgt) <- getOutflow(m2,l))
    {
      locals += "  bool flow_<l>_<src@l>_<tgt@l> = true;\n"; 
    }
  }
  locals += "\n";

  
  locals += "  //flow calculation for triggers:\n";
  for(Element e <- [e | e <- m2.m.elements, isFlow(e)])
  {
    locals += "  int flow_<e.s@l>_<e.t@l>;\n"; //TODO: optimize type
  }
  locals += "\n";
  
  return locals;
}

//3.2    for each (atomic) step
//3.2.1  set the step guards to the value of the act guard (activated nodes will be able to do a step within this step)
//       while any of the step guards are true, perform steps
//       for each node generate the step
//       when all step guards become false break

private str promelaModel(Mach2 m2, map[str,str] ts) =
"<globals(m2,ts)>
active proctype mm ()
{
<locals(m2, ts)>
  do
  :: atomic
     {
 <prepare(m2)>
       do
<for(Element e <- m2.m.elements, isNode(e)){><toPromela(m2,e)><}>
       :: else;
          break;  
       od;
<finalize(m2)>
     };
  od;
}";

private str prepare(Mach2 m2)
{
  str r = "       //copy state to tempstate\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) //TODO: gate
  {
    str n = e.name.name;
    r += "       <n>_new = <n>;\n";
    r += "       <n>_old = <n>;\n";
  }
  return r;
}  

//3.3    at the end of each atomic step
//3.3.1  propagate what is accumulated in gates according to the round robing scheduling (TODO)
//3.3.2  for each node set the activation guards
//       assign true if a node is in automatic or user
//       assign false if a node is in passive or start
//3.3.3  for each node that has triggers //TODO: triggers
//       if all the flow on which it operates is satisfied
//         thus for each in or out flow edge check that flow_<src>_<tgt> != 0
//       then assign true to the activation guard of the triggered node
private str finalize(Mach2 m2)
{
  str r = "       //finalize step\n";  
  
  r += "       //activate when auto or user\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    r += "       <n>_active = <e.when == when_auto() || e.when == when_user()>;\n";
  }
  r += "\n";
  
  //TODO: triggers
  //for(Element e <- [e | e <- m2.getTriggers()])
  //{
  //  //get the source
  //}

  r += "       //store new state and clear temporary values\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) //TODO: gate
  {
    str n = e.name.name;
    r += "       <n> = <n>_new;\n";
    r += "       <n>_new = 0;\n";
    r += "       <n>_old = 0;\n";
  }
  r += "\n";  
  
  r += "       //re-enable steps:\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    r += "       <n>_step = true;\n";
  }
  r += "\n";
  
  
  return r;
}


private str toPromela(Mach2 m2, e: pool(when_auto(), act_pull(), how_any(),
  id(str name), list[Unit] units, at_val(int at), Add add, Min min, max_val(max))) =    
"       :: d_step
          {
          <name>_step == true; //if <name> acts
          <name>_step = false; //disable <name> from taking another step until it gets another turn
          do
          <for(f: flow(src,exp,tgt) <- getInflow(m2, e@l)){
          str src_name = toString(src);
          str tgt_name = toString(tgt);
          str flow = toString(exp);>
          :: flow_<e@l>_<src@l>_<tgt@l> == true; //if this flow may happen
             flow_<e@l>_<src@l>_<tgt@l> = false; //disable it from happening more than once         
             if
             :: <tgt_name>_new \< <max> && <src_name>_old \> 0 && <flow> \> 0;
                if
                :: <src_name>_old \>= <flow>; //source contains enough for full flow
                   if
                   :: <tgt_name>_new + <flow> \<= <max>; //the full flow fits inside the target
                      <src_name>_old = <src_name>_old - <flow>;
                      <tgt_name>_new = <tgt_name>_new + <flow>;
                      <src_name>_new = <src_name>_new - <flow>;
                   :: else; //target has capacity for less than the full flow
                      <src_name>_old = <src_name>_old - (<max> - <tgt_name>_new);
                      <src_name>_new = <src_name>_new - (<max> - <tgt_name>_new);
                      <tgt_name>_new = <max>;
                   fi;
                :: else; //source does not contain enough for full flow
                   if
                   :: <tgt_name>_new + <src_name>_old \<= <max>;
                      <tgt_name>_new = <tgt_name>_new + <src_name>;
                      <src_name>_new = 0;
                      <src_name>_old = 0;
                   :: else; //target accepts less than whatever the source can provide
                      <src_name>_new = <src_name>_new - (<max> - <name>_new);
                      <src_name>_old = <src_name>_old - (<max> - <name>_new);
                      <tgt_name>_new = <max>;
                   fi;
                fi;
             :: else;          
             fi;<}>
          :: else; //all flow guards are false
             <for(flow(src,exp,tgt) <- getInflow(m2,e@l)){>
             flow_<e@l>_<src@l>_<tgt@l> = true;
             <}>
             break;
          od
          };\n";

private str toPromela(Mach2 m2, Element e) = "";

/*
private str toPromela(p: pool(when_user(), act_pull(), how_any(),
  id(str name), list[Unit] units, at_val(int v), Add add, Min min, Max max))
{
  //emit pool value
  //emit temp pool value
  //emit step flag, init value true
}

private str toPromela(p: pool(when_passive(), act_pull(), how_any(),
  id(str name), list[Unit] units, at_val(int v), Add add, Min min, Max max))
{
  //emit pool value
  //emit temp pool value
  //emit step flag, init value false

}

private str toPromela(p: pool(when_start(), act_pull(), how_any(),
  id(str name), list[Unit] units, at_val(int v), Add add, Min min, Max max))
{
  //emit pool value
  //emit temp pool value
  //emit step flag, init value true

}
*/