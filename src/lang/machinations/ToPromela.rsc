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
import IO;

import List;

private int MAX_BIT   = 1;
private int MAX_BYTE  = 255;
private int MAX_SHORT = toInt(pow(2, 15)) - 1;

public str mm_toPromela(Mach2 m2)
 = promelaModel(m2,storageTypes(m2));

private map[str,str] storageTypes(Mach2 m2)
{
  map[str,str] ts = ();
  //pools
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

  //1. for each pool generate one global
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
    globals += "<ts[n]> <n> = <v>; //label <e@l>\n"; //pool declaration and initial value
  }
  
  //Gates
  globals += "//gate state values\n";
  for(Element e <- [e | e <- m2.m.elements, isGate(e)])
  {
    str n = e.name.name;
    globals += "int <n> = 0; //label <e@l>\n";
    globals += "byte <n>_s = 0; //label <e@l>\n"; //gate edge number
    globals += "int <n>_c = 0;  //label <e@l>\n"; //gate edge count
  }
  
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
    //if it is automatic or can be triggered
    if(e.when == when_auto() || e.when == when_user() || canBeTriggered(m2,e@l))
    {   
      str n = e.name.name;
      locals += "  bool <n>_step;\n"; //initialized later
    }
  }
  locals += "\n";  
  
  locals += "  bool commit = true; //commit all guard\n";
  
  locals += "  //temporary old pool values for testing availability of resources:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {
    str n = e.name.name;
    locals += "  <ts[n]> <n>_old = 0;\n";  
  }
  locals += "\n";

  locals += "  //temporary new pool values for testing maximum and contructing next state:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {  
    str n = e.name.name;
    locals += "  <ts[n]> <n>_new = 0;\n";    
  }  
  locals += "\n";

  locals += "  //temporary new pool values for testing maximum and contructing next state:\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {  
    str n = e.name.name;
    locals += "  <ts[n]> <n>_old_try = 0;\n";    
    locals += "  <ts[n]> <n>_new_try = 0;\n";
  }  
  locals += "\n";

  locals += "  //pull guards for each flow within a node alternative:\n";
  for(l <- getPullNodes(m2))
  {
    //if it is automatic or can be triggered
    Element e = getElement(m2,l);
    if(e.when == when_auto() || e.when == when_user() || canBeTriggered(m2,l))
    {
      for(flow(src,exp,tgt) <- getInflow(m2,l))
      {
        locals += "  bool flow_<l>_<src@l>_<tgt@l> = true; //<e.name.name>\n";  
      }
    }
  }
  locals += "\n";

  locals += "  //push guards for each flow within a node alternative:\n";
  for(l <- getPushNodes(m2))
  {
    //if it is automatic or can be triggered
    Element e = getElement(m2,l);
    if(e.when == when_auto() || e.when == when_user() || canBeTriggered(m2,l))
    {
      for(flow(src,exp,tgt) <- getOutflow(m2,l))
      {
        locals += "  bool flow_<l>_<src@l>_<tgt@l> = true;\n"; 
      }
    }
  }
  locals += "\n";

  
  locals += "  //temporary flow calculation for triggers:\n";
  for(Element e <- [e | e <- m2.m.elements, isFlow(e)])
  {
    locals += "  int flow_<e.s@l>_<e.t@l>;\n"; //TODO: optimize type?
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
  'active proctype mm ()
  '{
  '<locals(m2, ts)>
  '  do
  '  :: atomic //each active or activated, non-disabled node can act
  '     {
  '       printf(\"MM: step\\n\");
  '<prepare(m2)>
  '       do
  '<for(Element e <- m2.m.elements, isNode(e))
    {><if(e.when != when_passive() || canBeTriggered(m2,e@l))
       {><toPromela(m2, e, e.act, e.how)><
       }><
    }>
  '       :: else -\> break;  
  '       od;
  '<finalize(m2)>
  '     };
  '  od;
  '}
  '
  '<monitor(m2,ts)>
  ";//
  

private str prepare(Mach2 m2) =
 "       //copy state to tempstate<for(Element e <- [e | e <- m2.m.elements, isPool(e)]) { str n = e.name.name;> 
 '       <n>_new = <n>;
 '       <n>_old = <n>;
 <}>
 '       //enable steps:<
   for(Element e <- [e | e <- m2.m.elements, isNode(e)]){><
     if(e.when == when_auto() || canBeTriggered(m2, e@l)){ str n = e.name.name; >
 '       if
 '       :: <n>_active == true <for(state(ID s, Exp e, ID t) <- getActivators(m2, e@l)){>&& <toString(e)><}> -\> <n>_step = true;
 '       :: else;
 '       fi;<
     }><
   }>
 '     
 ";

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

  r += "       //activate via triggers\n";
  //for each node that has triggers
  //   if each flow is satisfied
  //   then the flow along each edge on which the node operates is greater or equal to the flow expression
  //   then activate the nodes the trigger refers to

  for(int l <- getPullNodes(m2))
  {
    list[Element] ts = getTriggers(m2,l);
    if(ts != [])
    {
      //get the inflow      
      r += "       if\n";
      r += "       :: ";
      for(flow(ID s, Exp exp, ID t) <- getInflow(m2,l))
      {
        r += "flow_<s@l>_<t@l> \>= <toString(exp)> && ";
      }
      r += "true -\>\n";
      for(state(ID s, Exp exp, ID t) <- ts)
      {
        r += "        <t.name>_active = true;";
      }
      r += "\n";
      r += "       :: else;\n";
      r += "       fi;\n";
    }
  }
  
  for(int l <- getPushNodes(m2))
  {
    list[Element] ts = getTriggers(m2,l);     
    if(ts != [])
    {
      //get the inflow      
      r += "       if\n";
      r += "       :: ";
      for(flow(ID s, Exp exp, ID t) <- getOutflow(m2,l))
      {
        r += "flow_<s@l>_<t@l> \>= <toString(exp)> && ";
      }
      r += "true -\> ";
      for(state(ID s, Exp exp, ID t) <- ts)
      {
        r += "<t.name>_active = true; ";
      }
      r += "\n";
      r += "       :: else;\n";
      r += "       fi;\n";
    }
  }
  r += "\n";
  
  r += "       //clear temporary transition data from state\n";
  for(Element e <- [e | e <- m2.m.elements, isFlow(e)])
  {
    r += "       flow_<e.s@l>_<e.t@l> = 0;\n";
  }
  r += "\n";
 
  r += "       //store new state and clear temporary values\n";
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) 
  {
    str n = e.name.name;
    r += "       <n> = <n>_new;
         '       <n>_new = 0;
         '       <n>_old = 0;
         '       <n>_new_try = 0;
         '       <n>_old_try = 0;\n";
  }
  r += "\n";

  r += redistribute(m2) + "\n";
  
  /*
  r += "       //re-enable steps:\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    if(e.when == when_auto() || canBeTriggered(m2, e@l))
    {
      str n = e.name.name;
      r += "       <n>_step = true;\n";
    }
  }
  r += "\n";*/
  
  r += "       //activate when auto or user\n";
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    switch(e.when)
    {
      case when_auto():
      {
        r += "       <n>_active = true;\n";  
      }
      case when_user():
      {
        r +=
        "       if
        '       :: <n>_active = true;
        '       :: <n>_active = false;
        '       fi;";
      }
    }
  }
  r += "\n";
  return r;
}

