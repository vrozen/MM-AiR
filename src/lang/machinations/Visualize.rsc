@license{
  Copyright (c) 2009-2013 CWI / HvA
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
/*****************************************************************************/
/*!
* Micro-Machinations Visualization
* @package      lang::machinations
* @file         Visualize.rsc
* @brief        Defines the Micro-Machinations visualization
* @contributor  Riemer van Rozen - rozen@cwi.nl - HvA, CREATE-IT / CWI
* @date         April 11th 2013
* @note         Compiler/Assembler: Rascal MPL.
*/
/*****************************************************************************/
module lang::machinations::Visualize

import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Message;
import lang::machinations::Desugar;
import lang::machinations::Instantiator;
import lang::machinations::Preprocessor;
import lang::machinations::Labeler;
import lang::machinations::Serialize;
import lang::machinations::Evaluator;
import lang::machinations::Generator;

import vis::Figure;
import vis::Render;
import IO;
import ParseTree;
import util::Math;
import List;
import Set;

//------------------------------------------------------------------------------
//Visual Constants
//------------------------------------------------------------------------------
private int NODE_HSIZE = 50;
private int NODE_VSIZE = 50;
private int ARROW_HSIZE = 10;
private int ARROW_VSIZE = 10;
private int NAME_FONTSIZE = 16;
private int MODIFIER_FONTSIZE = 20;
private int AMOUNT_FONTSIZE = 20;
private int LINE_WIDTH = 2;

private int MAX_DEPTH = 200;
private int MAX_DELAY = 10000;
private int MAX_ZOOM = 200;
private int MAX_GAP_SIZE = 100;

private int MIN_DEPTH = 0;
private int MIN_DELAY = 500;
private int MIN_ZOOM = 50;
private int MIN_GAP_SIZE = 20;

private int DEFAULT_MAX_DEPTH = 40;
private int DEFAULT_DELAY = 500;
private int DEFAULT_ZOOM = 100;
private int DEFAULT_GAP_SIZE = 40;

private bool DEFAULT_SHOW_NAMES = false;

private str HAS_UNHAPPENED_COLOR = "red";
private str HAS_HAPPENED_COLOR = "green";
private str WILL_HAPPEN_COLOR = "orange";
private str IS_HAPPENING_COLOR = "silver";

private str INTERACTIVE_MODE = "Interactive Simulation";
private str RANDOM_MODE = "Random Simulation";
private str EXPLORE_MODE = "Explore State Space";
private str GUIDED_MODE = "Guided Simulation";

//------------------------------------------------------------------------------
//External API: mm_visualize
//------------------------------------------------------------------------------

public void mm_visualize(Mach2 m2)
{
  list[Msg] msgs = [];
  
  //----------------------------------------------------------------------------
  //Locals used in the visualization.
  //----------------------------------------------------------------------------  
  int zoom = DEFAULT_ZOOM;
  int gapSize = DEFAULT_GAP_SIZE;
  int maxDepth = DEFAULT_MAX_DEPTH;
  int delay = DEFAULT_DELAY;
  bool showNames = DEFAULT_SHOW_NAMES;
  str transitionColor = WILL_HAPPEN_COLOR;

  //state information
  State s = NEW_State(m2);
  TempState ts = NEW_TempState(m2);
  list[tuple[State s, Transition tr]] successors
    = toList(generate_step(s, ts, m2));
  list[tuple[State s, Transition tr]] trace = [];
  int selected = 0;
  Transition tr = successors[0].tr;
  list[list[tuple[State s, Transition tr]]] violations = [];
  int selectedViolation = -1;
    
  set[State] ss = {};
  list[list[tuple[State,Transition]]] workStack = [];
  list[tuple[State,Transition]] work = [];

  str mode = INTERACTIVE_MODE;
  bool newModus = true;
  bool newGraph = true;
  bool pause = true;
  
  str log = "";
  
  //----------------------------------------------------------------------------
  //Declare Model Transformations
  //----------------------------------------------------------------------------     
  private void previous ()
  {
    //select the previous transition (if any) and display it
    if(selected > 0)
    {
      selected -= 1;
    }
    else //go to the last transition if allready at the first choice    
    {
      selected = size(successors) - 1;
    }
    transitionColor = WILL_HAPPEN_COLOR;    
    tr = successors[selected].tr;
    newGraph = true;
  }

  private void next ()
  {
    //select the next transition (if any) and display it
    if(selected < size(successors) - 1)
    {
      selected += 1;
    }
    else //go to the first transition if allready at the last choice
    {
      selected = 0;
    }
    transitionColor = WILL_HAPPEN_COLOR;
    tr = successors[selected].tr;   
    newGraph = true;
  }
  
  private void step ()
  {
    //1. add the selected state and transition to the trace
    trace = push(<s,tr>, trace);
    <s, tr> = successors[selected];
    selected = 0;

    msgs = testAssertions(s,ts,m2);
    log = toString(msgs);

    //2. perform the currently selected transition (select corresponding state)
    transitionColor = HAS_HAPPENED_COLOR;

    //3. calculate the successors of the current state
    if(mode == GUIDED_MODE)
    {
      //get the correct successor state for this depth
      successors = [violations[selectedViolation][size(trace)]];
    }
    else
    {
      successors = toList(generate_step(s, ts, m2));
    }
    newGraph = true;
  }
 
  private void stepBack ()
  {
    if(trace != [])
    {
      //1. set the state to be the previous state    
      <<s, tr>, trace> = pop(trace);
      
      msgs = testAssertions(s,ts,m2);
      log = toString(msgs);
      
      
      //2. display the undone transition in RED  
      transitionColor = HAS_UNHAPPENED_COLOR;
  
      //3. calculate the successors of the current state     
      successors = toList(generate_step(s, ts, m2));
      newGraph = true;
    }
  }
  
  private void previousViolation ()
  {
    //select the previous transition (if any) and display it
    if(size(violations) > 0)
    {
      if(selectedViolation > 0)
      {
        selectedViolation -= 1;
      }
      {
        selectedViolation = size(violations) - 1;
      }
      transitionColor = WILL_HAPPEN_COLOR;
      //TODO: select the violation
      newGraph = true;
    }
  }
  
  private void nextViolation ()
  {
    if(size(violations) > 0)
    {
      if(selectedViolation < size(violations) - 1)
      {
        selectedViolation += 1;
      }
      else
      {
        selectedViolation = 0;
      }
      transitionColor = WILL_HAPPEN_COLOR;
    
      //TODO: select the violation    
      newGraph = true;
    }
  }
 
  
  private void automaticStep()
  {
    switch(mode)
    {
      case EXPLORE_MODE:
      {
        explore_step(); 
      }
      case RANDOM_MODE:
      {
        selected = getOneFrom([0 .. size(successors)]);  
        step();
      }      
      case GUIDED_MODE:
      {
        selected = 0;
        step();
      }
    }
  }
    
  private void timedAutomaticStep()
  {
    if(pause == false)
    {
      automaticStep();
    }
  }
  
  //----------------------------------------------------------------------------
  //Declare Model Transformation (Model Check)
  //----------------------------------------------------------------------------
  private void explore()
  {   
    s = NEW_State(m2);
    ss = {};
    msgs = [];
    workStack = [[<s,[]>]];
    work = [];
    pause = false;
    delay = 10;
    trace = [];
    violations = [];
    transitionColor = HAS_HAPPENED_COLOR;
  }

  private void explore_step()
  {
    if(pause == false && workStack != [])
    {
      work = head(workStack);
      
      if(work == [])
      {
        //println("Out of work at depth <size(workStack)>");
        workStack = tail(workStack);
        return;
      }
      <<s,tr>, work> = pop(work);
    
      if(s in ss)
      {
        if(work == [])
        {
          //println("Out of work at depth <size(workStack)>");
          workStack = tail(workStack);
        }
        else
        {
          workStack[0] = work;
        }
        return;
      }
    
      //printState(curState, m2);
      ss += s;
        
      //println("Test assertions");
      list[Msg] curMsgs = testAssertions(s,ts,m2);    
      if(curMsgs != [])
      {
        msgs += curMsgs;
        log = toString(curMsgs) + toString(s,m2);
        
        //traverse the workstack
        //violations += [reverse(trace)];
        
        return;
      }
      
      if(size(workStack) < maxDepth)
      {
        //println("\nGo in depth");
        list[tuple[State,Transition]] sucs = toList(generate_step(s,ts,m2));
        workStack = [sucs, work] + tail(workStack);
        //trace += push(<s,ts>, trace);
      }
      else
      {
        //println("\nAt max depth");
        workStack[0] = work;
      }

      newGraph = true;
    }
    
    if(workStack == [] && pause == false)
    {
      pause = true;
      trace = [];
      delay = 500;
    }
  }
  
  //----------------------------------------------------------------------------
  //Declare Model Transformation (Reset)
  //----------------------------------------------------------------------------
  private void reset()
  {
    pause = true;
    selected = 0;                
    trace = [];
    s = NEW_State(m2);   
    successors = toList(generate_step(s, ts, m2));
    tr = successors[0].tr;
    newGraph = true;
    transitionColor = WILL_HAPPEN_COLOR;
  }

  //----------------------------------------------------------------------------
  //Declare Timer for Automatic Steps (might be simulation or generation)
  //---------------------------------------------------------------------------- 
  private TimerAction autoTimer(stopped(n))
  = restart(delay);

  private TimerAction autoTimer(_)
  = noChange();

  //----------------------------------------------------------------------------
  //Declare Generative Controls
  //Note: top controls are regenerated to avoid rendering artifacts.
  //---------------------------------------------------------------------------- 
  private Figure controls()
  {
    Figure lower;
    switch(mode)
    {
      case INTERACTIVE_MODE: lower = interactiveControls();
      case EXPLORE_MODE: lower = exploreControls();
      case RANDOM_MODE: lower = automaticControls(RANDOM_MODE);
      case GUIDED_MODE: lower = automaticControls(GUIDED_MODE);
      default: lower = box(text("missing controls"));
    };    
    return vcat
    (
      [
        generalControls(),
        lower
      ],
      top(),
      halign(0.5),
      hshrink(0.9)
    );
  }

  //----------------------------------------------------------------------------
  //Declare General Controls
  //---------------------------------------------------------------------------- 
  private Figure generalControls()
  = vcat
    (
      [
        text
        (
          "Micro Machinations",
          fontSize(14),
          fontBold(true)
        ),
        text
        (
          str(){ return mode; },
          fontBold(true),
          fontSize(14)
        ),
        button
        (
          INTERACTIVE_MODE,
          void(){ mode = INTERACTIVE_MODE; newModus = true; }
        ),
        button
        (
          RANDOM_MODE,
          void(){ mode = RANDOM_MODE; newModus = true; pause = true; }
        ),
        button
        (
          GUIDED_MODE,
          void(){ mode = GUIDED_MODE; newModus = true; }
        ),
        button
        (
          EXPLORE_MODE,
          void(){ mode = EXPLORE_MODE; newModus = true; }
        ),
        text
        (
          "Graph Options",
          fontBold(true),
          height(40)
        ),
        grid
        (
          [
            [
              text
              (
                str () { return "zoom: <zoom>"; },
                left()
              ),
              scaleSlider
              (
                int () { return MIN_ZOOM; },
                int () { return MAX_ZOOM; },
                int () { return zoom; },
                void (int curZoom) { zoom = curZoom; newGraph = true;},
                left()
              )
            ],
            [
              text
              (
                str () { return "gap size: <gapSize>"; },
                left()
              ),
              scaleSlider
              (
                int () { return MIN_GAP_SIZE; },
                int () { return MAX_GAP_SIZE; },
                int () { return gapSize; },
                void (int curGapSize) { gapSize = curGapSize; newGraph = true;},
                left()
              )
            ],
            [
              checkbox
              (
                "names",
                true,
                void(bool showNamesState){ showNames = showNamesState; newGraph = true; }
               )
            ]
          ]          
        ),
        text
        (
          "Status",
          fontBold(true),
          height(40)
        ),
        grid
        (
          [
            [
              text
              (
                "status ",
                left()
              ),
              text
              (
                str ()
                {
                  return "<if(pause){>paused<} else {>running<}>";
                },
                left()
              )
            ],
            [
              text("trace depth:", left()),
              text
              (
                str () { return "<size(trace)>"; },
                left()
              )          
            ],
            [
              text("transition selected:", left()),
              text
              (
                str () { return "<selected + 1> / <size(successors)>"; },
                left()
              )
            ],
            [
              text("violations:", left()),
              text
              (
                str () { return "<size(msgs)>"; },
                left()                
              )
            ],
            [
              text("violation selected:", left()),
              text
              (
                str () { return "<selectedViolation + 1> / <size(violations)>"; },
                left()
              )
            ]
          ]
        )
      ],
      top(),     
      vshrink(0.7)
    );

  //----------------------------------------------------------------------------
  //Declare Interactive Controls
  //----------------------------------------------------------------------------  
  private Figure interactiveControls()
  = vcat
    (
      [
        text
        (
          "Interactive Controls",
          fontBold(true),
          height(40)
        ),
        hcat
        (
          [
            button
            (
              "Back",
              void() { stepBack(); }
            ),
            button
            (
              "Step",
              void() { step(); }
            )
          ]
        ),
        hcat
        (
          [
            button
            (
              "Previous",
              void() { previous(); }
            ),
            button
            (
              "Next",
              void() { next(); }
            )
          ]
        ),
        button
        (
          "Reset",
          void() { reset(); }
        )        
      ],
      top(),     
      vshrink(0.3)
    );
    
 
  //----------------------------------------------------------------------------
  //Declare Interactive Controls
  //----------------------------------------------------------------------------  
  private Figure exploreControls()
  = vcat
    (
      [
        text
        (
          "Exploration Controls",
          fontBold(true),
          height(40)
        ),
        grid
        (
          [
            [
              text
              (
                str () { return "max depth: <maxDepth>"; }
              ),
              scaleSlider
              (
                int () { return MIN_DEPTH; },
                int () { return MAX_DEPTH; },
                int () { return maxDepth; },
                void (int curMaxDepth) { maxDepth = curMaxDepth; }
              )
            ],
            [
              text
              (
                "state space:"
              ),
              text
              (
                str () { return "<size(ss)>"; }
              )                        
            ],
            [
              text
              (
                "work amount"
              ),
              text
              (
                str(){ return "<size(work)>"; }
              )
            ],
            [
              button
              (
                "Explore",
                void(){ explore(); }          
              ),
              button
              (
                "Pause",
                void(){if(pause){pause = false;} else { pause = true; }}
              )
            ],
            [
              button
              (
                "Previous",
                void(){ previousViolation(); }
              ),
              button
              (
                "Next",
                void(){ nextViolation(); }
              )
            ]
          ]
        )
      ],
      top(),     
      vshrink(0.3)
    );

  //----------------------------------------------------------------------------
  //Declare Automatic Controls
  //----------------------------------------------------------------------------
  private Figure automaticControls(str controlsName)
  = vcat
    (
      [
        text
        (
          controlsName,
          fontBold(true),
          height(40)
        ),
        grid
        (
          [
            [
              text
              (
                str () { return "delay (ms):\n<delay>"; }
              ),
              scaleSlider
              (
                int () { return MIN_DELAY; },
                int () { return MAX_DELAY; },
                int () { return delay; },
                void (int curDelay) { delay = curDelay; }
              )
            ]
          ]
        ),
        button
        (
          "Start / Pause",
          void(){if(pause){pause = false;} else { pause = true; }}
        ),
        hcat
        (
          [
            button
            (
              "Back",
              void() { stepBack(); }
            ),
            button
            (
              "Step",
              void() { automaticStep(); }
            )
          ]
        ),
        button
        (
          "Reset",
          void(){ reset(); }
        )
      ],
      top(),     
      vshrink(0.3)
    );
  
  //----------------------------------------------------------------------------
  //Render Controls
  //----------------------------------------------------------------------------
  render
  (
    hcat
    (
      [
        vcat
        (
          [
            scrollable
            (
              computeFigure
              (
                bool(){ if(newGraph == true){ newGraph = false; return true; } else { return false; } },
                Figure ()
                {
                  return toGraph(s,ts,tr,m2,transitionColor,toReal(zoom)/100.0, gapSize, showNames);
                },
                top()
              ),
              vshrink(0.85)
            ),
            scrollable
            (
              text
              (
                str(){ return log; },
                fontSize(18),
                fontColor(color("red"))
              ),
              vshrink(0.15)
            )
          ],
          hshrink(0.80)    
        ),
        box
        (
          computeFigure
          (
            bool(){ if(newModus == true){ newModus = false; return true; } else { return false; } },
            Figure(){ return controls(); },
            top()
          ),
          hshrink(0.20)
        )
      ],
      timer(autoTimer, timedAutomaticStep)
    )
  );
}

private Figure toGraph(State s, TempState ts, Transition t, Mach2 m2,
  str transitionColor, real zoom, int gapSize, bool showNames)
{
  Figures ns = []; //nodes
  Edges es = []; //edges
  
  for(Element e <- m2.m.elements)
  {
    if(isPool(e) || isGate(e) || isSource(e) || isDrain(e))
    {
      ns += nodeToFigure(s, ts, m2, e, zoom, transitionColor, showNames);
    }
    if(isFlow(e) || isState(e))
    {
      es += edgeToFigure(t, e, transitionColor);
    }
  }
  
  return graph (ns, es, hint("layered"), gap(toInt(gapSize * zoom)), vshrink(0.8));
}

//------------------------------------------------------------------------------
//Edge Figures
//------------------------------------------------------------------------------
private Edge edgeToFigure(Transition t,
  Element e: flow  (ID src, Exp exp, ID tgt), str transitionColor)
{
  int width = 1;
  str color = "black";
  
   
  if({<_,w,_>} := {<a, b, c> | <a,b,c> <- t, a == src@l && c == tgt@l})
  {
    width = w * 4;
    color = transitionColor;
  }
  
  return edge
  (
    src.name,
    tgt.name,
    toArrow
    (
      arrowHead("white")
    ),
    lineWidth(width),
    lineColor(color),
    mouseOver(text(toString(exp)))
  );
}

private Edge edgeToFigure(Transition t,
  Element e: state (ID src, Exp exp, ID tgt), str transitionColor)
= edge
  (
    src.name,
    tgt.name,
    toArrow
    (
      arrowHead("white")
    ),
    lineWidth(LINE_WIDTH),
    lineStyle("dash"),
    mouseOver(text(toString(exp)))
  );

//------------------------------------------------------------------------------
//Node Figures
//------------------------------------------------------------------------------
private Figure nodeToFigure(State s, TempState ts, Mach2 m2, Element e,
  real zoom, str transitionColor, bool showNames)
{
  str color = "white";
  Figure nameFigure = space();
  if(e@l in activeNodes(s, ts, m2))
  {
    color = IS_HAPPENING_COLOR;
  }
  
  if(showNames == true)
  {
    nameFigure =
    text
    (
      toString(e.name),
      fontSize(toInt(NAME_FONTSIZE * zoom)),
      valign(2.0)
    );
  }
  
  return overlay
  (
    [
      overlay
      (
        [
          nodeToSubFigure(s,ts,m2,zoom,color,e),
          text
          (
            //Hack: adequate alignment
            "            <toVisualString(e.when)><toVisualString(e.act)><toVisualString(e.how)>",
            fontSize(toInt(MODIFIER_FONTSIZE * zoom)),
            fontBold(true),
            align(1.0,0.0)
          )
        ]
      ),
      nameFigure
    ],
    vis::Figure::id(toString(e.name)),
    top(), //Hack: center the node vertically
    left() //Hack: center the node horizontally
  );
}
 
//------------------------------------------------------------------------------
//Node Sub-Figures
//------------------------------------------------------------------------------
private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: pool (When when, Act act, How how, ID name, list[Unit] units, At at, Add add, Min min, Max max))
{  
  Figures fs = [pool(1.0 * zoom, color)];

  if(when == when_user())
  {
    fs += [pool(0.8 * zoom, color)];
  }
  
  fs +=
  [
    text
    (
      "<state_retrieve(s, ts, m2, e@l)>", //\n<toString(min)> <toString(max)>",
      fontBold(true),
      fontSize(toInt(AMOUNT_FONTSIZE * zoom))
    )
  ];
  
  return overlay(fs);
}

