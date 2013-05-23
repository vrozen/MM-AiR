module lang::machinations::Trace

import lang::machinations::AST;
import lang::machinations::Preprocessor;
import lang::machinations::State;
import lang::machinations::Message;
//import lang::machinations::Generator;
import lang::machinations::Evaluator;
import lang::machinations::Serialize;

import List;
import IO;

public Trace mm_trace_transform (t: trace(list[Event] events))
{
  list[Step] steps = [];
  list[Event] step_events = [];
  for(Event event <- events)
  {
    if(tr_next() == event)
    {
      steps += tr_step(step_events)[@location = event@location];
      step_events = [];
    }
    else
    {
      step_events += event;
    }
  }
  if(events != [])
  {
    steps += tr_step(step_events)[@location = head(events)@location];
  }  
  return trace(steps)[@location = t@location];
}

//requires a labeled trace
public tuple[list[tuple[State,Transition]],list[Msg]] mm_play (Mach2 m2, trace(list[Step] steps))
{
  println("Playback of trace with length <size(steps)> started.\n");

  list[tuple[State,Transition]] trace = []; 
  list[Msg] msgs = [];
  State s = NEW_State(m2);
  TempState ts = NEW_TempState(m2);
  
  for(step: tr_step(list[Event] events) <- steps)
  {
    set[tuple[State, Transition]] successors = mm_generate_step(s, ts, m2);    

    Transition tr1 = [<src@l,f,tgt@l> | tr_flow(src,f,tgt) <- events];

    set[tuple[State, Transition]] matches =
      {<s2,tr2> | <s2, tr2> <- successors, toSet(tr1) == toSet(tr2)};

    //println("MATCHES <matches>");

    if({<s2,tr2>} := matches)
    {
      s = s2;
      trace += [<s2,tr2>];
      msgs = testAssertions(s,ts,m2);
      if(msgs != []){ break; }
    }
    else
    {
      list[Step] expected = [tr2step(m2, tr2) | <_,tr2> <- successors];
      msgs += [msg_SyncLost(step,
             "<toString(s,m2)><for(alt <- expected){>Expected Alternative<toString(alt)><}>\nFound Transition<toString(step)>")];
             
      if(size(expected) == 1) //only one step expected
      {
        Step expected_step = getOneFrom(expected);        
        set[Event] addEvents = {evt | evt: tr_flow(_,_,_) <- events, evt notin expected_step.events };
        
        set[Event] minEvents = {evt | evt: tr_flow(_,_,_) <- expected_step.events, evt notin events };
        
        for(Event evt <- addEvents)
        {
          msgs += [msg_SyncLost(step,"Missing Rascal event: <toString(evt)>")];
        }
        for(Event evt <- minEvents)
        {
          msgs += [msg_SyncLost(step,"Missing Promela event: <toString(evt)>")];
        }
               
        
      }
      break;
    }
  }
  
  return <trace, msgs>;
}

public Step tr2step(Mach2 m2, Transition tr)
  = tr_step
  (
    [
      tr_flow(getElement(m2,src).name,f,getElement(m2,tgt).name) | <src,f,tgt> <- tr
    ]
  );
  
public Transition step2tr(Step s)
  = [<src@l, f, tgt@l> | tr_flow(src, f, tgt) <- s.events];

//public list[Transition] steps2transitions (trace(list[Step] steps))
//  = [ step2tr(step) | step <- steps ];