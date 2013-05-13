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
import lang::machinations::Message;
import lang::machinations::Machinations;
import lang::machinations::Trace;
import lang::machinations::Serialize;

import IO;
import String;
import List;

private loc MM_TEST_LOC = |project://MM-AiR/test|;
private str SPIN_OUT_EXT = "spin_out";
  
public test bool mm_testAll()
  = //mm_testAll(MM_TEST_LOC, MM_EXT) &&
    mm_testAll(MM_TEST_LOC, MM_TRACE_EXT);

public test bool mm_traceTestAll()
  = mm_testAll(MM_TEST_LOC, MM_TRACE_EXT);

public bool mm_testAll(loc files_loc, str ext)
{
  set[loc] files = getFiles(files_loc, ext);
  list[Msg] failures = [*mm_test(file, ext) | file <- files];
  println(toString(failures));
  return failures == [];
}

public set[loc] getFiles(loc files_loc, str ext)
 = {files_loc+"/<file>" | file <- listEntries(files_loc), endsWith(file, ext)};

public list[Msg] mm_test(loc l, MM_EXT)
{
  println("Testing <l>");
  tuple[Mach2 m2, list[tuple[State,Transition]] trace, list[Msg] msgs] r =  mm_simulate (mm_parse(l), l, 100);  
  return r.msgs;
}

public list[Msg] mm_test(loc l, MM_TRACE_EXT)
{
  println("Testing <l>");
  tuple[Mach2 m2, list[tuple[State,Transition]] trace, list[Msg] msgs] r =  mm_play (mm_trace_parse(l), l);
  return r.msgs;
}

//temporary solution for generating Promela for all test models
public void mm_testAllToPromela()
{
  set[loc] files = getFiles(MM_TEST_LOC, MM_EXT);
  for(loc f <- files)
  {
    mm_ide_toPromela (mm_parse(f), f);
  }
}

public void mm_testAllToTrace()
{
  set[loc] files = getFiles(MM_TEST_LOC, SPIN_OUT_EXT);
  for(loc spin_out_loc <- files)
  {
    println("read <spin_out_loc>");
    loc mmt_loc = spin_out_loc;
    mmt_loc.extension = MM_TRACE_EXT;    
    str mmt_model = "";
    list[str] lines = readFileLines(spin_out_loc);
    for(str line <- lines)
    {
      if(startsWith(line, "MM:"))
      {
        mmt_model += "<trim(replaceAll(line,"MM:",""))>\n";
      }
    }
    println("write file <mmt_loc>\n<mmt_model>");
    writeFile(mmt_loc, mmt_model);    
    //writeFile(mmt_loc, toString(mm_trace_transform(mm_trace_implode(mm_trace_parse(mmt_loc)))));
  }
}