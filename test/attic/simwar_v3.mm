Battle()              //Battle reuses the Operations component type.
{
  pool attack
  pool defence  
  Operations player1  //declare Operations player1 
  Operations player2  //declare Operations player2
  player1.attack  ==> player2.opponent_attack
  player1.defence ==> player2.opponent_defence  
  player2.attack  ==> player1.opponent_attack
  player2.defence ==> player1.opponent_defence
}

Operations(in pool t)            //Operations models player behavior.
{                               //Added units of measurement to expressions.
  pool opponent_attack          //opponent attack
  pool opponent_defence         //opponent defence
  auto pool turns of Turn at 100   //
  pool resources of Gold           //Gold resources (used for purchases)
  pool factories of Factory at 1   //factories producing income (start with 1)
  pool defence of Defence, Attack  //defending Attack and Defence units
  pool attack of Attack            //attacking Attack units
  drain killed of Defence, Attack  //drain kills attack or defence
  auto drain destroyed of Factory     //drain destroys factories (* pulls all)
  push all converter takeTurn from Turn to Gold      //convert a Turn into Gold
  push all converter buyDefence from Gold to Defence //convert all required Gold to Defence
  push all converter buyAttack from Gold to Attack   //convert all required Gold to Attack
  push all converter buyFactory from Gold to Factory //convert all required Gold to Factory

  turns --> takeTurn               //takeTurn consumes 1 Turn
  takeTurn -factories*0.25 Gold/Factory-> resources //flow 0.25 Gold/Factory * factories Factory to resources
  resources -5-> buyFactory        //buyFactory consumes 5 Gold from resources
  buyFactory --> factories         //buyFactory produces 1 Factory to factories
  resources -2-> buyDefence        //buyDefence consumes 2 Gold from resources
  buyDefence --> defence           //buyDefence produces 1 Defence to defence
  resources --> buyAttack          //buyAttack consumes 1 Gold from resources
  buyAttack --> attack             //buyAttack produces 1 Attack to attack

  factories -opponent_attack*25%-> destroyed //factories destuction rate
  defence -opponent_attack*25%-> killed      //defence casualty rate
  attack -opponent_defence*25%-> killed      //attack casualty rate
  defence .==0.> destroyed                   //zero defence enables destroyed
}