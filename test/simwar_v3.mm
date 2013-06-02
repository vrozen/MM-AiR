unit Gold    : "gold"
unit Factory : "factories"
unit Defense : "defense"
unit Attack  : "attack"

Turtle player1
State  state1
Random player2
State  state2

auto push all pool doit at 2
auto all gate done

player1.done --> done
player2.done --> done
done -2-> doit
doit --> player1.do
doit --> player2.do

done .=.> state1.do
done .=.> state2.do

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

state2.factories  .=.> player2.factories

//assert tie : state1.reserve > 0 || state2.reserve > 0 "tie"
assert turtleLives : state1.factories != 0 "turtle dies"
//assert randomLives : state2.factories != 0 "random dies"

State(in BuyAttack, in BuyFactory, in BuyDefense,            //trigger these for choice
      ref opponent_attack, ref opponent_defense, ref do,     //opponent you are fighting
      out attack, out defense, out factories, out resources) //your visible stats
{
  do .*.> resources
  do .*.> killed
  do .*.> destroyed

  pool reserve of Gold at 50           //Gold reserve (starts at 50)
  pool resources of Gold               //Gold resources (used for purchases)
  pool factories of Factory at 1 max 3 //factories producing income (start with 1)
  pool defense of Defense, Attack at 1 //defending Attack and Defense units
  pool attack of Attack                //attacking Attack units

  drain killed of Defense, Attack //defense and attack can be killed
  drain destroyed of Factory      //factories can be destroyed
  
  all converter buyDefense from Gold to Defense //convert all required Gold to Defense
  all converter buyAttack  from Gold to Attack  //convert all required Gold to Attack
  all converter buyFactory from Gold to Factory //convert all required Gold to Factory

  //factories .factories<5.> buyFactory

  reserve -factories-> resources //flow 0.25 * factories Gold to resources
  resources -5-> buyFactory      //buyFactory consumes 5 Gold from resources
  buyFactory --> factories       //buyFactory produces 1 Factory to factories
  resources -1-> buyDefense      //buyDefense consumes 2 Gold from resources
  buyDefense --> defense         //buyDefense produces 1 Defense to defense
  resources -2-> buyAttack       //buyAttack consumes 1 Gold from resources
  buyAttack --> attack           //buyAttack produces 1 Attack to attack

  factories -all-> destroyed           //factories destuction
  defense -opponent_attack/4-> killed  //defense casualty rate
  attack  -opponent_defense/4-> killed //attack casualty rate
  defense .defense == 0.> destroyed    //zero defense enables destroyed
}

Turtle(ref buyAttack, ref buyDefense, ref buyFactory, ref resources, in do, out done)
{
  pool do max 1
  auto delay work by 2
  auto pool done max 1
  do --> work
  work --> done
  do .*.> tick
  
  all source tick
  tick --> state
  tick --> count

  pool count
  
  pool state max 1
  auto pool attack max 1
  auto pool defense max 1
  auto pool factory max 1
  auto all drain getAttack
  auto all drain getDefense
  auto all drain getFactory
  
  getAttack  .*.> buyAttack
  getFactory .*.> buyFactory
  getDefense .*.> buyDefense

  state --> attack 
  state --> defense
  state --> factory
  
  attack   .defense==0 && factory==0 && count >= 12.> attack
  defense  .attack ==0 && factory==0 && count <6.> defense
  factory  .defense==0 && attack ==0 && count >= 6 && count < 12.> factory
  
  getAttack  .resources >= 2 && attack > 0.> getAttack
  getDefense .resources >= 1 && defense > 0.> getDefense
  getFactory .resources >= 5 && factory > 0.> getFactory
  
  attack --> getAttack
  defense --> getDefense
  factory --> getFactory
}

Random(ref buyAttack, ref buyDefense, ref buyFactory, ref factories, ref resources, in do, out done)
{
  pool do max 1
  auto delay work by 2
  auto pool done max 1
  do --> work
  work --> done
  do .*.> tick
  
  all source tick
  tick --> state
  pool state max 1
  auto pool attack max 1
  auto pool defense max 1
  auto pool factory max 1
  /*auto*/ drain skip
  auto all drain getAttack
  /*auto*/ all drain getDefense
  auto all drain getFactory
  
  getAttack  .*.> buyAttack
  getFactory .*.> buyFactory
  getDefense .*.> buyDefense

  state --> skip
  state --> attack 
  state --> defense
  state --> factory
  
  skip    .defense==0 && attack==0 && factory==0 .> skip
  attack  .defense==0 && attack==0 && factory==0 .> attack
  defense .defense==0 && attack==0 && factory==0 .> defense
  factory .defense==0 && attack==0 && factory==0 && factories < 3.> factory
  
  getAttack  .resources >= 2 && attack > 0.> getAttack
  getDefense .resources >= 1 && defense > 0.> getDefense
  getFactory .resources >= 5 && factory > 0.> getFactory
  
  attack --> getAttack
  defense --> getDefense
  factory --> getFactory
}