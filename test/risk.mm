/*source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"*/

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
  pool armies
  
  auto pool my_turn
  turn --> my_turn
  
  source return
  return --> turn
  
  auto all pool card
  card .(cav + inf + art) < 5.> card
  my_turn --> card
  
  auto all converter xCav //exchange cavlery
  auto all converter xInf //exchange infantry
  auto all converter xArt //exchange artillery
  auto all converter xSet //exchange set  
  
  auto pool cav //cavalry
  auto pool inf //infantry
  auto pool art //artillery

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
  
  assert test : armies < 74 ""
}