private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: gate  (when_user(), Act act, How how, ID name, list[Unit] opt_u))
= overlay
  (
    [
      gate(1.0 * zoom, color),
      gate(0.7 * zoom, color)
    ]
  );
  
private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: gate  (When when, Act act, How how, ID name, list[Unit] opt_u))
= gate(1.0 * zoom, color);

private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: source (when_user(), Act act, How how, ID name, list[Unit] opt_u))
= overlay
  (
    [
      source(1.0 * zoom, color),
      source(0.7 * zoom, color)
    ]
  );

private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: source (When when, Act act, How how, ID name, list[Unit] opt_u))
= source(1.0 * zoom, color);

private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: drain (when_user(), Act act, How how, ID name, list[Unit] opt_u))
= overlay
  (
    [
      drain(1.0 * zoom, color),
      drain(0.7 * zoom, color)
    ]   
  );

private Figure nodeToSubFigure(State s, TempState ts, Mach2 m2, real zoom, str color,
  e: drain (When when, Act act, How how, ID name, list[Unit] opt_u))
= drain(1.0 * zoom, color);

//------------------------------------------------------------------------------
//Basic Visual Elements
//------------------------------------------------------------------------------
private Figure point(real x, real y)
= ellipse
  (
    align(x,y)
  );

private Figure pool(real scale, str color)
= ellipse
  (
    size(NODE_HSIZE * scale, NODE_VSIZE * scale),
    lineWidth(LINE_WIDTH),
    fillColor(color) 
  );

