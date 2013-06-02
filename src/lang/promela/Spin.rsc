@license{
  Copyright (c) 2009-2013 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Riemer van Rozen - HvA / CWI (rozen@cwi.nl)}

@doc{
Synopsis: Execute and manage Spin model-checker.
}
module lang::promela::Spin

import String;
import ParseTree;
import util::IDE;
import vis::Figure;

start syntax Spin
 = spin: Segment*;

syntax Var
 = var: NAME NAME ":" VALUE;

syntax Line
 = line:  NAME ":" VALUE "," "state" VALUE "," String;

syntax Handle
 = h_never:   "never claim" HandleSwitch
 | h_assert:  "assertion violations" HandleSwitch
 | h_accept:  "acceptance   cycles" HandleSwitch
 | h_cycle:   "cycle checks" HandleSwitch
 | h_end:     "invalid end states" HandleSwitch;

syntax HandleSwitch
 = h_min:     "-" Par
 | h_plus:    "+";

syntax Segment
 = error:   "error: max search depth too small"
 | interrupted: 
            "Interrupted"
 | violate: "pan:" VALUE ": assertion violated" Par "(at depth" VALUE ")"
 | trail:   "spin: trail ends after" VALUE "steps"
 | wrote:   "pan: wrote" NAME
 | reduce:  "pan: reducing search depth to" VALUE
 | version:  Par
 | porUsed: "+ Partial Order Reduction"
 | globals: "global vars:" Var*
 | locals:  "local vars proc" VALUE Par ":" Var*
 | warnSearchNotCompleted:
            "Warning: Search not completed"
 | handles: "Full statespace search for:" Handle*
 | status:  "State-vector" VALUE
            "byte, depth reached" VALUE
            ", errors:" VALUE
            VALUE "states, stored"
            VALUE "states, matched"
            VALUE "transitions (= stored+matched)"
            VALUE "atomic steps"
            "hash conflicts:" VALUE "(resolved)"
 | memuse:  "Stats on memory usage (in Megabytes):"
            VALUE "equivalent memory usage for states (stored*(State-vector + overhead))"
            VALUE "actual memory usage for states"
            VALUE "memory used for hash table" Par
            VALUE "memory used for DFS stack" Par
            VALUE "total actual memory usage"
 | unreached:
            "unreached in proctype" NAME
            Line+
            "(" VALUE "of" VALUE "states" ")"
 | elapsed: "pan: elapsed time" VALUE "seconds"
 | rate:    "pan: rate" VALUE "states/second";

syntax Par
  = @category="Parent" "(" PARENT ")";

syntax String
  = @category="String"  "\"" STRING "\"";

lexical VALUE
  = @category="Value" ([0-9]+([.][0-9]+?)?)([e][+\-][0-9]+)?;

lexical NAME
  = @category="Name" ([a-zA-Z_$.] [a-zA-Z0-9_$.]* !>> [a-zA-Z0-9_$.]);
  
lexical STRING
  = ![\"]*;

lexical PARENT
  = ![)]*;
  
layout LAYOUTLIST
  = LAYOUT* !>> [\t-\n \r \ ] !>> "//" !>> "/*";

lexical LAYOUT
  = Comment
  | [\t-\n \r \ ];
  
lexical Comment
  = @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
  | @category="Comment" "//" ![\n]* [\n];


public str SPIN_REPORT_EXT = "svr";
public str SPIN_REPORT_NAME = "Spin Verification Report";

data Spin
  = spin(list[Segment] segments);

data Var
  = var(str t, str name, int val);

data Line
  = line 
  (
    str file,
    int line,
    int state,
    str text
  );

data Handle
 = h_never(HandleSwitch hs)
 | h_assert(HandleSwitch hs)
 | h_accept(HandleSwitch hs)
 | h_cycle(HandleSwitch hs)
 | h_end(HandleSwitch hs);

data HandleSwitch
 = h_min(str text)
 | h_plus();

