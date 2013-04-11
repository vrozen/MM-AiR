module lang::machinations::Instantiator

import IO;
import List;
import lang::machinations::AST;
import lang::machinations::Serialize;
import lang::machinations::Message;
import lang::machinations::Desugar;

//flattens a machinations model
public tuple[Machinations,list[Msg]] machinations_flatten(Machinations m)
{
  map[str, Element] types = (n.name: t | t: ctype (n, _, _ ) <- m.elements);
  <es, msgs> = flatten(id("global scope")[@location = m@location], "", types, m.elements);
  return <mach(es), msgs>;  
}
 
//flattens a list of machinations elements with a name space prefix
private tuple[list[Element],list[Msg]] flatten
(
  ID cId,
  str flatPre,
  map[str, Element] types,
  list[Element] elements
)
{
  list[Element] s_elements = [];
  list[Msg] msgs = [];
  list[ID] refs = [];
  
  for(Element e <- elements)
  {
    switch(e)
    {
      case component (ID t, ID name):
      {
        if(t.name in types)
        {
          Element ct = types[t.name];          
          refs += [flatten(getFlatName(flatPre,name), p_name) | param(io_ref(), ID p_name) <- ct.params];
          <es2, msgs2> = flatten(name, getFlatName(flatPre,name), types, ct.elements);
          s_elements += es2;
          msgs += msgs2;
        }
        else
        {
          msgs += [msg_missingType(t)];
        }
      }
      case del(ID name):
      {
        s_elements += del(flatten(flatPre,name))[@location = e@location];
      }
      case ctype (ID name, list[Param] params, list[Element] elements):
      {
        ; //filter outID
      }
      case flow (list[ID] src, Exp exp, list[ID] tgt):
      {
        s_elements += flow(flatten(flatPre, src), flatten(flatPre, exp), flatten(flatPre, tgt))[@location = e@location];
      }
      case state (list[ID] src, Exp exp, list[ID] tgt):
      {
        s_elements += state(flatten(flatPre, src), flatten(flatPre, exp), flatten(flatPre, tgt))[@location = e@location];
      }
      default:
      {
        if(e.add? &&
           e.add.exp?) //for pools
        {
          e.add.exp = flatten(flatPre, e.add.exp);
        }
        if(e.name?) //name must be ID or list[ID] (the case in named elements)
        {
          e.name = flatten(flatPre, e.name);
        }
        if(e.s?) //s must be ID (the case in flow and state)
        {
          e.s = flatten(flatPre, e.s);        
        }
        if(e.t?) //t must be ID (the case in flow and state)
        {
          e.t = flatten(flatPre, e.t);        
        }
        if(e.exp?) //exp must be Exp (otherwise expressions are not flattened!)
        {
          e.exp = flatten(flatPre, e.exp);
        }
        s_elements += e;
      }
    }
  }
  
  //replace references by the source of the flow targeting them
  //where only one flow may target the reference to prevent ambiguity  
  //additionally, remove the flow Element that indicated the alias
  
  for(ID ref <- refs)
  {
    list[Element] resolve = [e | e: state(_,e_ref(),_) <- inState(s_elements, ref)];
    
    if(resolve == [])
    {
      msgs += msg_MissingAlias(cId, ref);
    }
    else if([state(src,exp,tgt)] := resolve)
    {
      //extra check to prevent duplicate nodes
      for(e <- s_elements)
      {
        if(e.name? && e.name == tgt)
        {
          msgs += [msg_InstancedAlias(cId, ref, e.name)];
        }
      }
      //patch references
      s_elements = visit(s_elements - resolve)
      {
        case tgt:
        {
          //println("Reference <ref.name> replaced by <src.name>"); 
          insert src;
        }
      }
    }
    else
    {
      msgs += msg_AmbiguousAlias(cId, ref, resolve);
    }
  }
  
  return <s_elements, msgs>;
}

private ID flatten(str flatPre, list[ID] name)
  = id(getFlatName(flatPre, name))[@location = head(name)@location];

private ID flatten(str flatPre, ID name)
  = id(getFlatName(flatPre, name))[@location = name@location];

private Exp flatten(str flatPre, Exp e)
{
  return visit(e)
  {
    case e_n: e_name(list[ID] names):
    {
      insert e_name
      (
        id
        (
          getFlatName(flatPre, names)
        )[@location = head(names)@location]
      )[@location = e_n@location];
    }
    case e_a: e_active(list[ID] names):
    {
      insert e_active
      (
        id
        (
          getFlatName(flatPre, names)
        )[@location = head(names)@location]
      )[@location = e_a@location];
    }
  }
}

//flattens a name with a prefix
private str getFlatName("", ID name)
  = toString(name);

private str getFlatName(str flatPre, ID name)
  = "<flatPre>_<toString(name)>";

private str getFlatName(str flatPre, list[ID] name)
  = "<if(flatPre!=""){><flatPre>_<}><while(name != []){ <n, name> = headTail(name);><toString(n)><if(name!=[]){>_<}><}>";