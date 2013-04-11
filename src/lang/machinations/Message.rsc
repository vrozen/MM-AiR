@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Message
* @package      lang::machinations
* @file         Message.rsc
* @brief        Messages are pieces of data produced by tranformation phases.
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Message

import lang::machinations::AST;
import lang::machinations::Serialize;
import lang::machinations::State;
import Message;

data Msg
  = msg_MissingElement(ID id)
  | msg_MissingType(ID id)
  | msg_AmbiguousAlias(ID c, ID ref, list[Element] inFlow)
  | msg_InstancedAlias(ID c, ID ref, ID instance)
  | msg_MissingAlias(ID c, ID ref)
  | msg_AssertionViolated(State s, Element e)
  ;

public str toString(list[Msg] msgs)
  = "<for(msg <- msgs){><toString(msg)>\n<}>";

public str toString(msg_MissingElement(ID id))
  = "Missing element <id.name> at <id@location>"; //at line <id@location.begin.line> column <id@location.begin.column+1>;

public str toString(msg_MissingType(ID id))
  = "Missing type <id.name> <id@location>";

public str toString(msg_InstancedAlias(ID c, ID ref, ID instance))
  = "Instanced alias <ref.name> in <c.name> at <instance@location>";

public str toString(msg_AmbiguousAlias(ID c, ID ref, list[Element] inflow))
  = "Ambiguous alias <ref.name> in component <c.name> to [<for(e <- inflow){> <e.s.name> <}>] at <ref@location>";

public str toString(msg_MissingAlias(ID c, ID ref))
  = "Missing alias <ref.name> in component <c.name> at <ref@location>";
  
public str toString(msg_AssertionViolated(State s, Element e))
  = "Assertion <toString(e.name)> violated <toString(e.exp)> : <e.msg>\n";

public set[Message] getErrors(list[Msg] messages)
  = {error(toString(m),getLocation(m)) | m <- messages};