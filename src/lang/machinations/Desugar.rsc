@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Machinations abstract syntax desugaring
* @package      lang::machinations
* @file         Desugar.rsc
* @brief        Defines desugarings of ASTs.
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Desugar

import lang::machinations::AST;
import IO;
import List;
import util::Math;

public Machinations mm_desugar (Machinations m)
{
  return visit(m)
  {
    case mach(list[Element] elements):
    {
      insert mach(elements + [*es | block(list[Element] es) <- elements] - [e | e: block(_) <- elements])[@location = m@location];
    }
    case ct: ctype(n, params, list[Element] elements):
    {
      insert ctype(n, params, elements + [*es | block(list[Element] es) <- elements] - [e | e: block(_) <- elements]);
    }
    case src: source(When when, Act act, How how, ID name, list[Unit] opt_u):
    {
      insert source(when, act_push(), how_all(), name, opt_u)[@location = src@location]; //override to always push all !!!
    }
    case drn: drain(When when, Act act, How how, ID name, list[Unit] opt_u):
    {
      insert drain(when, act_pull(), how, name, opt_u)[@location = drn@location]; //override to always pull (any or all)
    }
    case at_none():
    {
      insert at_val(0);
    }
    case e_die(int val):
    {
      insert e_range(1, val);
    }
    case e: always(_,_,_):
    {
      insert visit(e)
      {
        case e_one(): insert e_val(1.,[]);
      }
    }
    case e: add_exp(_):
    {
      insert visit(e)
      {
        case e_one(): insert e_val(1.,[]);
      }
    }
    case f: flow(list[ID] src, Exp e, list[ID] tgt):
    {
      insert desugarFlow(m, f);
    }
    case s: state(list[ID] src, Exp e, list[ID] tgt):
    {
      insert desugarState(m, s);
    }
  }
}

public Element getElement(Machinations m, ID name)
 = getElement(m.elements, name);

//retrieve an element by name from an unflattened model
private Element getElement(list[Element] elements, list[ID] name)
{
  for(e <- elements, isNode(e))
  {
    if(e.name.name == head(name).name)
    {
      if(size(name) == 1)
      {
        return e;
      }
      else if(ctype(_,_, list[Element] es) := e)
      {
        return getElement(es, tail(name));
      }
      else
      {
        throw "expected component type <head(name)>, found <e>";
      }
    }
  }
  throw "name <name> not found in elements";
}

private Element desugarFlow(Machinations m, f: flow(list[ID] src, e: e_one(), list[ID] tgt))
  = flow(src, e_val(1.,[])[@location = e@location], tgt)[@location = f@location];
  
private Element desugarFlow(Machinations m, f: flow(list[ID] src, e: e_all(), list[ID] tgt))
  = flow(src, e_name(src)[@location = e@location], tgt)[@location = f@location];

//NOTE: e_per is only allowed as top-level expression and not as a child-expression
//TODO: check this in a contextual analyzer
private Element desugarFlow(Machinations m, f: flow(list[ID] src, e_per(Exp exp, int n), list[ID] tgt))
  = desugarPer(m, f);
  
private Element desugarFlow(Machinations m, f: flow(list[ID] src, Exp exp, list[ID] tgt))
  = flow(src, desugarExp(src,exp,tgt), tgt)[@location = f@location];

private Element desugarState(Machinations m, s: state(list[ID] src, Exp exp, list[ID] tgt))
  = state(src, desugarExp(src,exp,tgt), tgt)[@location = s@location];
 
private Exp desugarExp(list[ID] src, Exp e, list[ID] tgt)
{
  return visit(e)
  {
    //in multiplication expressions without arguments
    //shorthand is rewritten to a trigger
    case exp: e_mul(e_one(), e_one()):
    {
      insert e_trigger()[@location = exp@location];
    }
    case exp: e_eq(e_one(), e_one()):
    {
      insert e_ref()[@location = exp@location];
    }
    case Exp exp:
    {
      //in expressions with one sub-expression
      //shorthand is replaced by a number 1.0
      if(exp.e? && exp.e == e_one())
      {
        exp.e = e_val(1.,[])[@location = exp.e@location];
        insert exp;
      }      
      //in expressions with left-hand and right-hand side expressions
      //shorthand is replaced by source and target names
      else if(exp.e1? && exp.e2?)
      {
        if(exp.e1 == e_one())
        {
          exp.e1 = e_name(src)[@location = exp.e1@location];
        }
        if(exp.e2 == e_one())
        {
          exp.e2 = e_name(src)[@location = exp.e2@location];
        }
        insert exp;
      }
    }
  }
}

