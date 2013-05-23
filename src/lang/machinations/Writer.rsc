module lang::machinations::Writer

import String;
import List;
import IO;

alias Writer =
  tuple
  [
    loc tgt, //file to be written to
    str buf, //line buffer not yet written
    loc pos, //line location not yet written
    list[tuple[str text, loc pos]] lines //written lines
  ];

//retrieves the current line
public int getCurrentLine(Writer w)
  = size(w.lines) + 1;

//retrieves the location associated with a line
public loc getLocation(Writer w, int line)
  = w.lines[line-1].src;

public Writer writer(loc tgt)
  = <tgt, "", tgt, []>;

public Writer writeln(Writer w)
  = <w.tgt, "", w.tgt, w.lines + [<w.buf, w.pos>]>;

public Writer writeln(Writer w, str text)
  = writeln(write(w, text, w.pos));

public Writer writeln(Writer w, str text, loc pos)
  = writeln(write(w, text, pos));

public Writer write(Writer w, str text)
  = write(w, text, w.pos);

public Writer write(Writer w, str text, loc pos)
{
  list[int] allBreaks = findAll(text, "\n");                           //all line breaks
  set[int] escapedBreaks = {e + 1 | e <- findAll(text, "\\n")};        //escaped line breaks 
  list[int] actualBreaks = [b | b <- allBreaks, b notin escapedBreaks]; //actual line breaks
  
  list[tuple[str,loc]] lines = []; //lines to be written

  int lo = 0;
  int hi = 0;
  //println("all breaks <allBreaks>");
  //println("escaped breaks <escapedBreaks>");
  //println("actual breaks <actualBreaks>");
  for(int i <- actualBreaks)
  {
    hi = i;
    //println("lo: <lo> hi: <hi>");
    w.lines += [<w.buf + substring(text, lo, hi), pos>];
    lo = hi + 1;
    w.buf = "";
  }
  
  if(hi < size(text))
  {
    w.buf += substring(text, lo, size(text));
    //println("buf: <w.buf>");
  }

  return w;
}

public void writeFile(Writer w)
{
  println("Output writen to file <w.tgt>");
  writeFile(w.tgt, toString(w));
}

public str toString(Writer w)
{
  str out = "";
  for(tuple[str text, loc src] line <- w.lines)
  {
    out += line.text + "\n";
  }
  return out;
}

/*
public Writer testWriter()
{
  Writer w = writer(|project://MM-AiR/test/activator.mm|);
  w = write(w, "hello
               'world");
  w = writeln(w);
  w = writeln(w, "hello to you too");
  w = write(w, "dubdeedoo
               'and tailor too");
  w = writeln(w);
  

  println(toString(w));
  return w;
}
*/