@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Labeler
* @package      lang::machinations
* @file         Labeler.rsc
* @brief        Defines labeling of ASTs.
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Labeler

import lang::machinations::AST;
import lang::machinations::Message;

//note: requires a labeled machinations model
public tuple[Trace, list[Msg]] mm_label (Machinations m, Trace trace)
{
  list[Msg] msgs = [];   //messages
  map[ID, int] n2l = (); //name to label map

  //1. build name to label map
  visit(m)
  {
    case ID n:
    {
      n2l += (n : n@l);
    }
  };
  
  //2. annotate trace with labels
  Trace trace2 = visit(trace)
  {
    case ID id:
    {
      if(id in n2l)
      {
        insert id[@l = n2l[id]];
      }
      //else
      //{
      //  msgs += [msg_MissingElement(id)];
      //}
    }
  };
  
  return <trace2, msgs>;
}

public tuple[Machinations,list[Msg]] mm_label (Machinations m)
{
  list[Msg] msgs = [];  //messages
  map[ID,int] n2l = (); //name to label map
  int l = 0;            //current label
  
  //First label pools
  //Note: the labels become addresses for value storage.
  Machinations m2 = visit(m)
  {
    case Element e:
    {
      if(isPool(e) == true)
      {
        Element e2 = e[@l = l];
        n2l += (e.name: l);
        l = l + 1;
        //l2e += (l: e2);
        insert e2;
      }
    }
  };
  
  //Then label all other elements
  Machinations m3 = visit(m2)
  {
    case Element e:
    {
      if(isPool(e) == false)
      {
        Element e2 = e[@l = l];
        //l2e += (l: e2);
        if(e.name?)
        {
          n2l += (e.name: l);
        }
        l = l + 1;
        insert e2;
      }
    }
  };
  
  //Finally label ID's
  Machinations m4 = visit(m3)
  {
    case ID id:
    {
      if(id in n2l)
      {
        insert id[@l = n2l[id]];
      }
      else
      {
        msgs += [msg_MissingElement(id)];
      }
    }
  };
  
  return <m4,msgs>;
}
