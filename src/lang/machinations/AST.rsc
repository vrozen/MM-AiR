@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Abstract Syntax
* @package      lang::machinations
* @file         Machinations.rsc
* @brief        Defines Machinations Abstract Syntax
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::AST
import ParseTree;

public int MAX_INT = 2147483647;

anno loc Machinations@location;
anno loc ID@location;
anno loc Element@location;
anno loc Exp@location;
anno int Element@l; //label
anno int ID@l;      //label

data Machinations
  = mach(list[Element] elements);
//Note: A flow from a drain is an error --\> checker
//Note: A flow to a source is an error --\> checker

data Element
  //basic elements:
  = pool      (When when, Act act, How how, ID name, list[Unit] units, At at, Add add, Min min, Max max)
  | gate      (When when, Act act, How how, ID name, list[Unit] opt_u) //Dist removed
    //NOTE: all gates automatically push and they cannot be disabled. pull, passive or start are not supported
  | flow      (list[ID] src, Exp exp, list[ID] tgt)
  | state     (list[ID] src, Exp exp, list[ID] tgt)
  | always    (ID name, Exp exp, str msg)
  //syntactic sugar:
  | source    (When when, Act act, How how, ID name, list[Unit] opt_u)
  | drain     (When when, Act act, How how, ID name, list[Unit] opt_u)
  | converter (When when, Act act, How how, ID name, list[Unit] opt_src_u, list[Unit] opt_tgt_u)
  | delay     (When when, Act act, How how, ID name, list[Unit] opt_u, int val)  
  //temporary desugaring block:
  | block     (list[Element] elements)
  //flattened flow
  | flow      (ID s, Exp exp, ID t)
  | state     (ID s, Exp exp, ID t)
  //component elements:
  //Added: global scripting commands (breaks declarative universe)
  //1. use component to spawn and
  //2. remove to unspawn component type instances  
  | ctype     (ID name, list[Param] params, list[Element] elements)  
  | component (ID t, ID name)
  | del       (list[ID] names)
  | del       (ID name) //flattened
  | unit      (ID name, str msg)
  ;

data Param
  = param(IO io, ID name);

data IO
  = io_ref()
  | io_in()
  | io_out()
  | io_inout();

data At //start value
  = at_none()
  | at_val(int v);

data Add //node modifier edges together form an expression that adjusts the value of a pool
  = add_none()
  | add_exp(Exp exp);

data Min //minimum pool value
  = min_none()
  | min_val(int v);

data Max //maximum pool value
  = max_none()
  | max_val(int v);

data When
  = when_passive()
  | when_user()
  | when_auto()
  | when_start();

data Act
  = act_pull()
  | act_push();
  
data How
  = how_any()
  | how_all();

//data Dist
//  = dist_deterministic()
//  | dist_random();

data Unit
  = u_name     (ID name)
  | u_override (Unit u)
  | u_div      (Unit u1, Unit u2)
  | u_mul      (Unit u1, Unit u2);

data Exp
  // expand the following implicit notation
  = e_one()                 //desugar --> usually: e_val(1.0, [])
  | e_trigger()             //desugared e_mul(e_one(), e_one())
  | e_ref()                 //may not appear as any sub expression, only valid use is in state as parent exp
  | e_range(int low, int high)
  | e_die(int size)         //desugar --> e_range(1, size)
  | e_percent(Exp e)
  | e_per(Exp e, int n)     //desugar --> buffer. NOTE: in Machinations changing n is possible.
  | e_val(real v, list[Unit] opt_u) //Arithmetic value Expression
  | e_true()                 //Boolean true Expression
  | e_false()                //Boolean false Expression
  | e_all()                  //Arithmetic all Expression (refers to all resources in al pool)
  | e_name(list[ID] names)   //namespace query
  | e_name(ID name)          //flattened name space query
  | e_active(list[ID] names) //activity query
  | e_active(ID name)        //flattened activity query 
  | e_override(Exp e)        //Overriden expression
  | e_not(Exp e)             //Boolean Unary Not Expression
  | e_unm(Exp e)             //Arithmetic Negation Unary Expression
  | e_lt(Exp e1, Exp e2)     //Relational Less Than Expression
  | e_gt(Exp e1, Exp e2)     //Relational Greater Than Expression
  | e_le(Exp e1, Exp e2)     //Relational Less-Equals Expression
  | e_ge(Exp e1, Exp e2)     //Relational Greater-Equals Expression
  | e_neq(Exp e1, Exp e2)    //Relational Not-Equals Expression
  | e_eq(Exp e1, Exp e2)     //Relational Equals Expression
  | e_and(Exp e1, Exp e2)    //Boolean and Expression
  | e_or(Exp e1, Exp e2)     //Boolean or Expression
  | e_mul(Exp e1, Exp e2)    //Arithmetic Multiply Binary Expression
  | e_div(Exp e1, Exp e2)    //Arithmetic Divide Binary Expression
  | e_add(Exp e1, Exp e2)    //Arithmetic Plus Binary Expression
  | e_sub(Exp e1, Exp e2)    //Arithmetic Minus Binary Expression
  ;
  
data ID
  = id(str name);
 
public lang::machinations::AST::Machinations machinations_implode(Tree t)
  = implode(#lang::machinations::AST::Machinations, t);

//boolean pattern matching on elements
public bool isPool(Element n)
  = (pool (When when, Act act, How how, ID name, list[Unit] units, At at, Add add, Min min, Max max) := n);

public bool isGate(Element n)
  = (gate (When when, Act act, How how, ID name, list[Unit] opt_u) := n);

public bool isSource(Element n)
  = (source (When when, Act act, How how, ID name, list[Unit] opt_u) := n);
  
public bool isDrain(Element n)
  = (drain (When when, Act act, How how, ID name, list[Unit] opt_u) := n);
  
public bool isFlow(Element e)
  = (flow (ID s, Exp exp, ID t) := e);
  
public bool isState(Element e)
  = (state (ID s, Exp exp, ID t) := e);
  
public bool isNode(Element e)
  = isPool(e) || isGate(e) || isSource(e) || isDrain(e);