/*source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"*/

unit Army : "army unit type"
unit Turn : "player turn"
unit Card : "bonus card"

source upBonus
pool bonus at 10
upBonus -10-> bonus

pool turn at 1

Cards p1

turn .=.> p1.turn
bonus .=.> p1.bonus
upBonus .=.> p1.upBonus

Cards(ref bonus, ref turn, ref upBonus, out armies)
{
  pool armies of Army
  
  auto pool my_turn of Turn
  turn --> my_turn
  
  source return of Turn
  return --> turn
  
  auto all converter getCard from Turn to Card
  getCard .(cav + inf + art) < 5.> getCard
  my_turn --> getCard
  getCard --> card
  
  pool card of Card
  
  auto all converter xCav from Card to Army //exchange cavlery
  auto all converter xInf from Card to Army //exchange infantry
  auto all converter xArt from Card to Army //exchange artillery
  auto all converter xSet from Card to Army //exchange set  
  
  auto pool cav of Army at 6//cavalry
  auto pool inf of Army //infantry
  auto pool art of Army //artillery

  auto pool getMeABug at 0
  getMeABug .*.> getMeAnotherBug
  pool getMeAnotherBug at 0
  getMeAnotherBug -1-> getMeABug
  getMeABug -1-> getMeAnotherBug

  card --> cav card --> inf card --> art
  cav .*.> return
  inf .*.> return
  art .*.> return 

  my_turn --> xCav   cav -3-> xCav   xCav -(8 * bonus) / 10-> armies  
  my_turn --> xArt   art -3-> xArt   xArt -(4 * bonus) / 10-> armies
  my_turn --> xInf   inf -3-> xInf   xInf -(6 * bonus) / 10-> armies
  my_turn --> xSet   cav --> xSet inf --> xSet art --> xSet  xSet - bonus -> armies
 
  xCav .*.> return xCav .*.> upBonus  
  xArt .*.> return xArt .*.> upBonus
  xInf .*.> return xInf .*.> upBonus
  xSet .*.> return xSet .*.> upBonus
  
  assert ends : armies < 200 "ok"
}
