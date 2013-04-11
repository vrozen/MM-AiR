module lang::machinations::Checker

import lang::machinations::AST;
import lang::machinations::Labeler;
import lang::machinations::FlowGraph;
import lang::machinations::Message;

import IO;

public list[Msg] check(Machinations m, MachinationsInfo mi, MachinationsFlow mf)
{
  return [*(
             checkFlow(ct, cti, ctf) +
             checkConverters(ct, cti, ctf)
           )
          | <<ct,cti>,ctf> <- {<mi[n],mf[n]> | n <- mi}];
}

private list[Msg] checkFlow(ComponentType ct, ComponentTypeInfo cti, ComponentTypeFlow ctf)
{
  list[Msg] msgs = [];

  for(<src_l, flow_l, tgt_l> <- ctf.seg.flow)
  {
    Element src_e = cti.l2e[src_l];
    Element tgt_e = cti.l2e[tgt_l];
    Element flow_e = ctf.l2e[flow_l];
    ID src_id = cti.l2n[src_l];
    ID tgt_id = cti.l2n[tgt_l];
    list[Unit] src_u = getUnits(src_e, true);
    list[Unit] tgt_u = getUnits(tgt_e, false);
    msgs += [flowError(flow_e,src_id,tgt_id,u) | u <- src_u, u notin tgt_u && tgt_u != []];
  }
  
  return msgs;
}

private list[Msg] checkConverters(ComponentType ct, ComponentTypeInfo cti, ComponentTypeFlow ctf)
{
  list[Msg] msgs = [];
  for(converter (bool and, list[ID] names, list[ID] opt_src_u, list[ID] opt_tgt_u) <- ct.elements)
  {
    for(n <- names)
    {
      FLabel l = n@l;
      //println("converter label <l>");
      
      //get ingoing and outgoing flow labels
      set[FLabel] in_ls = {src | <src,_,l> <- ctf.seg.flow};
      set[FLabel] out_ls = {tgt | <l,_,tgt> <- ctf.seg.flow};

      //println("input labels <in_ls>");
      //println("output labels <out_ls>");
    
      //get ingoing and outgoing flow elements
      set[Element] input_es = { cti.l2e[src] | src <- in_ls};    
      set[Element] output_es = { cti.l2e[tgt] | tgt <- out_ls};

      //println("input elements\n<input_es>");
      //println("output elements\n<output_es>");

      //get ingoing and outgoint flow units
      set[ID] input_us = { *(getUnits(input_e,true)) | input_e <- input_es };
      set[ID] output_us = { *(getUnits(output_e,false)) | output_e <- output_es};
    
      //println("input units\n<input_us>");
      //println("output units\n<output_us>");
        
      //check that each source unit in in the inflow and that each target unit is in the outflow
      msgs += [outputError(u) | u <- opt_tgt_u, u notin output_us] +
              [inputError(u) | u <- opt_src_u, u notin input_us];
    }
  }
  return msgs;
}


private list[Unit] getUnits(Element e, bool isSource)
{
  if(converter(bool and, list[ID] names, list[Unit] opt_src_u, list[Unit] opt_tgt_u) := e)
  {
    if(isSource == true)
    {
      return opt_tgt_u;
    }
    else
    {
      return opt_src_u;
    }
  }
  else //should work since all other components have the opt_u field
  {
    return e.opt_u;
  }
}
