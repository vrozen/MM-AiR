Oever l
Oever r

auto push pool b at 1  b --> l.boer
auto push pool k at 1  k --> l.kool
auto push pool g at 1  g --> l.geit
auto push pool w at 1  w --> l.wolf

l.boer --> r.boer  r.boer --> l.boer
l.kool --> r.kool  r.kool --> l.kool
l.wolf --> r.wolf  r.wolf --> l.wolf
l.geit --> r.geit  r.geit --> l.geit

Oever(inout boer, inout kool, inout wolf, inout geit)
{
  push pool boer 
  push pool kool
  push pool wolf
  push pool geit  

  auto source tick
  pool tock max 1
  tick --> tock
  tock --> goGeit
  tock --> goKool
  tock --> goWolf
  
  drain goGeit
  drain goKool
  drain goWolf
  drain goBoer

  boer . == 1 .> tick  
  goKool . boer == 1 && kool == 1 && geit != wolf .> goKool  
  goWolf . boer == 1 && wolf == 1 && geit != kool .> goWolf
  goGeit . boer == 1 && geit == 1 .> goGeit
  goBoer . boer == 1 .> goBoer
  
  tock .*.> goGeit
  tock .*.> goKool
  tock .*.> goWolf
  tock .*.> goBoer
  
  goGeit .*.> geit  goGeit .*.> boer
  goWolf .*.> wolf  goWolf .*.> boer
  goKool .*.> kool  goKool .*.> boer
  goBoer .*.> boer
  
  //assert eatKool : !(geit == kool && geit != boer) "de geit eet de kool op"
  //assert eatGeit : !(geit == wolf && wolf != boer) "de wolf eet de geit op"
}

assert bereikbaar: !(r.boer == 1 && r.kool == 1 && r.wolf == 1 && r.geit == 1)
  "De overkant bereiken is onmogelijk"
  
/*

// [file: kwg.max, started: 9-Feb-2005]
// A farmer has to get the cabbage, the wolf and the goat to the other
// side of a river but he can take only one item at once in his little boat.
// He also has to make sure the goat doesn't eat the cabbage and the wolf
// doesn't eat the goat when he is on the other side of the river.
int boer; int kool; int wolf; int geit; 
process Kwg{
  boer = kool = wolf = geit = 1;    //Start at this side of the river.
  do :: boer==kool && geit!=wolf -> //It is safe to
        boer = kool = boer % 2 + 1; //take the cabbage to the other side.
     :: boer==wolf && geit!=kool -> //It is safe to
        boer = wolf = boer % 2 + 1; //take the wolf to the other side.
     :: boer==wolf && boer==geit && boer!=kool -> //It is safe to
        boer = wolf = boer % 2 + 1; //take the wolf to the other side.
     :: boer==geit ->               //If the goat is on the same side
        boer = geit = boer % 2 + 1; //take the goat to the other side.
     :: boer = boer % 2 + 1;        //Go to the other side without an item.
  od;}
//Say there is no way to get every item to the other side safely.
[] !(boer==2 && kool==2 && wolf==2 && geit==2) //Which isn't true.

*/