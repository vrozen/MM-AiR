unit BreadCrumbs : "bread crumbs"
unit Droppings   : "bird residue"

auto push all pool lady of BreadCrumbs at 10 max 10  //declare a lady has 10 crumbs, and she throws them
pool pond of BreadCrumbs max 10                      //declare a pond contains crumbs

pool road of Droppings max 10             //declare a road contains droppings
pool BIG_APPETITE of BreadCrumbs at 2     //declare big appetite is 2 crumbs
pool SMALL_APPETITE of BreadCrumbs at 1   //declare small appetite is 1 crumb
lady --> pond                             //lady throws bread crumbs in the pond, one at a time

//declare bird b1 with a big apetite   (its pond is the pond, its road is the road)
Bird b1   BIG_APPETITE .=.> b1.appetite     pond .=.> b1.pond   road .=.> b1.road
//declare bird b2 with a small apetite (its pond is the pond, its road is the road)
Bird b2   SMALL_APPETITE .=.> b2.appetite   pond .=.> b2.pond   road .=.> b2.road

Bird(ref appetite, ref pond, ref road) //declare Bird type (with references to pond, road and apetite)
{
  auto any pool eat of BreadCrumbs max 10  //birds eat all they want (not less)
  pond -appetite-> eat              //birds eat as much as their apetite specifies
  
  //digestion is automatic and converts crumbs to droppings
  auto all converter digest from BreadCrumbs to Droppings
  eat --> digest   //food from eat is digested into
  digest --> road  //droppings to the road

  //we keep track of how much a bird digested
  pool count max 10
  digest --> count
  
  assert fed : count > 0 || road < 10 "birds always get fed"
}
