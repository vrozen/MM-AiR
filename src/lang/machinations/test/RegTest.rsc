module lang::machinations::test::RegTest

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
import Message;
import IO;
import String;

private loc MACHINATIONS_LOC      = |project://machinations/test|;
private str MACHINATIONS_SFX      = ".mach4";

data Verdict
  = success(loc l)
  | parserFail(loc l)
  | imploderFail(loc l)
  | transformerFail(loc l)
  | folderFail(loc l)
  | labelerFail(loc l)
  | checkerFail(loc l)
  | dfAnalyzerFail(loc l)
  | rdAnalyzerFail(loc l)
  | messageFail(loc l)
  | typeFail(loc l)
  ;
  
public test bool testAll()
{
  return testAll(LUA_LOC) && testAll(LUA_LOC_2);
}
  
public bool testAll(loc files_loc)
{
  set[loc] ltFiles = getFiles(LUA_TYPE_LOC, LUA_TYPE_SFX);
  set[Verdict] ltVerdicts = {lua_type_test(file) | file <- ltFiles};
  set[Verdict] ltFailures =  {v | v <- ltVerdicts, success(_) !:= v};

  set[loc] luaFiles = getFiles(files_loc, LUA_SFX); 
  set[Verdict] luaVerdicts = {lua_test(file) | file <- luaFiles};
  set[Verdict] luaFailures =  {v | v <- luaVerdicts, success(_) !:= v};

  iprintln(ltVerdicts);
  iprintln(luaVerdicts);

  return ltFailures == {} && luaFailures == {};
}

private set[loc] getFiles(loc dir, str suffix)
{
  return {dir+"/<file>" | file <- listEntries(dir), endsWith(file, suffix)};
}

private Verdict lua_type_test(loc l)
{
  Tree x;
  LT ast;  
  LuaTypes ts;
  list[Msg] m;
  
  iprintln(l);
  
  //1. Parse
  try
  {
    x = lua_type_parse(l);
  }
  catch e:
  {
    return parserFail(l);
  }
  
  //2. Implode
  try
  {
    ast = lua_type_implode(x);
  }
  catch e:
  {
    return imploderFail(l);
  }

  //3. Create Type
  try
  {
    ts = lua_type_toType(ast);
  }
  catch e:
  {
    return typeFail(l);
  }  
   
  //3. Check
  try
  { 
    <ts, m> = lua_type_Checker_check(ts);
  }
  catch e:
  {
    return checkerFail(l);
  }

  //4. Report
  try
  { 
    set[Message] errors = getErrors(m);
  }
  catch e:
  {
    return messageFail(l);
  }

  return success(l);
}

private Verdict lua_test(loc l)
{
  //define tree, ast, seg, checker and analyzer
  Tree x;
  Block ast_1, ast_2, ast_3, ast_4, ast_5;
  DFSegment seg;
  Analyzer a = NEW_Analyzer;
  Checker c = Checker_new(lua_getTypes());

  iprintln(l);

  //1. Parse
  try
  {
    x = lua_parse(l);
  }
  catch e:
  {
    return parserFail(l);
  }
  
  //2. Implode
  try
  {
    ast_1 = lua_implode(x);
  }
  catch e:
  {
    return imploderFail(l);
  }
  
  //3. Transform
  try
  {
    ast_2 = lua_transform(ast_1);
  }
  catch e:
  {
    return transformerFail(l);
  }
  
  //4. Fold
  try
  {
    <c.messages, ast_3> = lua_fold(c.messages, ast_2); 
  }
  catch e:
  {
    return folderFail(l);
  }
  
  //5. Label
  try
  {
    <a.nodes, ast_4> = lua_setLabels(ast_3);
  }
  catch e:
  {
    return labelFail(l);
  }
  
  //6. Check
  try
  { 
    <c, ast_5> = lua_Checker_check(c, ast_4);
  }
  catch e:
  {
    return checkerFail(l);
  }

  //7. Data Flow Analysis
  try
  {  
    <a, seg> = lua_DFAnalyzer_analyze(a, ast_5);
  }
  catch e:
  {
    return dfAnalyzerFail(l);
  }
  
  //8. Reaching Definitions Analysis
  try
  {
    a = lua_RDAnalyzer_analyze(a, c, ast_5, seg);
  }
  catch e:
  {
    return rdAnalyzerFail(l);
  }
  
  //9. Error reporting
  try
  {
    set[Message] errors = getErrors(c) + getErrors(a);
    set[Message] warnings = getWarnings(c) + getWarnings(a);
    set[Message] infos = getInfo(c) + getInfo(a);
    messages = errors + warnings + infos;
  }
  catch e:
  {
    return messageFail(l);
  }
  
  return success(l);
}
