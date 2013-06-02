@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations IDE Contributions
* @package      lang::machinations
* @file         Machinations.rsc
* @brief        Defines Machinations IDE Contributions
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Machinations

import lang::machinations::Syntax;
import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Desugar;
import lang::machinations::Serialize;
import lang::machinations::Preprocessor;
import lang::machinations::Instantiator;
import lang::machinations::Labeler;
import lang::machinations::Evaluator;
//import lang::machinations::Generator;
import lang::machinations::Message;
import lang::machinations::Visualize;
import lang::machinations::ToPromela;
import lang::machinations::Trace;
import lang::machinations::Checker;
import lang::machinations::Writer;

import ParseTree;
import util::IDE;
import vis::Figure;
import IO;
import Message;

public str MM_NAME = "Micro Machinations"; //language name
public str MM_EXT  = "mm" ;                //file extension

public str MM_TRACE_NAME = "Micro Machinations Trace"; //language name
public str MM_TRACE_EXT  = "mmt";                      //file extention

public tuple[Machinations, list[Msg]] mm_parse (Tree t, loc l)
{
  list[Msg] msgs = [];
  list[Msg] msgs1, msgs2, msgs3, msgs4, msgs5;
  Machinations m1, m2, m3, m4, m5;
 
  //println("2. Implode");
  try
  {
    m1 = mm_implode(t); 
  }
  catch e:
  {
    msgs += [msg_ImploderFail(l, toString(e))];
    return <mach([]), msgs>;
  }
  
  //println("3. Desugar");
  try
  {
    m2 = mm_desugar(m1);
  }
  catch e:
  {
    msg += [msgs_DesugarFail(l, toString(e))];
    return <m1, msgs>;
  }
  
  //println("4. Flatten");
  try
  {
    <m3, msgs3> = mm_flatten(m2);
    if(msgs3 != [])
    { 
      return <m2, msgs3>;
    }
  }
  catch e:
  {
    msgs += [msg_FlattenerFail(l, e)];
    return <m2, msgs>;
  }
  
  //println("5. Desugar Flat");
  try
  {
    m4 = mm_desugarFlat(m3);
  }
  catch e:
  {
    msgs += [msg_DesugarFail(l,toString(e))];
    return <mach([]), msgs4>;
  }
  
  //println("6. Label");
  try
  {
    <m5, msgs5> = mm_label(m4);
    if(msgs5 != [])
    {
      return <m4, msgs5>;
    }
  }
  catch e:
  {
    msgs += [labelerFail(l,toString(e))]; 
    return <mach([]), msgs>;
  }

  return <m5, msgs>;
}

public tuple[Mach2, list[Msg]] mm_preprocess (Tree t, loc l)
{
  list[Msg] msgs = [];
  Machinations m;
  Mach2 m2;
  <m, msgs> = mm_parse(t, l);  
  if(msgs != [])
  {
    return <NEW_Mach2, msgs>;
  }
  
  //println("7. Preprocess\n");
  try
  {
    m2 = mm_preprocess(m);
  }
  catch e:
  {
    msgs += [msg_PreprocessorFail(l,e)];
    return <NEW_Mach2, msgs>;
  }
  
  msgs += mm_check(m2);
  
  
  return <m2, msgs>;
}

public tuple[Mach2, list[Msg]] mm_limit (Tree t, loc l)
{
  list[Msg] msgs = [];
  Mach2 m2, m3;
  <m2, msgs> = mm_preprocess(t, l);
  if(msgs != [])
  {
    return <NEW_Mach2, msgs>;
  }
  
  //println("8. Limit\n");
  try
  {
    m3 = mm_limit(m2, 255);
  }
  catch e:
  {
    msgs += [msg_LimiterFail(l,toString(e))];
    return <m2, msgs>;
  }
  
  return <m3, msgs>;
}

public tuple[Mach2, list[tuple[State,Transition]], list[Msg]] mm_simulate (Tree t, loc l, int depth)
{
  list[Msg] msgs, msgs2;
  Mach2 m2;
  list[tuple[State,Transition]] trace = [];
  <m2, msgs> = mm_limit(t, l);
  
  if(msgs != [])
  {
    return <m2, trace, msgs>;
  } 

  //println("8. Simulate");
  try
  {
    <trace, msgs2> = mm_simulate(m2, depth);
    if([msg_AssertionViolated(State s, Element e)] := msgs2 &&
       e.name.name == "ends")
    {
      ;
    }
    else if(msgs2 != [])
    {      
      return <m2, trace, msgs2>;
    }
  }
  catch e:
  {
    msgs += [msg_EvaluatorFail(l, toString(e))];
  }
  
  return <m2, trace, msgs>; 
}