//FIXME: agree on a semantics for per
private Element desugarPer(Machinations m, e: flow(list[ID] src, e_per(Exp exp, int n), list[ID] tgt))
{
  ID timerId = id("<last(src).name>_timer_tick")[@location = last(src)@location];
  ID resetId = id("<last(src).name>_timer_reset")[@location = last(src)@location];
  ID countId = id("<last(src).name>_timer")[@location = last(src)@location];
  ID flushId = id("<last(src).name>_flush")[@location = last(src)@location];
  ID bufferId = id("<last(src).name>_buffer")[@location = last(src)@location];
  
  Element input = getElement(m.elements, src);
  Element output = getElement(m.elements, tgt);
  Act act;
  How how;
  
  if(input.act == act_push() && output.act == act_pull())
  {
    ; //semantics clash
  }
  else if(input.act == act_push())
  {
    //buffer uses input
    act = input.act;
    //how = input.how; //FIXME
    how = how_all();  //FIXME
  }
  else if(output.act == act_pull())
  {
    //buffer uses output
    act = output.act;
    //how = input.how; //FIXME
    how = how_all();  //FIXME
  }

  return block
  (
    [
      /*timer*/  source(when_auto(), act_push(), how_all(), timerId, [])[@location = e@location], //FIXME
      /*reset*/  drain (when_auto(), act_pull(), how_any(), resetId, [])[@location = e@location], //FIXME
      /*count*/  pool  (when_passive(), act_pull(), how_any(), countId, [], at_val(2), add_none(), min_none(), max_none())[@location = e@location],
      /*buffer*/ pool  (when_auto(), act_pull(), how_any(), bufferId, [], at_val(0), add_none(), min_none(), max_none())[@location = e@location],
      /*flush*/  gate  (when_passive(), act_pull(), how_any(), flushId, [])[@location = e@location],
      flow (src, exp, [bufferId])[@location = e@location],
      flow (bufferId, e_name(bufferId)[@location = e@location], flushId)[@location = e@location],
      flow ([flushId], e_name(flushId)[@location = e@location], tgt)[@location = e@location],
      flow (timerId, e_val(1., []), countId)[@location = e@location],
      flow (countId, e_name(countId)[@location = e@location], resetId)[@location = e@location],
      state (bufferId, e_eq(e_name(bufferId)[@location=bufferId@location], e_val(0.,[])[@location=e@location]), bufferId)[@location = e@location],
      state (countId, e_eq(e_name(countId)[@location=countId@location], e_val(toReal(n),[])[@location=e@location]), resetId)[@location = e@location],
      state (resetId, e_trigger(), flushId)[@location = e@location]
    ]
  );
}

//Flat model desugaring 
//Converter works well
//Delay is mostly untested, does it have the correct semantics?    
public Machinations mm_desugarFlat(Machinations m)
{
  for(e: converter(When when, Act act, How how, ID name, list[Unit] opt_src_u, list[Unit] opt_tgt_u) <- m.elements)
  {
    ID drainId = id("<name.name>_drain")[@location = name@location];
    ID sourceId = id("<name.name>_source")[@location = name@location];

    //1. divert all flow into the converter node to the drain node
    m.elements = divertInFlow(m.elements, name, drainId);
        
    //2. divert all flow from the converter node to the source node 
    m.elements = divertOutFlow(m.elements, name, sourceId);

    //3. divert all state into the converter node to the drain node  
    m.elements = divertInState(m.elements, name, drainId);

    //4. divert all state from the converter node to the drain node
    m.elements = divertOutState(m.elements, name, drainId); 

    m.elements -= [e];

    m.elements +=
    [
      drain(when, act_pull(), how, drainId, opt_src_u)[@location = e@location],
      state(drainId,e_trigger(),sourceId)[@location = e@location],
      source(when_passive(), act_push(), how_all(), sourceId, opt_tgt_u)[@location = e@location]
    ];
  }
    
  for(e: delay(When when, Act act, How how, ID name, list[Unit] opt_u, val) <- m.elements)
  {
    ID firstId = id(name.name + "1")[@location = name@location];
    Element prev = pool(when, act, how, firstId, opt_u, at_val(0), add_none(), min_none(), max_none())[@location = e@location];
    list[Element] es = [prev];
    for(i <- [2..val+1]) //FIXME: range
    {
      //create a pool that automatically pulls all resources
      ID poolId = id(name.name + "<i>")[@location = e@location]; 
      Element flow = flow(prev.name, e_name(prev.name), poolId)[@location = e@location];
      Element cur = pool(when_auto(), act, how, poolId, [], at_val(0), add_none(), min_none(), max_none())[@location = e@location];
      //create a flow between the previous element and this one
      prev = cur;    
      es += [cur,flow];
    }

    //1. divert all flow into the delay node to the first pool       
    m.elements = divertInFlow(m.elements, name, firstId);
  
    //2. divert all state into the delay node to the first pool        
    m.elements = divertOutFlow(m.elements, name, prev.name);

    //3. divert all flow from the delay node to the last pool
    m.elements = divertInState(m.elements, name, firstId);

    //4. divert all state from the delay node to the last pool
    m.elements = divertOutState(m.elements, name, prev.name); 
    m.elements += es;
    m.elements -= [e];
  }

  return m;  
}