data Segment
  = error()
  | interrupted()
  | violate(int count, str text, int depth)
  | trail(int steps)
  | wrote(str name)
  | reduce(int depth)
  | version(str text)
  | porUsed()
  | warnSearchNotCompleted()
  | handles(list[Handle] handles) //TODO
  | globals(list[Var] vars)
  | locals(int pid, str name, list[Var] vars)
  | status
  (
    real stateVectorSize,
    real depthReached,
    real errors,
    real statesStored,
    real statesMatched,
    real transitions,
    real atomicSteps,
    real hashConflicts
  )
  | memuse
  (
    real states,
    real actualStates,
    real hashTable,
    str hashText,
    real dfsStack,
    str dfsText,
    real total
  )
  | unreached
  (
    str name,
    list[Line] lines,
    int numStates,
    int allStates
  )
  | elapsed
  (
    real seconds
  )
  | rate
  (
    real statesPerSecond
  );

public lang::promela::Spin::Spin spin_implode(Tree t)
  = implode(#lang::promela::Spin::Spin, t);

public start[Spin] spin_parse(str txt)  = parse(#start[Spin], txt);

public start[Spin] spin_parse(loc file) = parse(#start[Spin], file);

public start[Spin] spin_parse(str txt, loc file) = parse(#start[Spin], txt, file);


private node spin_outline (Tree t) = spin_implode(t);
  
public void spin_register()
{
  Contribution spin_style =
    categories
    (
      (
        "Name" : {foregroundColor(color("royalblue"))},
        "Parent" : {foregroundColor(color("darkblue")),bold()},
        "Comment": {foregroundColor(color("dimgray"))},
        "Value": {foregroundColor(color("firebrick"))},
        "String": {foregroundColor(color("teal"))}
        //,"MetaKeyword": {foregroundColor(color("blueviolet")), bold()}
      )
    );

  registerLanguage(SPIN_REPORT_NAME, SPIN_REPORT_EXT, lang::promela::Spin::spin_parse);
  registerOutliner(SPIN_REPORT_NAME, spin_outline);
  //registerContributions(SPIN_REPORT_NAME, spin_contributions);
}
  
/*


void spin_check(loc pmlFile)
{
  loc workingDir = pmlFile.parent;  
  str file = pmlFile.path;
  
  if(endsWith(file, ".pml"))
  {
    str verifier = substring(file, 0, size(file)-4);
  
  println("Input <pmlFile>"); 
  println("Working dir <workingDir>");
  println("File <file>");
  
  PID spinPID = createProcess("./check.sh", ["<file>"]);  
  
  println(readEntireStream(spinPID));
    
  println(readEntireErrStream(spinPID));

  killProcess(spinPID);  
    //PID gccPID = createProcess("gcc", ["pan.c", "--DSAFETY", "-o <verifier>"]);
  
    //TODO close
  } 
}

void spin_compile(loc pmlFile)
{
  loc workingDir = pmlFile.parent;  
  str file = pmlFile.path;
  
  if(endsWith(file, ".pml"))
  {
    str verifier = substring(file, 0, size(file)-4);
  
    println("Input <pmlFile>"); 
    println("Working dir <workingDir>");
    println("File <file>");
  
    PID spinPID = createProcess("spin", ["-a", "<file>"]);  
  
    println(readEntireStream(spinPID));
    
    println(readEntireErrStream(spinPID));

    killProcess(spinPID);  
    //PID gccPID = createProcess("gcc", ["pan.c", "--DSAFETY", "-o <verifier>"]);
  
    //TODO close
  }
  return;
}



//read lines
//line contains unreached
//read until end
//<file_name>:<int>,
/*
public list[int] getUnreached(loc spin_out_loc)
{
  list[str] lines = readFileLines(spin_out_loc);
  list[int] lineNumbers = [];
  str segment = "";
  str file = "all.pml";
  int i =0 ;
  str tail = "";
  
  for(str line <- lines)
  {
    if(contains(line, "unreached"))
    {
      segment = "unreached";
      println("Segment unreached found");
    }
    
    switch(segment)
    {
      case "unreached":
      {
        (Reach) `
      
        if("<file>:<i>,<tail>" := line)
        {
          println("got match");
          println(i);
          println(tail);
          lineNumbers += [i];
        }
      }
    }
  }
  return lineNumbers;
}


tuple[ list[int] unreached] spin_verify(loc pmlFile, list[str] options)
{
  loc verifier;
  PID verifierPID = createProcess("<bin_file>");
  
}

str spin_replay(str pmlFile)
{
}
*/