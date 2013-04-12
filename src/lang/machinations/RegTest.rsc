@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Regression Test
* @package      lang::machinations
* @file         RegTest.rsc
* @brief        Defines the Micro-Machinations regression test.
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::RegTest

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
import Message;
import IO;
import String;

private loc MACHINATIONS_LOC = |project://MM-AiR/test|;
private str MACHINATIONS_SFX = ".mach4";

data Verdict
  = success(loc l)
  | parserFail(loc l, str e)
  | imploderFail(loc l, str e)
  | desugarFail(loc l, str e)
  | labelerFail(loc l, str e)
  | flattenerFail(loc l, str e)
  | evaluatorFail(loc l, str e)
  | assertionFail(loc l, str e)
  | preprocessorFail(loc l, str e)
  ;
  
public test bool testAll()
{
  return testAll(MACHINATIONS_LOC, MACHINATIONS_SFX);
}
  
public bool testAll(loc files_loc, str suffix)
{
  set[loc] files = getFiles(files_loc, suffix);
  set[Verdict] verdicts = {machinations_test(file) | file <- files};
  set[Verdict] failures = {v | v <- verdicts, success(_) !:= v};

  iprintln(failures);
  return failures == {};
}

private set[loc] getFiles(loc files_loc, str suffix)
 = {files_loc+"/<file>" | file <- listEntries(files_loc), endsWith(file, suffix)};

private Verdict machinations_test(loc l)
{
  Tree t;
  Machinations m1, m2, m3, m4, m5;
  Mach2 m6;
  list[Msg] msgs3, msgs5, msgs6;
  list[tuple[State,Transition]] trace;
  
  println(l);

  //println("1. Parse");
  try
  {
    t = machinations_parse(l);
  }
  catch e:
  {
    return parserFail(l, toString(e));
  }
  
  //println("2. Implode");
  try
  {
    m1 = machinations_implode(t); 
  }
  catch e:
  {
    return imploderFail(l, toString(e));
  }
  
  //println("3. Desugar");
  try
  {
    m2 = machinations_desugar(m1);
  }
  catch e:
  {
    return desugarFail(l, toString(e));
  }
  
  //println("4. Flatten");
  try
  {
    <m3, msgs3> = machinations_flatten(m2);
    if(msgs3 != [])
    { 
      throw msgs3;
    }
  }
  catch e:
  {
    return flattenerFail(l, toString(e));
  }
  
  //println("5. Desugar Flat");
  try
  {
    m4 = machinations_desugarFlat(m3);
  }
  catch e:
  {
    return desugarFail(l,toString(e));
  }
  
  //println("6. Label");
  try
  {
    <m5, msgs5> = machinations_label(m4);
    if(msgs5 != [])
    {
      throw msgs5;
    }
  }
  catch e:
  {
    return labelerFail(l,toString(e));
  }
  
  //println("7. Preprocess\n");
  try
  {
    m6 = machinations_preprocess(m5);
  }
  catch e:
  {
    return preprocessorFail(l,toString(e));
  }

  //println("8. Simulate");
  try
  {
    <trace, msgs6> = machinations_simulate(m6, 100);
    if([msg_AssertionViolated(State s, Element e)] := msgs6 &&
       e.name.name == "ends")
    {
      ;
    }
    else if(msgs6 != [])
    {      
      throw msgs6;
    }
  }
  catch e:
  {
    return evaluatorFail(l,toString(e));
  }
  
  return success(l);
}