public tuple[Mach2 m2, list[tuple[State s, Transition tr]] trace, list[Msg] msgs] mm_play(Tree t, loc mmt_loc)
{
  loc mm_loc = mmt_loc;
  mm_loc.extension = "mm";  
  
  list[Msg] msgs = [], msgs1, msgs2, msgs3;
  Mach2 m2;
  Trace trace, trace2;
  list[tuple[State,Transition]] stateTrace = [];
  
  <m2, msgs1> = mm_limit(mm_parse(mm_loc), mm_loc);
  if(msgs1 != [])
  {
    return <m2, [], msgs1>;
  }
  
  try
  {
    trace = mm_trace_implode(t);  
  }
  catch e:
  {
    msgs += [msg_ImploderFail(mm_loc, e)];
    return <m2, [], msgs>;
  }
  
  try
  {
    trace = mm_trace_transform(trace);
  }
  catch e:
  {
    msgs += [msg_LabelerFail(m2, e)];
  }
  
  
  try
  {
    <trace2, msgs2> = mm_label(m2.m, trace);
    if(msgs2 != [])
    {
      return <m2, trace, msgs2>;
    }
  }
  catch e:
  {
    msgs += [msg_LabelerFail(m2, toString(e))];
    return <m2, [], msgs>;
  }
  
  try
  {
    <stateTrace, msgs3> = mm_play(m2, trace2);
    if([msg_AssertionViolated(State s, Element e)] := msgs3 &&
       e.name.name == "ends")
    {
      ;
    }
    else if(msgs3 != [])
    {      
      return <m2, [], msgs3>;
    }
  }
  catch e:
  {
    msgs += [msg_EvaluatorFail(mmt_loc, e)];
  }
  
  return <m2, stateTrace, msgs>;
}


public tuple[Writer,list[Msg]] mm_toPromela(Tree t, loc l)
{
  tuple[Mach2 m2, list[Msg] msgs] phase1 = mm_limit(t, l);
  
  Writer w = writer(l);
  
  if(phase1.msgs == [])
  { 
    w = mm_toPromela(phase1.m2);
    writeFile(w);
  }

  return <w, phase1.msgs>;
}

//--------------------------------------------------------------------------------
//IDE functions
//--------------------------------------------------------------------------------
private node mm_ide_outline (Tree t)
  = mm_implode(t);

private node mm_trace_ide_outline(Tree t)
  = mm_trace_implode(t);

private void mm_trace_ide_parse(Tree t, loc l)
{
  Trace trace = mm_trace_implode(t);
  iprintln(trace);
}

private void mm_ide_flatten (Tree t, loc l)
{
  tuple[Machinations m, list[Msg] msgs] phase1 = mm_parse(t, l);  
  println("/*Flattened model <l>*/\n<toString(phase1.m)>\n");
  if(phase1.msgs!=[])
  {
    println("Errors:\n<toString(phase1.msgs)>");
  }
}

private void mm_ide_visualize (Tree t, loc l)
{
  tuple[Mach2 m2, list[Msg] msgs] phase1 = mm_limit(t, l);
  if(phase1.msgs != [])
  {
    println(toString(phase1.msgs));
  }
  else
  {
    mm_visualize(phase1.m2);
  }
}

public void mm_ide_simulate (Tree t, loc l)
{
  list[Msg] msgs;
  Mach2 m2;
  list[tuple[State,Transition]] trace;    
  <m2, trace, msgs> = mm_simulate(t, l, 100);
   
  println(toString(trace, m2));
  if(msgs!=[])
  {
    println("Errors:\n<toString(msgs)>");
  }
}

public void mm_ide_generate (Tree t, loc l)
{
  println("FIXME: TODO");
}

public void mm_ide_toPromela (Tree t, loc l)
{
  println("Compile file <l> to Promela.");
  tuple[Writer w, list[Msg] msgs] phase1 = mm_toPromela(t, l);
  
  if(phase1.msgs != [])
  {
    println("Errors:\n<toString(phase1.msgs)>");
  }
}

public void mm_ide_check(Tree t, loc l)
{
 tuple[Mach2 m2, list[Msg] msgs] phase1 = mm_limit(t, l);
  if(phase1.msgs != [])
  {
    println(toString(phase1.msgs));
  }
  else
  {
    println(mm_checkUnreachable(phase1.m2));
  }
}

public void mm_trace_ide_play (Tree t, loc mmt_loc)
{
  tuple[Mach2 m2, list[tuple[State s, Transition tr]] trace, list[Msg] msgs] phase1 = mm_play(t, mmt_loc);
  if(phase1.msgs != [])
  {
    println("Errors:\n<toString(phase1.msgs)>");
  }
  else
  {
    println(toString(phase1.trace, phase1.m2));
    println("Playback completed successfuly.");
  }
}

