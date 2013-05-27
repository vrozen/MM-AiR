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
import lang::machinations::Evaluator;
import lang::machinations::Writer;
import util::Math;
import List;
import IO;

private int MAX_BIT   = 1;
private int MAX_BYTE  = 255;
private int MAX_SHORT = toInt(pow(2, 15)) - 1;

private bool debug = false;

public Writer mm_toPromela(Mach2 m2)
{
  loc tgt = m2.m@location;
  tgt.extension = ".pml";  
  tgt.begin.line = 0;
  tgt.begin.column = 0;
  tgt.end.line = 0;
  tgt.end.column = 0;
  tgt.offset = 0;
  tgt.length = 0;
  
  return promelaModel(writer(tgt),m2,storageTypes(m2));  
}

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
private Writer globals(Writer w, Mach2 m2, map[str,str] ts)
{
  State s = NEW_State(m2);
  TempState tempstate = NEW_TempState(m2);

  w = writeln(w, "//globals");
    
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
    w = writeln(w,
      "<ts[n]> <n> = <v>; //label <e@l>", //pool declaration and initial value
      e@location);
  }
  
  //Gates
  w = writeln(w, "//gate state values");
  
  for(Element e <- [e | e <- m2.m.elements, isGate(e)])
  {
    str n = e.name.name; 
    w = writeln(w,
      "int <n> = 0; //label <e@l> //gate temp value (zero when step completes)
      'byte <n>_s = 0; //label <e@l> //gate edge number
      'int <n>_c = 0; //label <e@l> //gate edge count", 
      e@location);
  }
  
  w = writeln(w);
  w = writeln(w, "//node activation state");
  
  //2. for each node generate one activation guard of type bool <name>_act
  //   initialize the bit to true if the node.when is in {auto, user, start}
  //   initialize the bit to false if the node.when is passive  
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])
  {
    str n = e.name.name;
    w = writeln(w,
      "bool <n>_active = <
        e.when != when_passive() &&
        false notin
          {evalBool(s,tempstate,m2,cond) |
           cond: state(ID src, Exp e, ID tgt) <- getActivators(m2, e@l)}>;",
      e@location);
  }


  w = writeln(w,
        "  //reachability:");
  for(Element e <- m2.m.elements, isNode(e))
  {
    list[Element] fs = [];
    if(e.act == act_pull() && (e.when != when_passive() || canBeTriggered(m2,e@l)))
    {
      fs += getInflow(m2, e@l);
    }
    if((e.act == act_push() && (e.when != when_passive() || canBeTriggered(m2,e@l))) || isGate(e))
    {
      fs += getOutflow(m2, e@l);
    }
    for (Element f <- fs)
    {
      if(e.how == how_all())
      {
        w = writeln(w,
        "  bool reach_all_<e@l>_<f@l> = false;");
      }
      if(e.how == how_any())
      {
        w = writeln(w,
          "  bool reach_all_<e@l>_<f@l> = false;
          '  bool reach_any_<e@l>_<f@l> = false;");
      }
    }
  }

  //reach triggers
  for(Element e <- m2.m.elements, isNode(e))
  {
    for(Element t <- getTriggers(m2,e@l))
    {
       w = writeln(w,
         "  bool reach_trigger_<e@l>_<t@l> = false;");
    }
  }
  
  //return globals;
  return w;
}

