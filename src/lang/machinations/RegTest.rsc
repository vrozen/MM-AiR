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
import lang::machinations::Machinations;

import ParseTree;
import Message;
import IO;
import String;

private loc MACHINATIONS_LOC = |project://MM-AiR/test|;
private str MACHINATIONS_SFX = ".mach4";
  
public test bool mm_testAll()
  = mm_testAll(MACHINATIONS_LOC, MACHINATIONS_SFX);

public bool mm_testAll(loc files_loc, str suffix)
{
  set[loc] files = getFiles(files_loc, suffix);
  list[Msg] failures = [*mm_test(file) | file <- files];
  println(toString(failures));
  return failures == [];
}

public set[loc] getFiles(loc files_loc, str suffix)
 = {files_loc+"/<file>" | file <- listEntries(files_loc), endsWith(file, suffix)};

public list[Msg] mm_test(loc l)
{
  tuple[Mach2 m2, list[tuple[State,Transition]] trace, list[Msg] msgs] r =  mm_simulate (mm_parse(l), l, 100);  
  return r.msgs;
}