private void mm_trace_ide_visualize (Tree t, loc mmt_loc)
{
  loc mm_loc = mmt_loc;
  mm_loc.extension = "mm";  
  
  list[Msg] msgs = [], msgs1, msgs2, msgs3;
  Mach2 m2;
  Trace trace, trace2;
  
  <m2, msgs1> = mm_limit(mm_parse(mm_loc), mm_loc);
  if(msgs1 != [])
  {
    return <m2, [], msgs1>;
  }
  
  try
  {
    trace = mm_trace_implode(t);  
  }
  catch e:
  {
    msgs += [msg_ImploderFail(m2, toString(e))];
    return <m2, [], msgs>;
  }
  
  try
  {
    trace = mm_trace_transform(trace);
  }
  catch e:
  {
    msgs += [msg_LabelerFail(m2, e)];
  }
  
  try
  {
    <trace2, msgs2> = mm_label(m2.m, trace);
    if(msgs2 != [])
    {
      return <m2, trace, msgs2>;
    }
  }
  catch e:
  {
    msgs += [msg_LabelerFail(m2, toString(e))];
    return <m2, [], msgs>;
  }
  
  mm_visualize(m2, trace2);
}

public void mm_register()
{
  Contribution mm_style =
    categories
    (
      (
        "Name" : {foregroundColor(color("royalblue"))},
        "TypeName" : {foregroundColor(color("darkblue")),bold()},
        "UnitName" : {foregroundColor(color("mediumblue")),bold()},
        "Comment": {foregroundColor(color("dimgray"))},
        "Value": {foregroundColor(color("firebrick"))},
        "String": {foregroundColor(color("teal"))}
        //,"MetaKeyword": {foregroundColor(color("blueviolet")), bold()}
      )
    );

  set[Contribution] mm_contributions =
  {
    mm_style,
    popup
    (
      menu
      (
        "Micro-Machinations",
        [
          action("Flatten", mm_ide_flatten),
          action("Simulate", mm_ide_simulate),
          action("Generate", mm_ide_generate),
          action("Visualize", mm_ide_visualize),
          action("ToPromela", mm_ide_toPromela),
          action("Check", mm_ide_check)
        ]
      )
    )
  };
  
  mm_trace_contributions =
  {
    mm_style,
    popup
    (
      menu
      (
        "Micro-Machinations",
        [
          action("Parse", mm_trace_ide_parse),
          action("Play Back", mm_trace_ide_play),
          action("Visualize", mm_trace_ide_visualize)
        ]
      )
    )
  };
    
  registerLanguage(MM_NAME, MM_EXT, lang::machinations::Syntax::mm_parse);
  registerOutliner(MM_NAME, mm_ide_outline);
  registerContributions(MM_NAME, mm_contributions);
  //registerAnnotator(Machinations_NAME, machinations_check);
  
  registerLanguage(MM_TRACE_NAME, MM_TRACE_EXT, lang::machinations::Syntax::mm_trace_parse);
  //registerOutliner(MM_TRACE_NAME, mm_trace_ide_outline);
  registerContributions(MM_TRACE_NAME, mm_trace_contributions);
}

//--------------------------------------------------------------------------------
//for quick testing purposes
//--------------------------------------------------------------------------------
public void probeer()
{
  loc f = |project://MM-AiR/test/pool2.mm|;
  mm_ide_simulate(mm_parse(f), f);
}

public void simwar()
{
  loc f = |project://MM-AiR/test/examples/simwar_v1.mm|;
  mm_ide_simulate(mm_parse(f), f);
}

public void gen()
{
  loc f = |project://MM-AiR/test/examples/simwar_v1.mm|;
  mm_ide_generate(mm_parse(f), f);
}

public void vis()
{
  loc f = |project://MM-AiR/test/examples/bird.mm|;
  mm_ide_visualize(mm_parse(f), f);
}

public void prom()
{
  loc f = |project://MM-AiR/test/activator2.mm|;
  mm_ide_toPromela(mm_parse(f), f);
}

public void play()
{
  loc f = |project://MM-AiR/test/all2.mmt|;
  mm_trace_ide_play(mm_trace_transform(mm_trace_parse(f), f));
}

/*
private Tree machinations_setLink(Tree t, map[loc, loc] l)
{
  //visit the parse tree and replace categories based on messages
  return visit(t)
  {
    case Tree n:
    {
      if(n@\loc? && n@\loc in l)
      {
        insert n[@link = l[n@\loc]];
      }
    }
  }
}

private Tree machinations_setLinksList(Tree t, map[loc, list[loc]] l)
{
  map[loc, set[loc]] l2 = ();
  for(loc src <- l)
  {
    l2 += (src : toSet(l[src]));
  }
  return setLinks(t, l2);
}

private Tree machinations_setLinks(Tree t, map[loc, set[loc]] l)
{
  return visit(t)
  {
    case Tree n:
    {
      if(n@\loc? && n@\loc in l)
      {
        insert n[@links = l[n@\loc]];
      }
    }
  }
}*/
