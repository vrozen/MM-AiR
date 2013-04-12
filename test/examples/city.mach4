/*
  This experiment demonstrates the use of components.
*/

Brewery beerKeg        //there is a brewery caled beerKeg
Inn whiteHorse         //there is an inn called White Horse
Inn dancingPony        //there is an inn called Dancing Pony
auto pool folk at 20   //there are tweny potential guests

beerKeg.ale .=.> whiteHorse.ale     //beerKeg is White Horse's exclusive ale supplier
beerKeg.ale .=.> dancingPony.ale    //beerKeg is Dancing Pony's exclusive ale supplier
folk -0..4-> whiteHorse.guests      //up to 4 guests enter White Horse
folk -0..8-> dancingPony.guests     //up to 6 guests enter Dancing Pony
dancingPony.guests -dancingPony.guests/2-> folk  //half the guests leave
whiteHorse.guests -whiteHorse.guests/3-> folk    //a third of the guests leave

/**
 * A Brewery is a place where ale is brewed.
 * @ale the available ale
 */
Brewery(out ale)     //the output of a Brewery is ale
{
  auto source brew   //ale magically appears
  pool ale max 10000 //a maximum of 1000 ale is stored
  brew -100-> ale    //ale is brewed 100 at a time
}

/**
 * An Inn is a place where guests can stay to eat and drink.
 * @ref ale refers to a supplier of ale
 * @inout guests of the inn can enter and leave
 */
Inn(ref ale, inout guests)
{
  Kitchen kitchen    //Inns have a kitchen
  Pub pub            //Inns have a pub
  auto pool account  //Inns actively keep an account
  auto pool guests   //Inns actively house guests
  
  ale -guests*5-> pub.ale                 //get ale from the suppier (estimate that each guest drinks 4 ale)
  kitchen.pancakes -guests-> pub.pancakes //get pancakes from the kitchen (estimate that each guest has pancakes)
  account .=.> pub.income
  guests .=.> pub.guests
  
  ale .=.> pub.ale
}

/**
 * A Kitchen is a place where pancakes are baked.
 * @out pancakes the available pancakes
 */
Kitchen(out pancakes)
{
  auto source cook  //the cook is a source of pancakes
  pool pancakes     //the kitchen stores pancakes
  cook -0..1-> pancakes //the cook sometimes bakes a pancake
}

/**
 * A Pub is a place where guests can eat pancakes and drink ale.
 * @in pancakes the pancakes that may be eaten
 * @in ale the ale that may be consumed
 * @ref guests refers to the guests
 * @ref income refers to the place where income is stored
 */
Pub(in pancakes, in ale, ref guests, ref income)
{
  auto pool ale max 500  
  auto pool pancakes max 10
  
  auto converter drink
  auto converter eat
  source gold
    
  ale -guests*0..4-> eat     //some guests eat
  ale -guests*1..10-> drink  //guests drink between 1 and 8 beers
  eat -2-> income
  drink -1-> income
}