unit Gold : "gold"
unit Factory : "factories"
unit Defence : "defence"
unit Attack : "attack"

PlayerRules player1      //declare player1 rules
PlayerRules player2      //declare player2 rules
Warmonger playerAct1
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

PlayerRules(in BuyAttack, in BuyFactory, in BuyDefence,
            ref opponent_attack, ref opponent_defence,
            out attack, out defence)
{
  pool reserve of Gold at 100          //Gold reserve (starts at 100)
  auto pool resources of Gold          //Gold resources (used for purchases)
  pool factories of Factory at 1       //factories producing income (start with 1)
  pool defence of Defence, Attack at 1 //defending Attack and Defence units
  pool attack of Attack                //attacking Attack units
  assert alive : factories > 0 "loss"

  auto drain killed of Defence, Attack //drain kills attack or defence
  auto drain destroyed of Factory      //drain destroys factories (* pulls all)

  all converter buyDefence from Gold to Defence //convert all required Gold to Defence
  all converter buyAttack  from Gold to Attack  //convert all required Gold to Attack
  all converter buyFactory from Gold to Factory //convert all required Gold to Factory

  reserve -factories * 0.25 + 1-> resources //flow 0.25 * factories Gold to resources
  resources -5-> buyFactory      //buyFactory consumes 5 Gold from resources
  buyFactory --> factories       //buyFactory produces 1 Factory to factories
  resources -1-> buyDefence      //buyDefence consumes 2 Gold from resources
  buyDefence --> defence         //buyDefence produces 1 Defence to defence
  resources -2-> buyAttack        //buyAttack consumes 1 Gold from resources
  buyAttack --> attack           //buyAttack produces 1 Attack to attack

  factories -factories-> destroyed     //factories destuction rate
  defence -opponent_attack * 0.25-> killed  //defence casualty rate
  attack -opponent_defence * 0.25-> killed  //attack casualty rate
  defence .defence == 0 && attack == 0.> destroyed  //zero defence enables destroyed
}

Turtle(ref buyAttack, ref buyDefence, ref buyFactory)
{
  source tick
  auto pool count
  auto drain chooseDefence
  auto drain chooseFactory
  auto drain chooseAttack
  tick --> count  
  tick --> chooseDefence
  tick --> chooseFactory
  tick --> chooseAttack

  count . count <=6.> chooseDefence
  count . count >6 && count <15.> chooseFactory
  count . count >=15.> chooseAttack
  
  chooseDefence .*.> buyDefence
  chooseAttack .*.> buyAttack
  chooseFactory .*.> buyFactory
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

Warmonger(ref buyAttack, ref buyDefence, ref buyFactory)
{
  source tick
  auto drain attack
  tick --> attack
  attack .*.> buyAttack
}

/*
Random(ref buyAttack, ref buyDefence, ref buyFactory)
{
  auto source tick
  gate r
  pool attack
  pool defence
  pool factory
  drain chooseDefence
  drain chooseAttack
  drain chooseFactory
   
  tick --> r
  r --> factory
  r --> attack
  r --> defence
  
  factory -all-> chooseFactory
  defence -all-> chooseDefence
  attack -all-> chooseAttack
  
  defence .==1.> chooseDefence
  attack  .==2.> chooseAttack
  factory .==3.> chooseFactory
  
  chooseAttack .*.> buyAttack
  chooseFactory .*.> buyFactory
  chooseDefence .*.> buyDefence
}*/
