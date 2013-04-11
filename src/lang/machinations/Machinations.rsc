module lang::machinations::Machinations

import lang::machinations::Syntax;
import lang::machinations::AST;
import lang::machinations::State;
import lang::machinations::Desugar;
import lang::machinations::Serialize;
import lang::machinations::Preprocessor;
import lang::machinations::Instantiator;
import lang::machinations::Labeler;
import lang::machinations::Evaluator;
import lang::machinations::Generator;
import lang::machinations::Message;
import lang::machinations::Visualize;
import lang::machinations::ToPromela;

import ParseTree;
import util::IDE;
import vis::Figure;
import IO;
import Message;

//data OL = outl(list[str] errs);

private str Machinations_NAME = "Machinations"; //language name
private str Machinations_EXT = "mach4";         //file extension

private Tree machinations_check(Tree t)
{
  //Machinations m = machinations_implode(t);
  //list[Msg] msgs;
  //list[Message] errors;  
  //<m, mi> = setLabels(m);
  //<msgs, mf> = getFlow(m, mi);
  //msgs += check(m, mi, mf);

  //errors = getErrors(msgs);
  //uses = getUses(m, mi);
  //defs = getDefs(uses);
  
  //t = setLink(t, uses);
  //t = setLinks(t, defs);
  
  //return t[@messages = errors];
  return t;
}

private node machinations_outline(Tree t)
  = machinations_implode(t);

private void flatten(Tree t, loc l)
{
  Machinations m1 = machinations_implode(t); 
  Machinations m2 = machinations_desugar(m1);
  //println("desugared:\n<toString(m2)>\n");
  <m3, msgs> = machinations_flatten(m2);
  Machinations m4 = machinations_desugarFlat(m3);
  println("/*Flattened model <l>*/\n<toString(m4)>\n");
  if(msgs!=[])
  {
    println("Errors:\n<toString(msgs)>");
  }
}

private void visualize(Tree t, loc l)
{
  machinations_visualize(t,l);
}

public void simulate(Tree t, loc l)
{
  Machinations m1 = machinations_implode(t); 
  Machinations m2 = machinations_desugar(m1);
  <m3, msgs3> = machinations_flatten(m2);
  Machinations m4 = machinations_desugarFlat(m3);
  <m5, msgs5> = machinations_label(m4);
  println(toString(m5));  
  msgs = msgs3 + msgs5;
  if(msgs != [])
  {
    println("Errors:\n<toString(msgs)>");
  }
  else
  {
    Mach2 m6 = machinations_preprocess(m5);
    machinations_simulate(m6);
  }
}

public void generate(Tree t, loc l)
{
  Machinations m1 = machinations_implode(t); 
  Machinations m2 = machinations_desugar(m1);
  <m3, msgs3> = machinations_flatten(m2);
  Machinations m4 = machinations_desugarFlat(m3);
  <m5, msgs5> = machinations_label(m4);
  msgs = msgs3 + msgs5;
  println(toString(msgs));
  if(msgs != [])
  {
    println("Errors:\n<toString(msgs)>");
  }
  else
  {
    Mach2 m6 = machinations_preprocess(m5);
    machinations_generate(m6);
  }
}

public void compile(Tree t, loc l)
{
  Machinations m1 = machinations_implode(t); 
  Machinations m2 = machinations_desugar(m1);
  <m3, msgs3> = machinations_flatten(m2);
  Machinations m4 = machinations_desugarFlat(m3);
  <m5, msgs5> = machinations_label(m4);
  msgs = msgs3 + msgs5;
  println(toString(msgs));
  if(msgs != [])
  {
    println("Errors:\n<toString(msgs)>");
  }
  else
  {
    Mach2 m6 = machinations_preprocess(m5);
    str promelaModel = machinations_toPromela(m6);
    println("promela model:\n<promelaModel>");    
  }
}

public void registerMachinations()
{
  c =
  {
    categories
    (
      (
        "Name" : {foregroundColor(color("royalblue"))},
        "TypeName" : {foregroundColor(color("darkblue")),bold()},
        "UnitName" : {foregroundColor(color("mediumblue")),bold()},
        "Comment": {foregroundColor(color("dimgray"))},
        "Value": {foregroundColor(color("firebrick"))},
        "String": {foregroundColor(color("teal"))}
        //,"MetaKeyword": {foregroundColor(color("blueviolet")), bold()}
      )
    ),
    popup
    (
      menu
      (
        "Machinations",
        [
          action("flatten", flatten),
          action("simulate", simulate),
          action("generate", generate),
          action("visualize", visualize),
          action("toPromela", compile)
        ]
      )
    )
  };
    
  registerLanguage(Machinations_NAME, Machinations_EXT, machinations_parse);
  //registerAnnotator(Machinations_NAME, machinations_check);
  registerOutliner(Machinations_NAME, machinations_outline);
  registerContributions(Machinations_NAME, c);
}

public void probeer()
{
  loc f = |project://machinations/test/city.mach4|;
  simulate(machinations_parse(f), f);
}

public void simwar()
{
  loc f = |project://machinations/test/simwar_v1.mach4|;
  simulate(machinations_parse(f), f);
}

public void gen()
{
  loc f = |project://machinations/test/simwar_v1.mach4|;
  generate(machinations_parse(f), f);
}

public void vis()
{
  loc f = |project://machinations/test/bird.mach4|;
  visualize(machinations_parse(f), f);
}



/*
private Tree machinations_setLink(Tree t, map[loc, loc] l)
{
  //visit the parse tree and replace categories based on messages
  return visit(t)
  {
    case Tree n:
    {
      if(n@\loc? && n@\loc in l)
      {
        insert n[@link = l[n@\loc]];
      }
    }
  }
}

private Tree machinations_setLinksList(Tree t, map[loc, list[loc]] l)
{
  map[loc, set[loc]] l2 = ();
  for(loc src <- l)
  {
    l2 += (src : toSet(l[src]));
  }
  return setLinks(t, l2);
}

private Tree machinations_setLinks(Tree t, map[loc, set[loc]] l)
{
  return visit(t)
  {
    case Tree n:
    {
      if(n@\loc? && n@\loc in l)
      {
        insert n[@links = l[n@\loc]];
      }
    }
  }
}*/
