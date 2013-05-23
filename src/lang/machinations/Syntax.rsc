@license{
  Copyright (c) 2009-2011 CWI and HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Syntax
* @package      lang::machinations
* @file         Syntax.rsc
* @brief        Defines the syntax of Micro-Machiations
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         June 1st 2012
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Syntax

/******************************************************************************** 
  Micro Machinations Reach
********************************************************************************/
start syntax Reach
  = reach_flow_all: "reach_all" "(" VALUE "," VALUE ")"
  | reach_flow_any: "reach_any" "(" VALUE "," VALUE ")"
  | reach_trigger:  "reach_trigger" "(" VALUE "," VALUE ")";

/******************************************************************************** 
  Micro Machinations Traces
********************************************************************************/
start syntax Trace
  = trace: Event*
  | trace: ("MM:" Event)*;
  
syntax Event
  = tr_flow:    NID "-" VALUE "-" "\>" NID
  | tr_next:    "step"
  | tr_trigger: "trigger" NID
  | tr_inhibit: "inhibit" NID  //NOTE: not used yet
  | tr_signal:  "signal"  NID  //NOTE: not used yet
  | tr_violate: "violate" NID
  | tr_state:   "state" "(" {StateValue ","}* ")";
  
syntax StateValue
  = NID "=" VALUE;

/******************************************************************************** 
  Notes on changes and adjustments.
  Flow had name such that state edges (flow modifier edges) could adjust it.
  This is removed since the flow expression expresses the same thing.
  It was:    flow:      (NID ":")? {NID "."}+ "-" Exp "-\>" {NID "."}+ 

  Note: state and flow edges denote many different things, context sensitive!
  However not activator edges and trigger edges:
    1. activator edges with boolean expressions specifiying the activation codition
    2. and trigger edges, which activate a target node whenever a source nodes conditions are all validated
  removed are
    1. flow modifier edges --> these are flow value expressions now
    2. node modifier edges --> these are node value expressions now
    3. modifier modifier edges --> hopefully these can also be exoressed using expressions
  It is possible to translate graphical machinations to this texual format.
********************************************************************************/

start syntax Machinations
  = mach: Element*;

syntax Element
  = ctype:     TID "(" {Param ","}* ")" "{" Element* "}"
  | component: TID NID        //added semantics "spawn"
  | del:       "delete" NID   //added for scripting "unspawn"
  | unit:      "unit" NID ":" String
  | source:    When Act How "source" NID ("of" Unit)?       //ACT --> always push
  | drain:     When Act How "drain" NID ("of" {Unit ","}+)? //ACT --> always pull
  | pool:      When Act How "pool" NID ("of" {Unit ","}+)? At Add Min Max
  | always:    "assert" NID ":" Exp String
  | converter: When Act How "converter" NID ("from" Unit)? ("to" Unit)? //converters convert one resource into another
  | delay:     When Act How "delay" NID ("of" {Unit ","}+)? "by" VALUE //delays are fixed for now
  | gate:      When Act How "gate" NID ("of" Unit)?  //Dist removed
  //in textual machinations all edges connect two nodes:
  | flow:      {NID "."}+ "-" Exp "-\>" {NID "."}+       //flow        if (pool -ValExp-> node)
                                                         //probability if (gate -ValExp-> node)
                                                         //coondition  if (gate -BoolExp-> node)
                                                         //alias       if (node --> ref node)
  | state:     {NID "."}+ "." Exp "." "\>" {NID "."}+    //trigger     if (pool .*.> node)
                                                         //activator   if (pool .BoolExp.> node)
                                                         //trigger     if (gate .BoolExp.> node)
                                                         //trigger     if (gate .ValExp.> nide)
  ;

syntax Param //component type parameters for connecting edges to components
  = param: IO NID;

syntax At    //initial value of a pool
  = at_none: //default is zero
  | at_val: "at" VALUE;

syntax Add    //modification expression of a pool
  = add_none: //default is no modification
  | add_exp: "add" Exp;
  
syntax Min    //minimum value of a pool
  = min_none: //default is no lower bound
  | min_val: "min" VALUE;

syntax Max    //maximum value of a pool
  = max_none: //default is no upper bound
  | max_val: "max" VALUE;
  
syntax IO //type parameter is input, output or both
  = io_ref: "ref"       //external node is referred to from the inside
                        //references may not be defined inside the component type
  | io_in:  "in"        //internal node consumes input from external nodes
                        //inputs must be defined inside the component type
  | io_out: "out"       //internal node provides output to external nodes
                        //output must be defined inside the component type
  | io_inout: "inout";  //internal node consomes input from, 
                        //and provis output to external nodes
                        //input/output must be defined inside the component type
                        
syntax When //when does a node act?
  = when_passive: //default
  | when_passive: "passive"
  | when_user:    "user"
  | when_auto:    "auto"
  | when_start:   "start";

syntax Act //what does a node do?
  = act_pull: //default
  | act_pull: "pull"
  | act_push: "push";

syntax How //how does a pool perform an act?
  = how_any:  //default
  | how_any: "any"
  | how_all: "all";

//syntax Dist //what does a gate do?
//  = dist_deterministic:   //default: distribute resources deterministically
//  | dist_radom: "random"; //distribute resources randomly

syntax Unit
  = u_name: UID
  | u_override: "(" Unit ")"
  | u_div: Unit "/" Unit
  | u_mul: Unit "*" Unit;

syntax Exp
  = e_one:
  | e_val:       VALUE Unit?     //Value with optional unit of measurement
  | @category="Value"  e_true:  "true"
  | @category="Value"  e_false: "false"
  | e_name:      {NID "."}+      //Name space query
  | e_override:  "(" Exp ")"     //Override priorities
  | e_active: "active" {NID "."}+
  | e_all: "all"
  | e_ref: "="
  | e_die: VALUE "dice"          //Random number in {1..VALUE+1}
  | e_range: VALUE ".." VALUE    //Random number in {VALUE..VALUE+1}
  > e_per: Exp "|" VALUE !>> Exp //amount that will flow after N iterations  --> desugar to buffer      
  > e_percent: Exp "%"           //state (trigger from gate to node) percentage adds up to 100%                             
                                 //flow percentage refers to the source            
  > e_unm: "~" Exp               //Arithmetic Negation Unary Expression
  | e_not: "!" Exp
  > left
    ( left e_mul: Exp "*" Exp   //Arithmetic Multiply Binary Expression
    | left e_div: Exp "/" Exp   //Arithmetic Divide Binary Expression
    )
  > left
    ( left e_add: Exp "+" Exp   //Arithmetic Plus Binary Expression
    | left e_sub: Exp "-" Exp   //Arithmetic Minus Binary Expression
    )
  > left
    ( left e_lt:  Exp "\<" Exp  //Relational Less Than Binary Expression
    | left e_gt:  Exp "\>" Exp  //Relational Greater Than Binary Expression
    | left e_le:  Exp "\<=" Exp //Relational Less-Equals Binary Expression
    | left e_ge:  Exp "\>=" Exp //Relational Greater-Equals Binary Expression
    | left e_neq: Exp "!=" Exp  //Relational Not-Equals Binary Expression
    | left e_eq:  Exp "==" Exp  //Relational Equals Binary Expression 
    )
  > left e_and: Exp "&&" Exp
  > left e_or: Exp "||" Exp
  ;

syntax String
  = @category="String"  "\"" STRING "\"";
    
syntax NID
  = @category="Name" ID;
  
syntax TID
  = @category="TypeName" ID; 
  
syntax UID
  = @category="UnitName" ID;
    
syntax ID
  = id: NAME;

lexical VALUE
  = @category="Value" ([0-9]+([.][0-9]+?)?);  

lexical NAME
  = ([a-zA-Z_$] [a-zA-Z0-9_$]* !>> [a-zA-Z0-9_$]) \ Keyword;
  
lexical STRING
  = ![\"]*;
  
layout LAYOUTLIST
  = LAYOUT* !>> [\t-\n \r \ ] !>> "//" !>> "/*";

lexical LAYOUT
  = Comment
  | [\t-\n \r \ ];
  
lexical Comment
  = @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
  | @category="Comment" "//" ![\n]* [\n];

keyword Keyword
  = "source" | "pool" | "drain" | "gate" | "converter" | "delay" | "assert" | "delete" | "unit"
  | "of" | "from" | "to" | "add" | "at" | "min" | "max"
  | "passive" | "user" | "auto" | "start"
  | "push" | "pull" | "any" | "all"
  | "true" | "false" | "dice" | "active"
  | "ref" | "in" | "out" | "inout" |
  | "step" | "violate";
  
public start[Machinations] mm_parse(str src, loc file) = 
  parse(#start[Machinations], src, file);
  
public start[Machinations] mm_parse(loc file) = 
  parse(#start[Machinations], file);
  
public start[Trace] mm_trace_parse(str src, loc file) = 
  parse(#start[Trace], src, file);

public start[Trace] mm_trace_parse(loc file) =
  parse(#start[Trace], file);
  