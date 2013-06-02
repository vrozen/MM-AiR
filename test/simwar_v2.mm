unit Gold    : "gold"
unit Factory : "factories"
unit Defense : "defense"
unit Attack  : "attack"

Turtle player1
State  state1
Random player2
State  state2

auto all pool doit at 1 max 1
auto all pool do1 max 1
auto all pool do2 max 1

doit --> do1
do1  --> do2
do2  --> doit

doit .==1.> do1
do1  .==1.> do2
do2  .==1.> doit

doit .=.> state1.turn
doit .=.> state2.turn
doit .=.> player1.turn
doit .=.> player2.turn

state1.resources .=.> player1.resources
state2.resources .=.> player2.resources

state1.defense .=.> state2.opponent_defense
state1.attack  .=.> state2.opponent_attack

state2.defense .=.> state1.opponent_defense
state2.attack  .=.> state1.opponent_attack  

state1.buyAttack  .=.> player1.buyAttack
state1.buyFactory .=.> player1.buyFactory 
state1.buyDefense .=.> player1.buyDefense

state2.buyAttack  .=.> player2.buyAttack
state2.buyFactory .=.> player2.buyFactory 
state2.buyDefense .=.> player2.buyDefense

state1.factories  .=.> player1.factories
state2.factories  .=.> player2.factories


//assert tie : state1.reserve > 0 || state2.reserve > 0 "tie"
assert turtleLives : state1.factories != 0 "turtle dies"
//assert randomLives : state2.factories != 0 "random dies"

State(in BuyAttack, in BuyFactory, in BuyDefense,            //choices
      ref opponent_attack, ref opponent_defense, ref turn,   //opponent
      out attack, out defense, out factories, out resources) //visible stats
{
  turn .*.> resources
  turn .*.> killed
  turn .*.> destroyed

  pool reserve of Gold at 50           //Gold reserve (starts at 50)
  pool resources of Gold               //Gold resources (for purchases)
  pool factories of Factory at 1 max 3 //factories producing income
  pool defense of Defense at 1         //defending units
  pool attack of Attack                //attacking units

  drain killed of Defense, Attack //defense & attack can be killed
  drain destroyed of Factory      //factories can be destroyed
  
  all converter buyDefense from Gold to Defense //convert Gold to Defense
  all converter buyAttack  from Gold to Attack  //convert Gold to Attack
  all converter buyFactory from Gold to Factory //convert Gold to Factory

  reserve -factories-> resources //flow factories Gold to resources
  resources -5-> buyFactory //buyFactory consumes 5 Gold from resources
  buyFactory --> factories  //buyFactory produces 1 Factory to factories
  resources -1-> buyDefense //buyDefense consumes 2 Gold from resources
  buyDefense --> defense    //buyDefense produces 1 Defense to defense
  resources -2-> buyAttack  //buyAttack consumes 1 Gold from resources
  buyAttack --> attack      //buyAttack produces 1 Attack to attack

  factories -all-> destroyed           //factories destuction
  defense -opponent_attack/4-> killed  //defense casualty rate
  attack  -opponent_defense/4-> killed //attack casualty rate
  defense .defense == 0.> destroyed    //no defense enables destroyed
}

Turtle(ref buyAttack, ref buyDefense, ref buyFactory, ref factories, ref resources, ref turn)
{
  source tick
  turn .*.> count
  tick --> count
  pool count

  auto source buy
  buy .*.> buyAttack
  buy .*.> buyFactory
  buy .*.> buyDefense

  count .count>=20 && factories >=3 && resources >=2.> buyAttack
  count .count<8 &&  resources >= 1.> buyDefense
  count .count>=8 && factories<3 && resources >=5.> buyFactory
}

Random(ref buyAttack, ref buyDefense, ref buyFactory, ref factories, ref resources, ref turn)
{  
  source tick
  turn .*.> count
  tick --> count
  pool count
  
  tick --> state
  auto pool state max 1
  auto all drain skip
  auto all drain getFactory
  auto all drain getAttack
  auto all drain getDefense
  
  getAttack  .*.> buyAttack
  getFactory .*.> buyFactory
  getDefense .*.> buyDefense
  
  state --> skip
  state --> getAttack 
  state --> getDefense
  state --> getFactory
  
  count .count>15.>skip
  count .resources >= 2 && count >= 20.> getAttack
  count .resources >= 1 && count < 10.> getDefense
  count .resources >= 5 && factories<3.> getFactory
}