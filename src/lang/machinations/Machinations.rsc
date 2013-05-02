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
import lang::machinations::Generator;
import lang::machinations::Message;
import lang::machinations::Visualize;
import lang::machinations::ToPromela;

import ParseTree;
import util::IDE;
import vis::Figure;
import IO;
import Message;

private str Machinations_NAME = "Machinations"; //language name
private str Machinations_EXT = "mach4";         //file extension

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
    return <mach([]), msgs>;
  }
  
  //println("4. Flatten");
  try
  {
    <m3, msgs3> = mm_flatten(m2);
    if(msgs3 != [])
    { 
      throw msgs3;
    }
  }
  catch e:
  {
    msgs += [msg_FlattenerFail(l, toString(e))];
    return <mach([]), msgs>;
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
      throw msgs5;
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
    return <m, msgs>;
  }
  
  //println("7. Preprocess\n");
  try
  {
    m2 = mm_preprocess(m);
  }
  catch e:
  {
    msgs += [msg_PreprocessorFail(l,toString(e))];
    return <m2, msgs>;
  }
  
  return <m2, msgs>;
}

public tuple[Mach2, list[Msg]] mm_limit (Tree t, loc l)
{
  list[Msg] msgs = [];
  Mach2 m2, m3;
  <m2, msgs> = mm_preprocess(t, l);
  if(msgs != [])
  {
    return <m, msgs>;
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
    return <m, msgs>;
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
      throw msgs2;
    }
  }
  catch e:
  {
    msgs += [msg_EvaluatorFail(l, toString(e))];
  }
  
  return <m2, trace, msgs>; 
}

private node mm_ide_outline (Tree t)
  = mm_implode(t);

private void mm_ide_flatten (Tree t, loc l)
{
  Machinations m;
  list[Msg] msgs;
  <m, msgs> = phase1(t, l);  
  println("/*Flattened model <l>*/\n<toString(m)>\n");
  if(msgs!=[])
  {
    println("Errors:\n<toString(msgs)>");
  }
}

private void mm_ide_visualize (Tree t, loc l)
{
  list[Msg] msgs;
  Mach2 m2;  
  <m2, msgs> = mm_limit(t, l);
  if(msgs != [])
  {
    println(toString(msgs));
  }
  else
  {
    mm_visualize(m2);
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
  list[Msg] msgs, msgs2;
  Mach2 m2;
  list[tuple[State,Transition]] trace = [];
  <m2, msgs> = mm_limit(t, l);
  
  if(msgs != [])
  {
    return <m, msgs>;
  } 

  //println("8. Generate");
  mm_generate(m2);
}

public void mm_ide_compile (Tree t, loc l)
{
  list[Msg] msgs;
  str model;
  <model, msgs> = mm_toPromela(m7);
      
  println("\n\n\n\n//promela model:\n<model>\n\n");
  if(msgs!=[])
  {
    println("Errors:\n<toString(msgs)>");
  }
}

public void mm_register()
{
  c =
  {
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
    ),
    popup
    (
      menu
      (
        "Machinations",
        [
          action("flatten", mm_ide_flatten),
          action("simulate", mm_ide_simulate),
          action("generate", mm_ide_generate),
          action("visualize", mm_ide_visualize),
          action("toPromela", mm_ide_compile)
        ]
      )
    )
  };
    
  registerLanguage(Machinations_NAME, Machinations_EXT, lang::machinations::Syntax::mm_parse);
  //registerAnnotator(Machinations_NAME, machinations_check);
  registerOutliner(Machinations_NAME, mm_ide_outline);
  registerContributions(Machinations_NAME, c);
}

//--------------------------------------------------------------------------------
//for quick testing purposes
//--------------------------------------------------------------------------------
public void probeer()
{
  loc f = |project://MM-AiR/test/all.mach4|;
  mm_ide_simulate(mm_parse(f), f);
}

public void simwar()
{
  loc f = |project://MM-AiR/test/examples/simwar_v1.mach4|;
  mm_ide_simulate(mm_parse(f), f);
}

public void gen()
{
  loc f = |project://MM-AiR/test/examples/simwar_v1.mach4|;
  mm_ide_generate(mm_parse(f), f);
}

public void vis()
{
  loc f = |project://MM-AiR/test/examples/bird.mach4|;
  mm_ide_visualize(mm_parse(f), f);
}

public void prom()
{
  loc f = |project://MM-AiR/test/source.mach4|;
  mm_ide_compile(mm_parse(f), f);
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


private Tree mm_ide_check(Tree t)
{
  //Machinations m = machinations_implode(t);
  //list[Msg] msgs;
  //list[Message] errors;  
  //<m, mi> = setLabels(m);
  //<msgs, mf> = getFlow(m, mi);
  //msgs += check(m, mi, mf);

  //errors = getErrors(msgs);
  //uses = getUses(m, mi);
  //defs = getDefs(uses);
  
  //t = setLink(t, uses);
  //t = setLinks(t, defs);
  
  //return t[@messages = errors];
  return t;
}