//divert inFlow of n to r in es
public list[Element] divertInFlow(list[Element] es, ID n, ID r)
  = es
  + [flow(src,exp,r)[@location = f@location] | f: flow(src,exp,tgt) <- inFlow(es, n)]
  - inFlow(es, n);

//divert outFlow of n to r in es
public list[Element] divertOutFlow(list[Element] es, ID n, ID r)
  = es
  + [flow(r,exp,tgt)[@location = f@location] | f: flow(src,exp,tgt) <- outFlow(es, n)]
  - outFlow(es, n);

//divert inState of n to r in es
public list[Element] divertInState(list[Element] es, ID n, ID r)
  = es
  + [state(src,exp,r)[@location = s@location] | s: state(src,exp,tgt) <- inState(es, n)]
  - inState(es, n);

//divert outState of n to r in es
public list[Element] divertOutState(list[Element] es, ID n, ID r)
  = es
  + [state(r,exp,tgt)[@location = s@location] | s: state(src,exp,tgt) <- outState(es, n)]
  - outState(es, n);

public list[Element] inFlow(list[Element] es, ID n)
  = [f | f: flow(_,_,tgt) <- es, tgt.name == n.name];
 
public list[Element] outFlow(list[Element] es, ID n)
  = [f | f: flow(src,_,_) <- es, src.name == n.name];
 
public list[Element] inState(list[Element] es, ID n)
  = [s | s: state(_,_,tgt) <- es, tgt.name == n.name];

public list[Element] outState(list[Element] es, ID n)
  = [s | s: state(src,_,_) <- es, src.name == n.name];


/*
//case delay = 0 --> no delay / gate
private Element desugarDelay(delay(When when, Act act, How how, ID name, list[Unit] opt_u, 0))
  = gate(when, act, how, name, opt_u);

//case delay = 1 --> pool
private Element desugarDelay(delay(When when, Act act, How how, ID name, list[Unit] opt_u, 1))
  = pool(when, act, how, name, opt_u);
*/

/*
//get a buffer id, used by buildbuffer
private list[ID] getBufferId(list[ID] n, int cur)
{
  ID suffix = last(n);
  ID suffix_new = id("$buf_<suffix.name>_<i>")[@location = suffix@location];
  return prefix(n) + [suffix_new];
}

//build a buffer of length n steps
private Element buildBuffer (list[Element] elements, Element prev, Element last, Exp e, int cur, int len)
{
  if(cur < len)
  {
    ID name = getBufferId(last,cur);
    
    //create a new buffer element that automatically pulls all resources
    Element buf  = pool(when_auto(), act_pull(), last.how, name, [], at_none(), add_none(), min_none(), max_none());

    //create a flow between the previous element and this one
    Element flow = flow(prev.name,e,name);
    
    //the buffer element must be zero to enable the first buffer element to pull 
    Element cond = state (name, e_gt(e_val(0,[])), getBufferId(last,1));
    
    return buildBuffer(elements+[buf,flow,cond], buf, last, e, cur+1, len);
  }
  else
  {
    return block(elements + flow(prev.name,e,last.name));
  }
}
*/
/*
public Element desugarElement(s:source(when, act, how, name, us)) =
  pool(when, act_push(), how, name, opt_u, [e_val(MAX_INT,[])])[@location=s@location];
  
public Element desugarElement(s:drain())=
  pool(when, act_pull(), how, name, opt_u,[e_val(0,[])])[location = s@location]; 
*/
     //sources are pools that
      //1. always push (pull is not allowed)
      //2. have an infinite amount of resources that we cannot refer to
      //3. minimum max_int, maximum max_int: any flow from here will work and what flows here is useless
      //drains are pools that
      //1. always pull (push is not allowed)
      //2. have an unspecified amount of resources that we cannot refer to
      //3. minimum zero, maximum zero: what flows here is destroyed
 