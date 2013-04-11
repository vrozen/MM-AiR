@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Serialization
* @package      lang::machinations
* @file         Serialize.rsc
* @brief        Defines the Micro-Machinations serialization.
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Serialize

import lang::machinations::AST;
import List;
import IO;
import String;
import util::Math;

public str toString(Machinations m)
  = "<for(e <- m.elements){><toString(e)><}>";

public str toString(component(ID t, ID name))
  = "<toString(t)> <toString(name)>\n";
 
public str toString(del(ID name))
  = "delete <toString(name)>\n";

public str toString(unit(ID name, str msg))
  = "unit <toString(name)> : <msg>"; 

public str toString(ct: ctype(ID name, list[Param] params, list[Element] elements))
  = "<toString(name)> (<for(p <- params){><toString(p)><}>)\n{\n<for(e <- elements){><toString(e)><}>}\n";

public str toString(pool (When when, Act act, How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
  = "<toString(when,act,how)>pool <toString(name)><if(units != []){> of <toString(units)><}><if(toString(at) != ""){> <toString(at)><}><if(toString(add)!=""){> <toString(add)><}><if(toString(min)!=""){> <toString(min)><}><if(toString(max)!=""){> <toString(max)><}>\n";

public str toString(gate(When when, Act act, How how, ID name, list[Unit] opt_u))
 = "<toString(when,act,how)>gate <toString(name)><if(opt_u != []){> of <toString(opt_u)><}>\n";
  
public str toString(source (When when, Act act, How how, ID name, list[Unit] opt_u))
  = "<toString(when,act,how)>source <toString(name)><if(opt_u != []){> of <toString(opt_u)><}>\n";
  
public str toString(drain (When when, Act act, How how, ID name, list[Unit] opt_u))
  = "<toString(when,act,how)>drain <toString(name)><if(opt_u != []){> of <toString(opt_u)><}>\n";
  
public str toString(converter (When when, Act act, How how, ID name, list[Unit] opt_src_u, list[Unit] opt_tgt_u))
 = "<toString(when,act,how)>converter <toString(name)> <if(opt_src_u != []){> from <toString(opt_src_u)><}> <if(opt_tgt_u != []){>to <toString(opt_tgt_u)><}>\n";

public str toString(delay(When when, Act act, How how, ID name, list[Unit] opt_u, int val))
 = "<toString(when,act,how)>delay <toString(name)> <if(opt_u !=[]){>of <toString(opt_u)><}> by <toInt(val)>\n";

public str toString(block (list[Element] elements))
 = "<for(e<-elements){><toString(e)><}>";

public str toString(When when, Act act, How how)
  = "<if(toString(when) != ""){><toString(when)> <}><if(toString(act) != ""){><toString(act)> <}><if(toString(how) != ""){><toString(how)> <}>";

public str toString(f: flow(list[ID] src, Exp exp, list[ID] tgt))
  = "<toString(src)> -<toString(exp)>-\> <toString(tgt)>\n";

public str toString(s: state(list[ID] src, Exp exp, list[ID] tgt))
  = "<toString(src)> .<toString(exp)>.\> <toString(tgt)>\n";

public str toString(f: flow(ID src, Exp exp, ID tgt))
  = "<toString(src)> -<toString(exp)>-\> <toString(tgt)>\n";

public str toString(s: state(ID src, Exp exp, ID tgt))
  = "<toString(src)> .<toString(exp)>.\> <toString(tgt)>\n";

public str toString(always(ID name, Exp e, str msg))
  = "assert <toString(name)> <toString(e)> <msg>\n";

public str toString(param(IO io, bool ref, ID name))
 = "<toString(io)> <toString(name)>";

public str toString(io_ref())
  = "ref";

public str toString(io_in())
  = "in";

public str toString(io_out())
  = "out";

public str toString(io_inout())
  = "inout";

public str toString(when_passive())
  = "";
  
public str toString(when_user())
  = "user";
  
public str toString(when_auto())
  = "auto";
  
public str toString(when_start())
  = "start";

public str toString(act_pull())
  = "";
  
public str toString(act_push())
  = "push";
  
public str toString(how_any())
  = "";
  
public str toString(how_all())
  = "all";

public str toString(at_none())
 = "";

public str toString(at_val(0))
  = "";

public str toString(at_val(int v))
  = "at <v>";

public str toString(min_none())
  = "";

public str toString(min_val(int v))
  = "min <v>";

public str toString(add_none())
  = "";
  
public str toString(add_exp(Exp e))
  =  "add <toString(e)>";

public str toString(max_none())
  = "";
  
public str toString(max_val(int v))
  = "max <v>";

public str toString(list[ID] name)
  = "<while(name != []){ <n, name> = headTail(name);><toString(n)><if(name!=[]){>.<}><}>";

public str toString(ID id)
  = id.name;

public str toString(list[Unit] units)
  = "<for(u <- units){><toString(u)><}>";

public str toString(u_name(ID name))
  = toString(name);

public str toString(u_override(Unit u))
  = "(<toString(u)>)";

public str toString(u_div(Unit u1, Unit u2))
  = "<toString(u1)> / <toString(u2)>";
  
public str toString(u_mul(Unit u1, Unit u2))
  = "<toString(u1)> * <toString(u2)>";

public str toString(e_trigger())
  = "*";
  
public str toString(e_ref())
  = "=";

public str toString(e_range(int low, int high))
  = "<low>..<high>";

public str toString(e_one())
  = "";
 
public str toString(e_percent(Exp e))
  = "<toString(e)> %";

public str toString(e_unm(Exp e))
  = "-<toString(e)>";

public str toString(e_val(real v, list[Unit] opt_u))
{
  if(endsWith("<v>","."))
  {
    return "<toInt(v)>";
  }
  else
  {
    return "<v>";
  }
}

public str toString(e_all())
  = "all";
 
public str toString(e_override(Exp e))
  = "( <toString(e)> )";

public str toString(e_name(list[ID] names))
  = toString(names);

public str toString(e_name(ID name))
  = toString(name);
  
public str toString(e_active(list[ID] names))
  = "active <toString(names)>";

public str toString(e_active(ID name))
  = "active <toString(name)>";

public str toString(e_true())
  = "true";

public str toString(e_false())
  = "false";

public str toString(e_lt(Exp e1, Exp e2))
  = "<toString(e1)> \< <toString(e2)>";
  
public str toString(e_gt(Exp e1, Exp e2))
  = "<toString(e1)> \> <toString(e2)>";
  
public str toString(e_le(Exp e1, Exp e2))
  = "<toString(e1)> \<= <toString(e2)>";
  
public str toString(e_ge(Exp e1, Exp e2))
  = "<toString(e1)> \>= <toString(e2)>";
  
public str toString(e_neq(Exp e1, Exp e2))
  = "<toString(e1)> != <toString(e2)>";

public str toString(e_eq(Exp e1, Exp e2))
  = "<toString(e1)> == <toString(e2)>";

public str toString(e_and(Exp e1, Exp e2))
  = "<toString(e1)> && <toString(e2)>";
  
public str toString(e_or(Exp e1, Exp e2))
  = "<toString(e1)> || <toString(e2)>";

public str toString(e_not(Exp e))
  = "! <toString(e)>";

public str toString(e_mul(Exp e1, Exp e2))
  = "<toString(e1)> * <toString(e2)>";

public str toString(e_div(Exp e1, Exp e2))
  = "<toString(e1)> / <toString(e2)>";

public str toString(e_add(Exp e1, Exp e2))
  = "<toString(e1)> + <toString(e2)>";

public str toString(e_sub(Exp e1, Exp e2))
  = "<toString(e1)> - <toString(e2)>";

public str toString(e)
{
  throw "not supported <e>";
}