public str monitor(m2,ts) =
  "active proctype monitor()
  '{
  '  do<for(always(ID name, Exp exp, str msg) <- m2.m.elements){>
  '  :: !(<toString(exp)>) -\>
  '     printf(\"MM: violate(<toString(name)>)\\n\");
  '     assert(<toString(exp)>); //<msg><}>
  '  od;
  '}";

private str redistribute(Mach2 m2) =
  "       //redistribute gates
  '       do<for(e <- m2.m.elements, isGate(e)){>
  '       <redistribute(m2,e)><}>
  '       :: else -\> //all gates have redistributed         
  '          break;   //exit redistribution phase
  '       od;";

//implement round-robin scheduling of gates
private str redistribute(Mach2 m2, g: gate(When when, Act act, How how, ID n, list[Unit] opt_u))
{
  list[Element] fs = getOutflow(m2, g@l);
  str name = n.name;

  return
     ":: <name> != 0 -\> //this should be for each gate!
         if
         <for(selected <- [0..size(fs)]){
           Element f = fs[selected];
           str flow = toString(f.exp); 
           str tgtName = f.t.name;
           int max = 0;
           bool tgtIsPool = isPool(m2, f.t@l);
           if(tgtIsPool)
           {
             Element e = getElement(m2, f.t@l);
             println(toString(e));
             max = e.max.v;
           }>
         :: <name>_s == <selected>;
            if    
            :: <flow> \>= 0  //if flow is positive 
               <if(tgtIsPool){>&& <tgtName> \< <max><}> /*and the target is not full*/ ;
               -\>
               if
               :: <name> \>= (<flow> - <name>_c); //if the full flow is available
                 <if(tgtIsPool){>
                 if
                 :: <tgtName> + (<flow> - <name>_c) \<= <max>; //if the full flow fits into the target
                 <}>                 
                    printf(\"MM: flow(<name>,%d,<tgtName>)\\n\",(<flow>));
                    <tgtName> = <tgtName> + (<flow> - <name>_c); //add the flow to the target
                    <name> = <name> - (<flow> - <name>_c); //remove the flow from the gate
                 <if(tgtIsPool){>
                 :: else -\> ; //the target has capacity for less than the full flow
                    printf(\"MM: flow(<name>,%d,<tgtName>)\\n\",(<max> - <tgtName>));
                    <name> = <name> - (<max> - <tgtName>); //remove the target remaining capacity from the gate
                    <tgtName> = <max>; //max out the target
                 fi;
                 <}>
                 <if(selected < size(fs) - 1){><name>_s = <name>_s + 1; <} else {><name>_s = 0;<}> //select the next edge
                 <name>_c = 0; //reset count
              :: else -\> //the full flow is not available  
                 <if(tgtIsPool){>             
                 if
                 :: <name> \< (<max> - <tgtName>) -\> //if whatever is available fits into the target
                 <}>
                    printf(\"MM: flow(<name>,%d,<tgtName>)\\n\",(<name>));
                    <tgtName> = <tgtName> + <name>; //add what is available to the target
                    <name>_c = <name>_c + <name>; //add what flows to the count
                    <name> = 0; //empty the gate
                 <if(tgtIsPool){>                
                 :: else -\> //whatever is available does not fit the target
                    printf(\"MM: flow(<name>,%d,<tgtName>)\\n\",(<max> - <tgtName>));
                    <name> = <name> - (<max> - <tgtName>); //remove the target remaining capacity from the gate
                    <name>_c = <name>_c + (<max> - <tgtName>); //add what flows to the count
                    <tgtName> = <max>; //max out the target                 
                 fi;
                 <}>
              fi;
            :: else -\> //the target is full and fits nothing else or the flow is not positive           
               <if(selected < size(fs) - 1){><name>_s = <name>_s + 1; <} else {><name>_s = 0;<}> //select the next edge 
           fi;<}>
         fi;";
}

//pull any pool is a deterministic step
private str toPromela(Mach2 m2, Element e, act_pull(), how_any())
{
  str name = e.name.name;
  return
    "       :: //d_step //pull any <name>
    '          //{
    '            <name>_step == true -\> //if <name> acts
    '            <name>_step = false; //disable <name> from taking another step until it gets another turn
    '            do
                 '<for(f <- getInflow(m2, e@l)){>
                 '<toPromela(m2, e@l, f, how_any())><}>
    '            :: else -\> //all flow guards are false, renable the transition
                    <for(flow(src,exp,tgt) <- getInflow(m2,e@l)){>
    '               flow_<e@l>_<src@l>_<tgt@l> = true;
    '               <}>
    '               break;
    '            od;
    '          //};\n";
}

//pull all pool is a deterministic step
private str toPromela(Mach2 m2, Element e, act_pull(), how_all())
{
  str name = e.name.name;
  return
    "       :: //d_step //pull all <name> 
    '          //{
    '            <name>_step == true -\> //if <name> acts
    '            <name>_step = false; //disable <name> from taking another step until it gets another turn
    '            commit = true;<
                 for(f: flow(src,exp,tgt) <- getInflow(m2, e@l)){
                   str src_name = toString(src);
                   str tgt_name = toString(tgt);><
                   if(isPool(m2, src@l)){>
    '            <src_name>_new_try = <src_name>_new;
    '            <src_name>_old_try = <src_name>_old;<
                   }><
                   if(isPool(m2, tgt@l)){>
    '            <tgt_name>_new_try = <tgt_name>_new;
    '            <tgt_name>_old_try = <tgt_name>_old;<
                   }><
                 }>
    '            do<
                 for(f: flow(src,exp,tgt) <- getInflow(m2, e@l)){>
                   '<toPromela(m2, e@l, f, how_all())><}>
    '            :: else -\>  //all flow guards are false
    '               break; //done (commit = true)
    '            od;
    '            if
    '            :: commit == true;<
                 for(f: flow(src,exp,tgt) <- getInflow(m2, e@l)){
                    str src_name = toString(src);
                    str tgt_name = toString(tgt);
                    str flow = toString(exp);>
    '               printf(\"MM: flow(<src_name>,%d,<tgt_name>)\\n\",<flow>);
    '               flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + <flow>;<
                    if(isPool(m2,src@l)){>
    '               <src_name>_new = <src_name>_new_try;
    '               <src_name>_old = <src_name>_old_try;<}><
                    if(isPool(m2,tgt@l)){>
    '               <tgt_name>_new = <tgt_name>_new_try;
    '               <tgt_name>_old = <tgt_name>_old_try;<}><
                 }>
    '            :: else; //do not commit
    '            fi;
    '            //re-enable the transition
    '            <for(flow(src,exp,tgt) <- getInflow(m2,e@l)){>
    '            flow_<e@l>_<src@l>_<tgt@l> = true;<}>
    '          //};\n";
}

//push any pool is not a deterministic step
private str toPromela(Mach2 m2, Element e, act_push(), how_all())
{
  str name = e.name.name;
  return 
  "       :: //push all <name>
  '         <name>_step == true -\> //if <name> acts
  '         <name>_step = false; //disable <name> from taking another step until it gets another turn
  '         commit = true;<
            for(f: flow(src,exp,tgt) <- getOutflow(m2, e@l)){
              str src_name = toString(src);
              str tgt_name = toString(tgt);><
              if(isPool(m2, src@l)){>
  '         <src_name>_new_try = <src_name>_new;
  '         <src_name>_old_try = <src_name>_old;<
              }><
              if(isPool(m2, tgt@l)){>
  '         <tgt_name>_new_try = <tgt_name>_new;
  '         <tgt_name>_old_try = <tgt_name>_old;<
              }><
            }>
  '         do<
            for(f: flow(src,exp,tgt) <- getOutflow(m2, e@l)){>
              '<toPromela(m2, e@l, f, how_all())><
            }>
  '         :: else -\>  //all flow guards are false
  '            break; //done (commit = true)
  '         od;
  '         if
  '         :: commit == true -\><
               for(f: flow(src,exp,tgt) <- getOutflow(m2, e@l)){
                 str src_name = toString(src);
                 str tgt_name = toString(tgt);
                 str flow = toString(exp);>
  '            printf(\"MM: flow(<src_name>,%d,<tgt_name>)\\n\",<flow>);
  '            flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + <flow>;<
                 if(isPool(m2, src@l)){>                    
  '            <src_name>_new = <src_name>_new_try;
  '            <src_name>_old = <src_name>_old_try;<
                 }><
                 if(isPool(m2, tgt@l)){>
  '            <tgt_name>_new = <tgt_name>_new_try;
  '            <tgt_name>_old = <tgt_name>_old_try;<
                 }><
               }>
  '         :: else; commit = true; //do not commit
  '         fi;
  '         //re-enable the transition
  '         <for(flow(src,exp,tgt) <- getOutflow(m2,e@l)){>
  '         flow_<e@l>_<src@l>_<tgt@l> = true;<
            }>";
}

private str toPromela(Mach2 m2, Element e, act_push(), how_any())
{
  throw "Push any not supported on: <toString(e)>.";
}


private str toPromela(Mach2 m2, int l, e: flow(ID src, Exp exp, ID tgt), how_all())
{
  str src_name = toString(src);
  str tgt_name = toString(tgt);
  str flow = toString(exp);

  bool srcIsPool = isPool(m2, src@l);
  bool tgtIsPool = isPool(m2, tgt@l);
  int max = 0;
  if(tgtIsPool)
  {
    Element e = getElement(m2, tgt@l);
    println(toString(e));
    max = e.max.v;
  }
  
  return  
    "            :: flow_<l>_<src@l>_<tgt@l> == true; //if this flow may happen
    '               flow_<l>_<src@l>_<tgt@l> = false; //disable it from happening more than once         
    '               if
    '               :: <flow> \> 0
    '                  <if(srcIsPool){>&& <src_name>_old_try \>= <flow><}> /*source contains enough for full flow*/
    '                  <if(tgtIsPool){>&& <tgt_name>_new_try + <flow> \<= <max> /*the full flow fits inside the target*/<}> -\>
    '                  <if(srcIsPool){><src_name>_old_try = <src_name>_old_try - <flow>;<}>
    '                  <if(tgtIsPool){><tgt_name>_new_try = <tgt_name>_new_try + <flow>;<}>
    '                  <if(srcIsPool){><src_name>_new_try = <src_name>_new_try - <flow>;<}>
    '               :: else -\>  //roll-back transaction
    '                  commit = false;
    '                  break;
    '               fi;";
}


private str toPromela(Mach2 m2, int l, e: flow(ID src, Exp exp, ID tgt), how_any())
{
  str src_name = toString(src);
  str tgt_name = toString(tgt);
  str flow = toString(exp);
  bool srcIsPool = isPool(m2,src@l);
  bool tgtIsPool = isPool(m2,tgt@l);
  bool tgtIsGate = isGate(m2,tgt@l);  
  int max = 0;
  if(tgtIsPool)
  {
    Element e = getElement(m2, tgt@l);
    max = e.max.v;
  }
  
  return
    "            :: flow_<l>_<src@l>_<tgt@l> == true; //if this flow happens
    '               flow_<l>_<src@l>_<tgt@l> = false; //disable it from happening more than once         
    '               if
    '               :: <flow> \> 0<if(tgtIsPool){> && <tgt_name>_new \< <max> /*target <tgt_name> is a Pool (not a Drain)*/<}>
    '                  <if(srcIsPool){>&& <src_name>_old \> 0     /*source <src_name> is a Pool (not a Source)*/<}> -\><
                       if(srcIsPool)
                       {>
    '                  if //source is a Pool (not a Source)
    '                  :: <src_name>_old \>= <flow> -\> //source contains enough for full flow
    '                  <}><
                       if(tgtIsPool)
                       {> 
    '                     if //target <tgt_name> is a Pool (not a Drain)
    '                     :: <tgt_name>_new + <flow> \<= <max> -\> //the full flow fits inside the target<
                       }>
    '                        printf(\"MM: flow(<src_name>,%d,<tgt_name>)\\n\",<flow>);
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + <flow>;<
                       if(srcIsPool){>
    '                        <src_name>_old = <src_name>_old - <flow>; //remove flow from source pool
    '                        <src_name>_new = <src_name>_new - <flow>; //remove flow from source pool
    '                  <}><
                       if(tgtIsPool){>
    '                        <tgt_name>_new = <tgt_name>_new + <flow>; //add flow to target pool
    '                  <}><
                       if(tgtIsGate){>
                       <}>
    '                        <tgt_name> = <tgt_name> + <flow>;
                       <
                       if(tgtIsPool)
                       {> 
    '                     :: else; //target has capacity for less than the full flow
    '                     <if(srcIsPool)
                           {>
    '                        <src_name>_old = <src_name>_old - (<max> - <tgt_name>_new);
    '                        <src_name>_new = <src_name>_new - (<max> - <tgt_name>_new);<
                           }>
    '                        printf(\"MM: flow(<src_name>,%d,<tgt_name>)\\n\",(<max> - <tgt_name>_new));
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + (<max> - <tgt_name>_new);
    '                        <tgt_name>_new = <max>;
    '                     fi;<
                       }>
    '                  <if(srcIsPool){>
    '                  :: else; //source is a Pool (not a Source) and does not contain enough for full flow
    '                     <if(tgtIsPool){>
    '                     if
    '                     :: <tgt_name>_new + <src_name>_old \<= <max> -\>
    '                        <tgt_name>_new = <tgt_name>_new + <src_name>_old;
    '                     <}>
    '                        printf(\"MM: flow(<src_name>,%d,<tgt_name>)\",<src_name>_old);
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + <src_name>_old;
    '                        <src_name>_new = 0;
    '                        <src_name>_old = 0;
    '                     <if(tgtIsPool){>
    '                     :: else; //target accepts less than whatever the source can provide
    '                        printf(\"MM: flow(<src_name>,%d,<tgt_name>)\\n\",(<max> - <tgt_name>_new));
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + (<max> - <tgt_name>_new);
    '                        <src_name>_old = <src_name>_old - (<max> - <tgt_name>_new);
    '                        <src_name>_new = <src_name>_new - (<max> - <tgt_name>_new);
    '                        <tgt_name>_new = <max>;
    '                     fi;
    '                     <}>
    '                  fi;
    '                  <}>
    '               :: else;          
    '               fi;";
}            


private str toPromela(Mach2 m2, Element e) =
  "       //no alternative emitted for: <toString(e)>";