//3.     generate one active proctype with the name of the model
//3.1    locals
//3.1.1  for each node generate one guard to check a step happened calling it <name>_step       
//3.1.2  for each pool generate one value to test availability for each pool calling it <name>_old
//3.1.2  for each pool and each gate generate one value to create the new state for each pool calling it <name>_new
//       note: global <name> will function als the old state and can be used in calculations
//       for each flow edge generate an int named flow_<src>_<tgt> to store
//       note: alternatively a bit is sufficient to check if a flow edge is satisfied
private Writer locals(Writer w, Mach2 m2, map[str,str] ts)
{
  w = writeln(w,
        "  //locals
        '  //sub-step guards:");
  
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    //if it is automatic or can be triggered
    if(e.when == when_auto() || e.when == when_user() || canBeTriggered(m2,e@l))
    {   
      str n = e.name.name;
      w = writeln(w,
        "  bool <n>_step;", //initialized later
        e@location);
    }
  }
  
  w = writeln(w,
        "  bool commit = true; //commit all guard
        '
        '  int flow = 0; //evaluated flow
        '
        '  //temporary old pool values for testing availability of resources:");
  
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {
    str n = e.name.name;
    w = writeln(w,
        "  <ts[n]> <n>_old = 0;", e@location);      
  }
  w = writeln(w);

  w = writeln(w,
        "  //temporary new pool values for testing maximum and contructing next state:");
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {  
    str n = e.name.name;
    w = writeln(w,
        "  <ts[n]> <n>_new = 0;", e@location);
  }
  w = writeln(w);

  w = writeln(w,
        "  //temporary new pool values for testing maximum and contructing next state:");
  for(Element e <- [e | e <- m2.m.elements, isPool(e)])
  {  
    str n = e.name.name;
    w = writeln(w,
        "  <ts[n]> <n>_old_try = 0;    
        '  <ts[n]> <n>_new_try = 0;\n",
        e@location);
  }
  w = writeln(w);
  
  w = writeln(w,
        "  //temporary flow calculation for triggers:");
  for(Element e <- [e | e <- m2.m.elements, isFlow(e)])
  {
    w = writeln(w,
        "  int flow_<e.s@l>_<e.t@l>;", e@location); //TODO: optimize type?
  }
  w = writeln(w);

  return w;
}

//3.2    for each (atomic) step
//3.2.1  set the step guards to the value of the act guard (activated nodes will be able to do a step within this step)
//       while any of the step guards are true, perform steps
//       for each node generate the step
//       when all step guards become false break

private Writer promelaModel(Writer w, Mach2 m2, map[str,str] ts) 
{
  w = globals(w, m2, ts);

  //begin model
  w = writeln(w,
    "active proctype mm ()
    '{");
  
  w = locals(w, m2, ts);
  
  
  //begin step
  w = writeln(w,
    "  end:
    '  do
    '  :: atomic //active nodes can cause flow to happen
    '     {
    '       d_step
    '       {");
  w = state(w, m2);
  w = prepare(w, m2);
  w = writeln(w,
    "       };");
        
  w = section(w, m2, act_pull(), how_all(), m2.pullAllNodes, m2.pullAllGroups);
  w = section(w, m2, act_pull(), how_any(), m2.pullAnyNodes, m2.pullAnyGroups);  
  w = section(w, m2, act_push(), how_all(), m2.pushAllNodes, m2.pushAllGroups);

  w = finalize(w, m2);
  
  //end atomic
  w = writeln(w,
    "     };");

  w = reach(w, m2);
  
  //end step, end process
  w = writeln(w,
    "  od;
    '}");
    
  w = monitor(w, m2, ts);

  return w;
}

private Writer state (Writer w, Mach2 m2)
{
  return writeln(w,
    "         //print state values
    '         printf(\"MM: state(\");<
   if(true)
   {
     list[str] ns = [e.name.name | e <- m2.m.elements, isPool(e)] +
                    ["<e.name.name>_s","<e.name.name>_c" | e <- m2.m.elements, isGate(e)] +
                    ["<e.name.name>_active" | e <- m2.m.elements, isNode(e)];
     str n;
    ><
    while(ns != [])
    {
      <n,ns> = headTail(ns);>
    '         printf(\"<n> = %d<if(ns!=[]){>, <}>\",<n>);<
    }><
  }>
    '         printf(\")\\n\");");
}


private Writer reach (Writer w, Mach2 m2)
{
  //Reachability test
  for(Element e <- m2.m.elements, isNode(e))
  {

    list[Element] fs = [];
    if(e.act == act_pull() && (e.when != when_passive() || canBeTriggered(m2,e@l)))
    {
      fs += getInflow(m2, e@l);
    }
    if((e.act == act_push() && (e.when != when_passive() || canBeTriggered(m2,e@l))) || isGate(e))
    {
      fs += getOutflow(m2, e@l);
    }
      for (Element f <- fs)
      {
        if(e.how == how_all())
        {
         
          w =  writeln(w,
            "       if
            '       :: reach_all_<e@l>_<f@l> -\>
            '          reach_all_<e@l>_<f@l> = false; //MM: reach_all(<e@l>,<f@l>)
            '       :: else;
            '       fi;");
        }
        if(e.how == how_any())
        {
         
          w = writeln(w,
            "       if
            '       :: reach_all_<e@l>_<f@l> -\>
            '          reach_all_<e@l>_<f@l> = false; //MM: reach_any(<e@l>,<f@l>)
            '       :: else;
            '       fi;
            '       if
            '       :: reach_any_<e@l>_<f@l> -\>
            '          reach_any_<e@l>_<f@l> = false; //MM: reach_all(<e@l>,<f@l>)
            '       :: else;
            '       fi;");
        }
      }
  }
  
  //TRIGGERS
  for(Element e <- m2.m.elements, isNode(e))
  {
    for(Element t <- getTriggers(m2,e@l))
    {
       w = writeln(w,
         "       if
         '       :: reach_trigger_<e@l>_<t@l> -\>
         '          reach_trigger_<e@l>_<t@l> = false; //MM: reach_trigger(<e@l>,<t@l>)
         '       :: else;
         '       fi;");
    }
  }
  
  
  return w;
}

//emit node alternatives / interleaving for pull and push
private Writer section (Writer w, Mach2 m2, Act act, How how, set[int] nodes, set[set[int]] groups)
{
  w = writeln(w,
    "      //Section <toString(act)> <toString(how)>");
  for(set[int] group <- groups)
  {
    println("Group <toString(act)> <toString(how)> <group>");
    if(group != {})
    {
    w = writeln(w,
    "       do");  
    for(Element e <- [getElement(m2,l) | l <- group] )
    {
      println("Competitor <e@l> <toString(e.name)>");
      w = writeln(w,
    "       :: d_step //<toString(e.when)> <toString(e.how)> <toString(e.name)>
    '          {
    '            <toString(e.name)>_step == true -\> //if <toString(e.name)> acts
    '            <toString(e.name)>_step = false; //disable <toString(e.name)> from taking another step until it gets another turn");     
      w = toPromela(w, m2, e, e.act, e.how);
      w = writeln(w,
    "          };");
    }
    w = writeln(w,
    "       :: else -\> break;  
    '       od;");
    }
  }
  if(groups!= {})
  {
    w = writeln(w,
      "       skip; //jump from d_step to here");
  }
  
  set[Element] remainder =
    {getElement(m2,r) | int r <- nodes - {*group | group <- groups}};
  
  remainder = {e | Element e <- remainder, e.when != when_passive() || canBeTriggered(m2, e@l)};
  
  if(remainder != {})
  {
    w = writeln(w,
      "         d_step
      '         {");
    for(Element e <- remainder)
    {
      println("Remainder <e@l> <toString(e.name)>");
      w = writeln(w,
      "           if
      '           :: <toString(e.name)>_active == true;  //<toString(e.when)> <toString(e.how)> <toString(e.name)>");
      w = toPromela(w, m2, e, e.act, e.how);
      w = writeln(w,
      "           :: else;  
      '           fi;");
    }
    w = writeln(w,
      "         };");
  }
  return w;
}


private Writer prepare(Writer w, Mach2 m2) =
 writeln(w,
 "       //copy state to tempstate<for(Element e <- [e | e <- m2.m.elements, isPool(e)]) { str n = e.name.name;> 
 '       <n>_new = <n>;
 '       <n>_old = <n>;
 <}>
 '       //enable steps:<
   for(Element e <- [e | e <- m2.m.elements, isNode(e)]){><
     if(e.when == when_auto() || canBeTriggered(m2, e@l)){ str n = e.name.name; >
 '       if
 '       :: <n>_active -\> <n>_step = true;
 '       :: else;
 '       fi;<
     }><
   }>
 ");

//3.3    at the end of each atomic step
//3.3.1  propagate what is accumulated in gates according to the round robing scheduling (TODO)
//3.3.2  for each node set the activation guards
//       assign true if a node is in automatic or user
//       assign false if a node is in passive or start
//3.3.3  for each node that has triggers
//       if all the flow on which it operates is satisfied
//         thus for each in or out flow edge check that flow_<src>_<tgt> != 0
//       then assign true to the activation guard of the triggered node
private Writer finalize(Writer w, Mach2 m2)
{
  w = writeln(w, "       //finalize step
                 '       d_step
                 '       {");
  w = writeln(w, "       //store new state and clear temporary values");
  for(Element e <- [e | e <- m2.m.elements, isPool(e)]) 
  {
    str n = e.name.name;
    w = writeln(w,
      "       <n> = <n>_new;
      '       <n>_new = 0;
      '       <n>_old = 0;
      '       <n>_new_try = 0;
      '       <n>_old_try = 0;",
      e@location);
  }
  w = writeln(w, "       };
                 '");  
  
  //currently still non-deterministic
  w = redistribute(w, m2);
  
  w = writeln(w,
              "       skip; //jump into d_step not allowed 
              '       d_step
              '       {");
  
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {  
    str n = e.name.name;
    w = writeln(w,
      "       <n>_active = false;",
      e@location);
  }
  
  //activate when auto or user and when not disabled
  w = writeln (w, "       //activate when auto or user and not disabled");
  for(Element e <- [e | e <- m2.m.elements, isNode(e)])  
  {
    str n = e.name.name;
    switch(e.when)
    {
      case when_auto():
      {
        w = writeln(w,
          "       if
          '       :: <for(state(ID s, Exp exp, ID t) <- getActivators(m2, e@l)){><
                        if(debug){><toPromela(exp)><} else {>c_expr { <toC(exp)> }<}> && <
                      }>true -\> <n>_active = true;
          '       :: else -\> <n>_active = false;
          '       fi;",
          e@location);
      }
      case when_user():
      {
        w = writeln(w,
          "       if
          '       :: <for(state(ID s, Exp exp, ID t) <- getActivators(m2, e@l)){><
                       if(debug){><toPromela(exp)><} else {>c_expr { <toC(exp)> }<}> && <
                     }>true -\> <n>_active = true;
          '       :: <n>_active = false; //unconditionally also made false to test triggering in all possible ways
          '       fi;",
          e@location);
      }
    }
  }
  w = writeln(w);
  
  //for each node that has triggers
  //   if each flow is satisfied
  //   then the flow along each edge on which the node operates is greater or equal to the flow expression
  //   then activate the nodes the trigger refers
  //   but only if it is not disabled
  w = writeln(w, "       //activate when triggered and not disabled");
  for(int l <- getPullNodes(m2))
  {
    Element e = getElement(m2,l);
    list[Element] triggers = getTriggers(m2,l);
    if(triggers != [])
    {
      //get the inflow
      w = write(w,    
        "       if
        '       :: ",
        e@location);
      if(getInflow(m2,l) != [])
      {
        for(flow(ID s, Exp exp, ID t) <- getInflow(m2, l))
        {
          if(debug)
          {
            w = write(w, "flow_<s@l>_<t@l> \>= <toPromela(exp)> && ", e@location); //each inflow is satisfied
          }
          else
          {          
            w = write(w, "c_expr { Pmm -\> flow_<s@l>_<t@l> \>= <toC(exp)> } && ", e@location); //each inflow is satisfied
          }
        }
      }
      else
      {
        w = write(w, "<getElement(m2,l).name.name>_active && ", e@location); //node has no inflow but is active
      }
      w = writeln(w, "true -\>", e@location);
      
      for(Element te: state(ID s, Exp exp, ID t) <- triggers)
      {
        w = write(w,
          "          if
          '          :: ",
          e@location);
        for(state(ID s2, Exp exp, ID t2) <- getActivators(m2, t@l))
        {
          w = write(w, "<if(debug){><toPromela(exp)><} else {>c_expr { <toC(exp)> }<}> && ", e@location);
        }
        w = writeln(w, "true -\>          
          '             printf(\"MM: trigger <t.name>\\n\");
          '             reach_trigger_<e@l>_<te@l> = true;
          '             <t.name>_active = true;
          '          :: else -\> printf(\"MM: inhibit <t.name>\\n\");
          '          fi;",
          e@location);
      }
      
      w = writeln(w,
        "       :: else; //flow requirement not met for trigger
        '       fi;",
        e@location);
    }
  }
  
  for(int l <- getPushNodes(m2))
  {
    Element e = getElement(m2,l);
    list[Element] triggers = getTriggers(m2,l);
    if(triggers != [])
    {
      //get the inflow
      w = write(w,    
        "       if
        '       :: ",
        e@location);
      if(getOutflow(m2,l) != [])
      {
        for(flow(ID s, Exp exp, ID t) <- getOutflow(m2, l))
        {
          if(debug)
          {
            w = write(w, "flow_<s@l>_<t@l> \>= <toPromela(exp)> && ", e@location); //each inflow is satisfied
          }
          else
          {          
            w = write(w, "c_expr { Pmm -\> flow_<s@l>_<t@l> \>= <toC(exp)> } && ", e@location); //each inflow is satisfied
          }
        }
      }
      else
      {
        w = write(w, "<getElement(m2,l).name.name>_active &&", e@location); //node has no inflow but is active
      }
      w = writeln(w, "true -\>", e@location);
      
      for(Element te: state(ID s, Exp exp, ID t) <- triggers)
      {
        w = write(w,
          "          if
          '          :: ",
          e@location);
        for(state(ID s2, Exp exp, ID t2) <- getActivators(m2, t@l))
        {
          w = write(w, "<if(debug){><toPromela(exp)><} else {>c_expr { <toC(exp)> }<}> && ", e@location);
        }
        w = writeln(w,
          "true -\>
          '             printf(\"MM: trigger <t.name>\\n\");
          '             reach_trigger_<e@l>_<te@l> = true;
          '             <t.name>_active = true;
          '          :: else -\> printf(\"MM: inhibit <t.name>\\n\");
          '          fi;",
          e@location);
      }
      
      w = writeln(w,
        "       :: else; //flow requirement not met for trigger
        '       fi;",
        e@location);
    }
  }
  w = writeln(w);
  
  w = writeln(w,
    "       //clear temporary transition data from state");
  for(Element e <- [e | e <- m2.m.elements, isFlow(e)])
  {
    w = writeln(w,
      "       flow_<e.s@l>_<e.t@l> = 0;");
  }
  w = writeln(w,
      "       printf(\"MM: step\\n\"); 
      '       }; //end d_step");

  return w;
}

public Writer monitor(Writer w, Mach2 m2, map[str,str] ts)
{
  w = writeln(w,
    "active proctype monitor()
    '{
    '  end:
    '  do");
  
  for(e: always(ID name, Exp exp, str msg) <- m2.m.elements)
  {
    w = writeln(w,
      "  :: !(<toPromela(exp)>) -\>
      '     printf(\"MM: violate <toString(name)>\\n\");
      '     assert(<toPromela(exp)>); //<msg>",
      e@location);
  }
      
  for(Element e <- m2.m.elements, isGate(e))
  {
    w = writeln(w,
      "  :: <e.name.name> != 0 -\>
      '     printf(\"MM: violate sane\\n\");
      '     assert(<e.name.name> == 0);",
      e@location);
  }
   
  w = writeln(w,
    "  od;
    '}");
        
  return w;
}

private Writer redistribute(Writer w, Mach2 m2)
{
  w = writeln(w,
    "       //redistribute gates
    '       do");

  for(e <- m2.m.elements, isGate(e))
  {
    w = redistribute(w, m2, e);
  }

  w = writeln(w,
    "       :: else -\> //all gates have redistributed         
    '          break;   //exit redistribution phase
    '       od;");

  return w;
}

//implement round-robin scheduling of gates
//FIXME: rewrite gate redistribution to be deterministic
//TODO: calculate dependencies in order to do that
private Writer redistribute(Writer w, Mach2 m2, g: gate(When when, Act act, How how, ID n, list[Unit] opt_u))
{
  list[Element] fs = getOutflow(m2, g@l);
  str name = n.name;

  return writeln(w,
     ":: <name> != 0 -\>
         if
         <for(selected <- [0..size(fs)]){
           Element f = fs[selected];
           str tgtName = f.t.name;
           int max = 0;
           bool tgtIsPool = isPool(m2, f.t@l);
           if(tgtIsPool)
           {
             Element e = getElement(m2, f.t@l);
             //println(toString(e));
             max = e.max.v;
           }>
         :: <name>_s == <selected>;<
           if(debug){>
            flow = <toPromela(f.exp)>;<
           } else {>
            c_code { Pmm -\> flow = (int) (<toC(f.exp)>); };<
           }>
            if
            :: flow \>= 0  //if flow is positive 
               <if(tgtIsPool){>&& <tgtName> \< <max><}> /*and the target is not full*/ ;
               -\>
               if
               :: <name> \>= (flow - <name>_c); //if the full flow is available
                 <if(tgtIsPool){>
                 if
                 :: <tgtName> + (flow - <name>_c) \<= <max>; //if the full flow fits into the target
                 <}>                 
                    printf(\"MM: <name>-%d-\><tgtName>\\n\",(flow - <name>_c));
                    reach_all_<g@l>_<f@l> = true;                  
                    <tgtName> = <tgtName> + (flow - <name>_c); //add the flow to the target
                    <name> = <name> - (flow - <name>_c); //remove the flow from the gate
                 <if(tgtIsPool){>
                 :: else -\> ; //the target has capacity for less than the full flow
                    printf(\"MM: <name>-%d-\><tgtName>\\n\",(<max> - <tgtName>));
                    reach_any_<g@l>_<f@l> = true;
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
                    printf(\"MM: <name>-%d-\><tgtName>\\n\",(<name>));
                    reach_any_<g@l>_<f@l> = true;
                    <tgtName> = <tgtName> + <name>; //add what is available to the target
                    <name>_c = <name>_c + <name>; //add what flows to the count
                    <name> = 0; //empty the gate
                 <if(tgtIsPool){>                
                 :: else -\> //whatever is available does not fit the target
                    printf(\"MM: <name>-%d-\><tgtName>\\n\",(<max> - <tgtName>));
                    reach_any_<g@l>_<f@l> = true;                    
                    <name> = <name> - (<max> - <tgtName>); //remove the target remaining capacity from the gate
                    <name>_c = <name>_c + (<max> - <tgtName>); //add what flows to the count
                    <tgtName> = <max>; //max out the target                 
                 fi;
                 <}>
              fi;
            :: else -\> //the target is full and fits nothing else or the flow is not positive           
               <if(selected < size(fs) - 1){><name>_s = <name>_s + 1; <} else {><name>_s = 0;<}> //select the next edge 
           fi;<}>
         :: else -\> printf(\"MM: violate sane\\n\"); assert(false);
         fi;",
     g@location);
}

//pull any pool is a deterministic step
private Writer toPromela(Writer w, Mach2 m2, Element e, act_pull(), how_any())
{
  str name = e.name.name;
  /*w = writeln(w,
    "       :: d_step //pull any <name>
    '          {
    '            <name>_step == true -\> //if <name> acts
    '            <name>_step = false; //disable <name> from taking another step until it gets another turn",
    e@location);
  */
  for(f <- getInflow(m2, e@l))
  {
    w = toPromela(w, m2, e@l, f, how_any());
  }
  /*
  w = writeln(w,
    "          };",
    e@location);
  */
  return w;
}

//pull all pool is a deterministic step
private Writer toPromela(Writer w, Mach2 m2, Element e, act_pull(), how_all())
{
  str name = e.name.name;
  w = writeln(w,
    //"       :: d_step //pull all <name> 
    //'          {
    //'            <name>_step == true -\> //if <name> acts
    //'            <name>_step = false; //disable <name> from taking another step until it gets another turn
    "            commit = true;<
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
                 }>",
    e@location);
  
  for(f: flow(src,exp,tgt) <- getInflow(m2, e@l))
  {
    w = toPromela(w, m2, e@l, f, how_all());
  }
  
  w = writeln(w,
    "            if
    '            :: commit == true;<
                 for(f: flow(src,exp,tgt) <- getInflow(m2, e@l)){
                   str src_name = toString(src);
                   str tgt_name = toString(tgt);><
                   if(debug){>
    '               flow = <toPromela(exp)>;<
                   } else {>
    '               c_code { Pmm -\> flow = (int) (<toC(exp)>); };<
                   }>
    '               printf(\"MM: <src_name>-%d-\><tgt_name> \\n\",flow);
    '               reach_all_<e@l>_<f@l> = true;
    '               flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + flow;<
                    if(isPool(m2,src@l)){>
    '               <src_name>_new = <src_name>_new_try;
    '               <src_name>_old = <src_name>_old_try;<}><
                    if(isPool(m2,tgt@l)){>
    '               <tgt_name>_new = <tgt_name>_new_try;
    '               <tgt_name>_old = <tgt_name>_old_try;<}><
                 }>
    '            :: else; //do not commit
    '            fi;",
    e@location);
    //'          };\n",

  return w;
}







//push any pool is not a deterministic step
private Writer toPromela(Writer w, Mach2 m2, Element e, act_push(), how_all())
{
  str name = e.name.name;
  w = writeln(w,
    //"       :: d_step //push all <name> 
    //'          {
    //'         <name>_step == true -\> //if <name> acts
    //'         <name>_step = false; //disable <name> from taking another step until it gets another turn
    "         commit = true;<
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
              }>",
    e@location);
 
  for(f: flow(src,exp,tgt) <- getOutflow(m2, e@l))
  {
    w = toPromela(w, m2, e@l, f, how_all());
  }
            
  w = writeln(w,
    "         if
    '         :: commit == true -\><
                 for(f: flow(src,exp,tgt) <- getOutflow(m2, e@l)){
                   str src_name = toString(src);
                   str tgt_name = toString(tgt);><
                   if(debug){>
    '            flow = <toPromela(exp)>;<} else {>
    '            c_code { Pmm -\> flow = (int) (<toC(exp)>); };<}>
    '            printf(\"MM: <src_name>-%d-\><tgt_name>\\n\",flow);
    '            reach_all_<e@l>_<f@l> = true;
    '            flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + flow;<
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
    '         fi;",
    //'         }; //end d_step\n", 
    e@location);

  return w;
}

private Writer toPromela(Writer w, Mach2 m2, Element e, act_push(), how_any())
{
  throw "Push any not supported on: <toString(e)>.";
}

private Writer toPromela(Writer w, Mach2 m2, int l, e: flow(ID src, Exp exp, ID tgt), how_all())
{
  str src_name = toString(src);
  str tgt_name = toString(tgt);
  bool srcIsPool = isPool(m2, src@l);
  bool tgtIsPool = isPool(m2, tgt@l);
  int max = 0;
  if(tgtIsPool)
  {
    Element e = getElement(m2, tgt@l);
    //println(toString(e));
    max = e.max.v;
  }
  
  return writeln(w,   
    "<if(debug){>
    '               flow = <toPromela(exp)>;<
    } else {>
    '               c_code { Pmm -\> flow = (int) (<toC(exp)>); };<
    }>
    '               if
    '               :: flow \> 0
    '                  <if(srcIsPool){>&& <src_name>_old_try \>= flow<}> /*source contains enough for full flow*/
    '                  <if(tgtIsPool){>&& <tgt_name>_new_try + flow \<= <max> /*the full flow fits inside the target*/<}> -\>
    '                  <if(srcIsPool){><src_name>_old_try = <src_name>_old_try - flow;<}>
    '                  <if(tgtIsPool){><tgt_name>_new_try = <tgt_name>_new_try + flow;<}>
    '                  <if(srcIsPool){><src_name>_new_try = <src_name>_new_try - flow;<}>
    '               :: else -\>  //roll-back transaction
    '                  commit = false;
    '               fi;",
    e@location);
}

private Writer toPromela(Writer w, Mach2 m2, int l, e: flow(ID src, Exp exp, ID tgt), how_any())
{
  str src_name = toString(src);
  str tgt_name = toString(tgt);
  bool srcIsPool = isPool(m2,src@l);
  bool tgtIsPool = isPool(m2,tgt@l);
  bool tgtIsGate = isGate(m2,tgt@l);  
  int max = 0;
  if(tgtIsPool)
  {
    Element e = getElement(m2, tgt@l);
    max = e.max.v;
  }
  
  return writeln(w,
    "<if(debug){>
    '               flow = <toPromela(exp)>;<
    } else {>
    '               c_code { Pmm -\> flow = (int) (<toC(exp)>); };<
    }>
    '               if
    '               :: flow \> 0<if(tgtIsPool){> && <tgt_name>_new \< <max> /*target <tgt_name> is a Pool (not a Drain)*/<}>
    '                  <if(srcIsPool){>&& <src_name>_old \> 0     /*source <src_name> is a Pool (not a Source)*/<}> -\><
                       if(srcIsPool)
                       {>
    '                  if //source is a Pool (not a Source)
    '                  :: <src_name>_old \>= flow -\> //source contains enough for full flow
    '                  <}><
                       if(tgtIsPool)
                       {> 
    '                     if //target <tgt_name> is a Pool (not a Drain)
    '                     :: <tgt_name>_new + flow \<= <max> -\> //the full flow fits inside the target<
                       }>
    '                        printf(\"MM: <src_name>-%d-\><tgt_name>\\n\", flow);
    '                        reach_all_<l>_<e@l> = true;
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + flow;<
                       if(srcIsPool){>
    '                        <src_name>_old = <src_name>_old - flow; //remove flow from source pool
    '                        <src_name>_new = <src_name>_new - flow; //remove flow from source pool
    '                  <}><
                       if(tgtIsPool){>
    '                        <tgt_name>_new = <tgt_name>_new + flow; //add flow to target pool
    '                  <}><
                       if(tgtIsGate){>
    '                        <tgt_name> = <tgt_name> + flow;
                       <}>
                       <
                       if(tgtIsPool)
                       {> 
    '                     :: else; //target has capacity for less than the full flow
    '                     <if(srcIsPool)
                           {>
    '                        <src_name>_old = <src_name>_old - (<max> - <tgt_name>_new);
    '                        <src_name>_new = <src_name>_new - (<max> - <tgt_name>_new);<
                           }>
    '                        printf(\"MM: <src_name>-%d-\><tgt_name>\\n\",(<max> - <tgt_name>_new));
    '                        reach_any_<l>_<e@l> = true;
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
    '                        printf(\"MM: <src_name>-%d-\><tgt_name>\\n\",<src_name>_old);
    '                        reach_any_<l>_<e@l> = true;   
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + <src_name>_old;
    '                        <src_name>_new = 0;
    '                        <src_name>_old = 0;
    '                     <if(tgtIsPool){>
    '                     :: else; //target accepts less than whatever the source can provide
    '                        printf(\"MM: <src_name>-%d-\><tgt_name>\\n\",(<max> - <tgt_name>_new));
    '                        reach_any_<l>_<e@l> = true;    
    '                        flow_<src@l>_<tgt@l> = flow_<src@l>_<tgt@l> + (<max> - <tgt_name>_new);
    '                        <src_name>_old = <src_name>_old - (<max> - <tgt_name>_new);
    '                        <src_name>_new = <src_name>_new - (<max> - <tgt_name>_new);
    '                        <tgt_name>_new = <max>;
    '                     fi;
    '                     <}>
    '                  fi;
    '                  <}>
    '               :: else;
    '               fi;",
    e@location);
}

private str toPromela(Mach2 m2, Element e) =
  "       //no alternative emitted for: <toString(e)>";

//-----------------------------------------------------------------------------
//Machinations integer expressions to C Expressions
//-----------------------------------------------------------------------------
private str toC(e_active(ID name))
  = "now.<toString(name)>_active";

private str toC(exp: e_val(real v, list[Unit] opt_u))
  = toString(exp);

private str toC(exp: e_true())
  = toString(exp);
  
private str toC(exp: e_false())
  = toString(exp);

private str toC(exp: e_name(ID name))
  = "now.<toString(exp)>";

private str toC(e_override(Exp e))
  = "(<toC(e)>)";
  
private str toC(e_not(Exp e))
  = "!<toC(e)>";

private str toC(e_unm(Exp e))
  = "-<toC(e)>";

private str toC(e_lt(Exp e1, Exp e2))
  = "<toC(e1)> \< <toC(e2)>";

private str toC(exp: e_gt(Exp e1, Exp e2))
  = "<toC(e1)> \> <toC(e2)>";

private str toC(exp: e_le(Exp e1, Exp e2))
  = "<toC(e1)> \<= <toC(e2)>";

private str toC(exp: e_ge(Exp e1, Exp e2))
  = "<toC(e1)> \>= <toC(e2)>";

private str toC(exp: e_neq(Exp e1, Exp e2))
  = "<toC(e1)> != <toC(e2)>";

private str toC(exp: e_eq(Exp e1, Exp e2))
  = "<toC(e1)> == <toC(e2)>";

private str toC(exp: e_and(Exp e1, Exp e2))
  = "<toC(e1)> && <toC(e2)>";

private str toC(exp: e_or(Exp e1, Exp e2))
  = "<toC(e1)> || <toC(e2)>";

private str toC(exp: e_mul(Exp e1, Exp e2))
  = "<toC(e1)> * <toC(e2)>";
  
private str toC(exp: e_div(Exp e1, Exp e2))
  = "<toC(e1)> / <toC(e2)>";

private str toC(exp: e_add(Exp e1, Exp e2))
  = "<toC(e1)> + <toC(e2)>";
  
private str toC(exp: e_sub(Exp e1, Exp e2))
  = "<toC(e1)> - <toC(e2)>";
 
private str toC(exp)
{
  throw "Expression <exp> not supported in toC";
  //FIXME: noteably e_range(int low, int high) and booleans
}

//-----------------------------------------------------------------------------
//Machinations Boolean expressions to Promela Expressions
//-----------------------------------------------------------------------------
private str toPromela(e_active(ID name))
  = "<toString(name)>_active";

private str toPromela(exp: e_val(real v, list[Unit] opt_u))
  = toString(exp);

private str toPromela(exp: e_true())
  = toString(exp);
  
private str toPromela(exp: e_false())
  = toString(exp);

private str toPromela(exp: e_name(ID name))
  = toString(exp);

private str toPromela(e_override(Exp e))
  = "(<toPromela(e)>)";
  
private str toPromela(e_not(Exp e))
  = "!<toPromela(e)>";
  
private str toPromela(e_unm(Exp e))
  = "-<toPromela(e)>";

private str toPromela(e_lt(Exp e1, Exp e2))
  = "<toPromela(e1)> \< <toPromela(e2)>";

private str toPromela(exp: e_gt(Exp e1, Exp e2))
  = "<toPromela(e1)> \> <toPromela(e2)>";

private str toPromela(exp: e_le(Exp e1, Exp e2))
  = "<toPromela(e1)> \<= <toPromela(e2)>";

private str toPromela(exp: e_ge(Exp e1, Exp e2))
  = "<toPromela(e1)> \>= <toPromela(e2)>";

private str toPromela(exp: e_neq(Exp e1, Exp e2))
  = "<toPromela(e1)> != <toPromela(e2)>";

private str toPromela(exp: e_eq(Exp e1, Exp e2))
  = "<toPromela(e1)> == <toPromela(e2)>";

private str toPromela(exp: e_and(Exp e1, Exp e2))
  = "<toPromela(e1)> && <toPromela(e2)>";

private str toPromela(exp: e_or(Exp e1, Exp e2))
  = "<toPromela(e1)> || <toPromela(e2)>";
  
private str toPromela(exp: e_mul(Exp e1, Exp e2))
  = "<toPromela(e1)> * <toPromela(e2)>";
  
private str toPromela(exp: e_div(Exp e1, Exp e2))
  = "<toPromela(e1)> / <toPromela(e2)>";

private str toPromela(exp: e_add(Exp e1, Exp e2))
  = "<toPromela(e1)> + <toPromela(e2)>";
  
private str toPromela(exp: e_sub(Exp e1, Exp e2))
  = "<toPromela(e1)> - <toPromela(e2)>";
  
private str toPromela(exp)
{
  throw "Expression <exp> not supported in toPromela";
}
