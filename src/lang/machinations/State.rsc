module lang::machinations::State

import lang::machinations::AST;

data Cond
  = rany(int src, int f, int tgt)  //condition is true: if 0 < flow <= f
  | rall(int src, int f, int tgt)  //condition is true: flow == f
  | and(list[Cond] cs)             //condition is true if all of its parts are true
  | i_or(list[Cond] cs)            //condition is true if one of its parts is true, and ordering is independent
  | d_or(list[Cond] cs)            //condition is true if one of its parts are true, and ordering is dependent
  | alt(list[Cond] cs)             //condition consists of multiple alternatives
  | noc();                         //no condition
  
alias Mach2 =
  tuple
  [
    Machinations m,
    map[int tgt, list[Element] fs] inflow,     //what is the inflow of this node?
    map[int src, list[Element] fs] outflow,    //what is the outflow of this node?
    map[int tgt, list[int] src] inflowLabels,
    map[int src, list[int] tgt] outflowLabels,
    map[int src, list[Element] fs] triggers,   //does this node trigger another?
    map[int tgt, list[Element] fs] activators, //is this node deactivated?
    map[int l, Cond c] conditions,             //are the conditions for this node constant?
    map[int l, Element e] elements,            //which element belongs to this label?
    set[list[int]] interleavings,
    set[int] sources,
    set[int] drains,
    set[int] pools,
    set[int] gates,
    set[int] nodes,
    set[int] pullNodes,
    set[int] pushNodes
  ];

alias State =
  tuple
  [
    list
    [
      int v   //pool value
    ] pools,  //pools (indexed by pool label)
    map
    [
      int g, //g = gate label
      tuple
      [
        int oc, //oc = gate distribution count 
        int on  //on = gate number (index on list of inflow or outflow)
      ] gate
    ] gates,
    set
    [
      int p      //p = a label is in the set if its node is activated
    ] activated  //set of labels
  ];
  
alias TempState =
    map
    [
      int g, //g = gate label
      int v  //v = gate value
    ];       //gate values
    
alias Transition =
  list //could also be a set
  [
    tuple
    [
      int src, //source pool
      int f,   //amount
      int tgt  //target pool
    ] redist   //redistribution
  ];

public Mach2 NEW_Mach2 = <mach([]),(),(),(),(),(),(),(),(),{},{},{},{},{},{},{},{}>;