private Figure gate(real scale, str color)
= overlay
  (
    [point(x,y) | <x,y> <- [<0.5,0.0>,<1.0,0.5>,<0.5,1.0>,<0.0,0.5>,<0.5,0.0>]],           
    shapeConnected(true),
    shapeClosed(true),
    size(NODE_HSIZE * scale, NODE_VSIZE * scale),
    lineWidth(LINE_WIDTH),
    fillColor(color)
  );

private Figure source(real scale, str color)
= overlay
  (
    [point(x,y) | <x,y> <- [<0.5,0.0>,<1.0,1.0>,<0.0,1.0>]],           
    shapeConnected(true),
    shapeClosed(true),
    size(NODE_HSIZE * scale, NODE_VSIZE * scale * 0.8),
    lineWidth(LINE_WIDTH),
    fillColor(color) 
  );

private Figure drain(real scale, str color)
= overlay
  (
    [point(x,y) | <x,y> <- [<0.0,0.0>,<1.0,0.0>,<0.5,1.0>]],           
    shapeConnected(true),
    shapeClosed(true),
    size(NODE_HSIZE * scale, NODE_VSIZE * scale * 0.8),
    lineWidth(LINE_WIDTH),
    fillColor(color)   
  );
  
private Figure always(real scale, str color)
= overlay
  (
    [point(x,y) | <x,y> <- [<0.0,0.0>,<1.0,0.0>,<1.0,1.0>,<0.0,1.0>]],           
    shapeConnected(true),
    shapeClosed(true),
    size(NODE_HSIZE * scale, NODE_VSIZE * scale * 0.8),
    lineWidth(LINE_WIDTH),
    fillColor(color)   
  );

private Figure arrowHead(str color)
= headNormal
  (
    size(ARROW_HSIZE, ARROW_VSIZE),
    lineWidth(LINE_WIDTH),
    fillColor(color)
  );
       
//------------------------------------------------------------------------------
//Basic Textual Elements
//------------------------------------------------------------------------------
public str toVisualString(when_passive()) = "";
public str toVisualString(when_user())    = "";
public str toVisualString(when_auto())    = "*";
public str toVisualString(when_start())   = "s";
public str toVisualString(act_pull())     = "";
public str toVisualString(act_push())     = "p";
public str toVisualString(how_any())      = "";
public str toVisualString(how_all())      = "&";
