module lang::promela::AST

data Element
  = e_do(list[Element] alts, Element els)
  | e_if(list[Element] alts, Element els)
  | e_opt(list[Element] es);