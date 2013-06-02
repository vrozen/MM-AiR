
Random p1

auto push all pool doit at 1
auto all gate done

p1.done --> done
done --> doit
doit --> p1.do


pool resources at 100
all converter buyAttack
all converter buyDefence
all converter buyFactory

resources -2-> buyAttack
resources -1-> buyDefence
resources -5-> buyFactory


buyAttack --> attack
buyDefence --> defence
buyFactory --> factory
pool factory
pool defence
pool attack

resources .=.> p1.resources

buyAttack  .=.> p1.buyAttack
buyDefence .=.> p1.buyDefence
buyFactory .=.> p1.buyFactory

assert bla : factory < 5 "test"

Random(ref buyAttack, ref buyDefence, ref buyFactory, ref resources, in do, out done)
{
  pool do     gate d1     gate d2  gate d3     gate d4    pool done
  do .*.> d1  d1 .*.> d2  d2 .*.>  d3 d3 .*.>  d4 d4 .*.> done  
  do .*.> tick
  do --> done
  
  source tick
  tick --> state
  pool state  
  auto pool attack
  auto pool defence
  auto pool factory  
  auto all drain busy
  auto all drain getAttack
  auto all drain getDefence
  auto all drain getFactory
  
  getAttack  .*.> buyAttack
  getFactory .*.> buyFactory
  getDefence .*.> buyDefence

  state --> busy
  state --> attack 
  state --> defence
  state --> factory
  
  busy .defence!=0 || attack!=0 ||factory!=0 .>busy
  attack  .defence==0 && factory==0.> attack
  defence .attack ==0 && factory ==0.> defence
  factory .defence ==0 && attack ==0.> factory
  
  getAttack  .resources >= 2.> getAttack
  getDefence .resources >= 1.> getDefence
  getFactory .resources >= 5.> getFactory
  
  attack -all-> getAttack
  defence -all-> getDefence
  factory -all-> getFactory
}