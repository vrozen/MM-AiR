unit Gold    : "gold"
unit Factory : "factories"
unit Defence : "defence"
unit Attack  : "attack"

PlayerRules player1      //declare player1 rules
Random playerAct1
PlayerRules player2      //declare player2 rules
Turtle playerAct2

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

assert tie :
  (player1.reserve > 0 || player1.resources > 0) ||
  (player2.reserve > 0 || player2.resources > 0)
  "tie"

PlayerRules(in BuyAttack, in BuyFactory, in BuyDefence,  //trigger these for choice
            in reserve, in killed, in destroyed,         //trigger these once each turn 
            ref opponent_attack, ref opponent_defence,   //opponent you are fighting
            out attack, out defence)                     //your visible stats
{
  pool reserve of Gold at 100          //Gold reserve (starts at 100)
  pool resources of Gold               //Gold resources (used for purchases)
  pool factories of Factory at 1       //factories producing income (start with 1)
  pool defence of Defence, Attack at 1 //defending Attack and Defence units
  pool attack of Attack                //attacking Attack units
  assert alive : factories > 0 "loss"

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

Turtle(ref buyAttack, ref buyDefence, ref buyFactory, ref turn)
{
  turn .*.> count

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

Random(ref buyAttack, ref buyDefence, ref buyFactory, ref turn)
{
  turn .*.> count
  
  source tick
  pool count      //count when triggered
  tick --> count  //count 1
  
  pool stateNone at 1
  auto pull pool stateAttack
  auto pull pool stateDefence
  auto pull pool stateFactory
  
  auto gate getAttack
  auto gate getDefence
  auto gate getFactory  
  
  getAttack  .*.> stateNone
  getDefence .*.> stateNone
  getFactory .*.> stateNone
    
  stateAttack  .stateAttack ==1 && count ==2.> getAttack
  stateDefence .stateDefence==1 && count ==1.> getDefence
  stateFactory .stateFactory==1 && count ==5.> getFactory
  
  getAttack  .*.> buyAttack
  getFactory .*.> buyFactory
  getDefence .*.> buyDefence


  //possible state changes
  stateNone    --> stateAttack 
  stateNone    --> stateDefence
  stateNone    --> stateFactory  
  stateAttack  --> stateNone
  stateDefence --> stateNone
  stateFactory --> stateNone

}

/*
AntiTurtle(ref buyAttack, ref buyDefence, ref buyFactory)
{
  source tick
  auto pool count
  //auto drain chooseDefence
  auto drain chooseFactory
  auto drain chooseAttack
  tick --> count  
  //tick --> chooseDefence
  tick --> chooseFactory
  tick --> chooseAttack

  count .<=6.> chooseFactory
  count .>6.> chooseAttack
  
  //chooseDefence .*.> buyDefence
  chooseAttack .*.> buyAttack
  chooseFactory .*.> buyFactory
}
*/

/*
Warmonger(ref buyAttack, ref buyDefence, ref buyFactory)
{
  source tick
  auto drain attack
  tick --> attack
  attack .*.> buyAttack
}*/