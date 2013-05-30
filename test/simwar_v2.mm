unit Gold    : "gold"
unit Factory : "factories"
unit Defence : "defence"
unit Attack  : "attack"

PlayerRules player1      //declare player1 rules
Random playerAct1
PlayerRules player2      //declare player2 rules
Turtle playerAct2



pool turn at 1
auto pool go
turn --> go
go --> turn

gate d1
gate d2
gate d3 
gate d4
go .*.> d1
d1 .*.> d2
d2 .*.> d3
d3 .*.> d4
d4 .*.> turn


go .=.> player1.do
go .=.> player2.do
go .=.> playerAct1.do
go .=.> playerAct2.do

player1.resources .=.> playerAct1.resources

player1.defence .=.> player2.opponent_defence
player1.attack  .=.> player2.opponent_attack

player2.defence .=.> player1.opponent_defence
player2.attack  .=.> player1.opponent_attack  

player1.buyAttack .=.> playerAct1.buyAttack
player1.buyFactory .=.> playerAct1.buyFactory 
player1.buyDefence .=.> playerAct1.buyDefence

player2.buyAttack .=.> playerAct2.buyAttack
player2.buyFactory .=.> playerAct2.buyFactory 
player2.buyDefence .=.> playerAct2.buyDefence

/*assert tie :
  (player1.reserve > 0 || player1.resources > 0) ||
  (player2.reserve > 0 || player2.resources > 0)
  "tie"*/
  
assert turtle : player2.factories > 0 "turtle beaten"  

PlayerRules(in BuyAttack, in BuyFactory, in BuyDefence,  //trigger these for choice
            in reserve, in killed, in destroyed,         //trigger these once each turn 
            ref opponent_attack, ref opponent_defence,   //opponent you are fighting
            out attack, out defence, out resources, ref do)   //your visible stats
{
  do .*.> resources
  do .*.> killed
  do .*.> destroyed

  pool reserve of Gold at 100          //Gold reserve (starts at 100)
  pool resources of Gold               //Gold resources (used for purchases)
  pool factories of Factory at 1       //factories producing income (start with 1)
  pool defence of Defence, Attack at 1 //defending Attack and Defence units
  pool attack of Attack                //attacking Attack units
  //assert alive : factories > 0 "loss"

  drain killed of Defence, Attack //drain kills attack or defence
  drain destroyed of Factory      //drain destroys factories (* pulls all)
  
  all converter buyDefence from Gold to Defence //convert all required Gold to Defence
  all converter buyAttack  from Gold to Attack  //convert all required Gold to Attack
  all converter buyFactory from Gold to Factory //convert all required Gold to Factory

  reserve -factories / 4 + 1-> resources //flow 0.25 * factories Gold to resources
  resources -5-> buyFactory      //buyFactory consumes 5 Gold from resources
  buyFactory --> factories       //buyFactory produces 1 Factory to factories
  resources -1-> buyDefence      //buyDefence consumes 2 Gold from resources
  buyDefence --> defence         //buyDefence produces 1 Defence to defence
  resources -2-> buyAttack       //buyAttack consumes 1 Gold from resources
  buyAttack --> attack           //buyAttack produces 1 Attack to attack

  factories -all-> destroyed                        //factories destuction rate
  defence -opponent_attack / 4 + 1 -> killed        //defence casualty rate
  attack  -opponent_defence / 4 + 1-> killed        //attack casualty rate
  defence .defence == 0 && attack == 0.> destroyed  //zero defence enables destroyed
}

Turtle(ref buyAttack, ref buyDefence, ref buyFactory, ref do)
{
  do .*.> count

  source tick
  pool count
  tick --> count  

  auto all drain chooseDefence
  auto all drain chooseFactory
  auto all drain chooseAttack

  tick --> chooseDefence
  tick --> chooseFactory
  tick --> chooseAttack

  count .count <=6.> chooseDefence
  count .count >6 && count <15.> chooseFactory
  count .count >=15.> chooseAttack
  
  chooseDefence .*.> buyDefence
  chooseAttack .*.> buyAttack
  chooseFactory .*.> buyFactory
}

Random(ref buyAttack, ref buyDefence, ref buyFactory, ref resources, ref do)
{
  do .*.> tick
   
  source tick
  tick --> state
  pool state  
  auto pool attack
  auto pool defence
  auto pool factory  
  auto all drain getAttack
  auto all drain getDefence
  auto all drain getFactory
  
  getAttack  .*.> buyAttack
  getFactory .*.> buyFactory
  getDefence .*.> buyDefence

  state --> attack 
  state --> defence
  state --> factory
  
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