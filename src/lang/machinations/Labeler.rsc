module lang::machinations::Labeler

import lang::machinations::AST;
import lang::machinations::Message;

public tuple[Machinations,list[Msg]] machinations_label (Machinations m)
{
  list[Msg] msgs = [];
  map[ID,int] n2l = ();
  //map[int,Element] l2e = ();
  int l = 0;
  
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
