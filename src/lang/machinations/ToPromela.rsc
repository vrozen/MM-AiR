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
  str globals = "";

  //1. for each pool generate one global. TODO: gates.
  //   choosing the type according to the maximum value --> note: create a map[str,str] name2type for this
  //   if at is defined, initialize with that value
  //   otherwise, initialize with zero
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {
    str n = e.name.name;
    int v = 0;
    if(e.max? && max_value(max) := e.max)
    {
      v = max;
    }    
    globals += "<ts[n]> <n> = <v>\n";
  }
  
  //TODO: Gates

  //2. for each node generate one activation guard of type bool <name>_act
  //   initialize the bit to true if the node.when is in {auto, user, start}
  //   initialize the bit to false if the node.when is passive  
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])
  {
    str n = e.name.name;    
    globals += "bool <n>_active = <e.when != when_passive()>\n";
  }
  
  return globals;
}

//3.     generate one active proctype with the name of the model


//3.1    locals
//3.1.1  for each node generate one guard to check a step happened calling it <name>_step       
//3.1.2  for each pool generate one value to test availability for each pool calling it <name>_low
//3.1.2  for each pool and each gate generate one value to create the new state for each pool calling it <name>_new
//       note: global <name> will function als the old state and can be used in calculations
//       for each flow edge generate an int named flow_<src>_<tgt> to store
//       note: alternatively a bit is sufficient to check if a flow edge is satisfied
private str locals(Mach2 m2, map[str,str] ts)
{
  str locals = "  //sub step guards:\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    locals += "  bool <n>_step;\n";
  }
  
  locals += "  //temp values for testing availability of resources:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) //TODO: gate
  {
    str n = e.name.name;
    locals += "  <ts[n]> <n>_low;\n";  
  }

  locals += "  //new values for testing maximum and contructing next state:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) //TODO: gate
  {
    str n = e.name.name;
    locals += "  <ts[n]> <n>_new;\n";    
  }  

  locals += "  //guards for each flow within a node alternative:\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])
  {
    str n = e.name.name;
    for(f_label <- {e@l | e <- getInflow(m2,e@l)})
    {
      locals += "  bool <name>_flow_<f_label> = true\n"; 
    }
  }
  
  locals += "  //flow calculation for triggers:\n";
  for(Element e <- [e | e <- m2.m.elements, isFlow(e)])
  {
    locals += "  int flow_<e.s@l>_<e.t@l>;\n"; //TODO: optimize type
  }
  
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
       do
       :: skip; //for each node generate the non-deterministic alternative        
       od;
       <finalize(m2)>
     };
  od;
}";

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
  str r = "       //finalize step";
  
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    r += "         <n>_active = <e.when == when_auto() || e.when == when_user()>;\n";
  }
  
  //TODO: triggers
  //for(Element e <- [e | e <- m2.getTriggers()])
  //{
  //  //get the source
  //}
  
  return r;
}


private str toPromela(Mach2 m2, p: pool(when_auto(), act_pull(), how_any(),
  id(str name), list[Unit] units, at_val(int at), Add add, Min min, max_val(max))) =
  ":: <name>_step == true;  //if this node gets its turn
      <name>_step = false;  //disable this node from taking another step until it gets another turn
      do
        <for(<flow,f_label> <- [<f, e@l> | f <- inFlow(m2, l), f > 0]){ >     
        :: <name>_<f_label> == true;         //if this flow may happen
           <name>_<f_label> = false;         //disable it from happening more than once
           if
           :: <src_name>_temp >= <flow>;     //source contains enough for full flow
             if
             :: <name> + <flow> \<= <max>;  //target accepts full flow
                <name> = <name> + <flow>;
                <src_name> = <src_name> - <flow>;
                <src_name>_temp = <src_name>_temp - <flow>;                
             :: else;
                if
                :: <name> \<= <max>;    //target accepts less than full flow                    
                   <src_name>_temp = <src_name>_temp - (<max> - <name>);
                   <name> = <max>;
                   <name>_temp = <max>;
                   flow_<f_label> == false;
                :: else;
                fi;
             fi;
          :: else;                        //source does not contain enough for full flow
             if
             :: <src_name>_temp \> 0      //source has resources
                && <name> \< <max>;       //target accepts resources
                if
                :: <name> + <src_name>_temp \<= <max>;
                   <name> = <name> + <src_name>;
                   <name>_temp = <name>_temp + <src_name>;
                   <src_name>_temp = 0;
                :: else;
                   if
                   :: <src_name> = <src_name> - (<max>-<name>);
                      <name> = <max>;
                      <name>_temp = <max>;
                   :: else;
                   fi;
                fi;
             :: else; //source has no resources or nothing fits
          fi;
       od;
    <}>";

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