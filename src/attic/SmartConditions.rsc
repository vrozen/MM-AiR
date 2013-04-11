module attic::SmartConditions


/*
//generate a list of conditions for one gate that acts on its own
public list[Cond] generateConditions(State s, Mach2 m2,
  g: gate(When when, Act act, How how, ID name, list[Unit] opt_u))
{
  list[Cond] conditions = getConditions(m2, p@l);
  if(conditions == [])
  { 
    //incoming state edges enable or disable this gate
    //outgoing state edges are all triggers (and are NOT activators)  
    switch(act)
    {
      case act_pull():
      {
        conditions = generateConditions(s, inFlow(m2, p@l), how);      
      }
      
      //gates cannot push in the machinations tool: it is removed for now
      //case act_push(): //the same as pulling from a gate
      //{
      //  //outgoing flow edges signify flow rate
      //  //incoming flow edges denote distribution chances
      //  map[Element, set[int]] fs = (f: eval(s,f) | f <- outFlow(m,g));      
      //  map[Element, set[int]] ds = (c: eval(s,c) | c <- inFlow(m,g));     
      //  conditions = generateConditions(fs, how) + generateDistributions(ds);
      //}
    }
  }
  return conditions;
}
*/

/*
//pulling pools: generate conditions that are pulling on this pool
public list[Cond] generateSmartConditions (State s, Mach2 m2,
    p: pool(When when, act_pull(), How how, ID name, list[Unit] units, At at, Mod md, Min min, Max max))
  = [generateCondition(s, getOutflow(m2,tgt@l), getElement(m2, tgt@l).how) |
      f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l), getElement(m2, tgt@l).act == act_pull()];

//pushing pools: generate conditions that are pulling on this pool
public list[Cond] generateSmartConditions (State s, Mach2 m2,
    p: pool(When when, act_push(), How how, ID name, list[Unit] units, At at, Mod md, Min min, Max max))
  = [generateCondition(s, getOutflow(m2,tgt@l), getElement(m2, tgt@l).how) |
      f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l), getElement(m2, tgt@l).act == act_pull()]
  + [generateCondition(s, getOutflow(m2,p@l), how)];
*/

//for each pool determine which conditions are pulling on it
//1. if this node pushes, then outgoing flow edges pull on this node
//2. for any outgoing edges connected to pulling nodes, these edges pull on this node
/*
public list[Cond] generateSmartConditions(State s, Mach2 m2,
  p: pool(When when, Act act, How how, ID name, list[Unit] units, At at, Mod md, Min min, Max max))
{
  list[Cond] conditions = [];
  conditions = //pull conditions
  for(f: flow(ID src, Exp exp, ID tgt) <- getOutflow(m2, p@l), getElement(m2, tgt@l).how == how_pull())
  {
    append generateCondition(s, getOutflow(m2,tgt@l), how_pull());
  }
  
  if(act == act_push()) //push conditions
  {
    conditions += generateCondition(s, getOutflow(m2,p@l), how);
  }
  
  return conditions;
}*/



