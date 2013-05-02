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
  //static errors
  = msg_MissingElement(ID id)
  | msg_MissingType(ID id)
  | msg_AmbiguousAlias(ID c, ID ref, list[Element] inFlow)
  | msg_InstancedAlias(ID c, ID ref, ID instance)
  | msg_MissingAlias(ID c, ID ref)
  | msg_DuplicateFlow(Element f1, Element f2)
  | msg_PushingGate(ID name)
  | msg_DrainHasOutflow(ID name, Element flow)
  | msg_SourceHasInflow(ID name, Element flow)
  | msg_TwiceUsedFlowEdge(Element flow)
  | msg_UnusedFlowEdge(Element flow)
  //runtime errors
  | msg_AssertionViolated(State s, Element e)  
  //transformation phase failures
  | msg_ParserFail(loc l, str err)
  | msg_ImploderFail(loc l, str err)
  | msg_DesugarFail(loc l, str err)
  | msg_LabelerFail(loc l, str err)
  | msg_FlattenerFail(loc l, str err)
  | msg_PreprocessorFail(loc l, str err)
  | msg_LimiterFail(loc l, str err)
  | msg_EvaluatorFail(loc l, str err)
  | msg_AssertionFail(loc l, str err)
  ;

public str toString(list[Msg] msgs)
  = "<for(msg <- msgs){><toString(msg)><}>";

public set[Message] getErrors(list[Msg] messages)
  = {error(toString(m),getLocation(m)) | m <- messages};

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
  
public str toString(msg_DuplicateFlow(Element f1, Element f2))
  = "Duplicate flow between nodes <f1.s.name> and <f1.t.name>\n";

public str toString(msg_PushingGate(ID name))
  = "Pushing gate <name.name>";
  
public str toString(msg_DrainHasOutflow(ID name, Element flow))
  = "Drain <name.name> has outflow";

public str toString(msg_SourceHasInflow(ID name, Element flow))
  = "Source <name.name> has inflow";
  
public str toString(msg_TwiceUsedFlowEdge(Element flow))
  = "Nodes <flow.s.name> and <flow.t.name> both operate on the same flow.";

public str toString(msg_UnusedFlowEdge(Element flow))
  = "Unused flow between <flow.s.name> and <flow.t.name>";
  
public str toString(msg_ParserFail(loc l, str err))
  = "Parser failure on <l>: <err>";
  
public str toString(msg_ImploderFail(loc l, str err))
  = "Imploder failure on <l>: <err>";

public str toString(msg_DesugarFail(loc l, str err))
  = "Desugar failure on <l>: <err>";

public str toString(msg_LabelerFail(loc l, str err))
  = "Labeler failure on <l>: <err>";

public str toString(msg_FlattenerFail(loc l, str err))
  = "Flattener failure on <l>: <err>";
  
public str toString(msg_EvaluatorFail(loc l, str err))
  = "Evaluator failure on <l>: <err>";

public str toString(msg_AssertionFail(loc l, str err))
  = "Assertion failure on <l>: <err>";

public str toString(msg_PreprocessorFail(loc l, str err))
  = "Preprocessor failure on <l>: <err>";

public str toString(msg_LimiterFail(loc l, str err))
  = "Limiter failure on <l>: <err>";