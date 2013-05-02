/*
Work in progress: Simple tower defence game.
Enemies hebben geen hit points.
Elke tower heeft een kans dat ie een enemy dood maakt. mogelijk kans dat ie het overleeft.
verschillende torens bouwen
ander effect dat ze ennemies dood maken
-- geld
-- kleine kans enemies raken --> meer geld
-- enemies veranderen in andere resource
-- basis reparatie torens

Onderwerpen micro torentjes
In het systeem klikken
Naderhand meerdere in het systeem hangen


*/

source tick

NormalTower n
pool money
pool enemy
money -=-> n.money
enemy -=-> n.enemies

NormalTower(ref money, ref enemies)
{
  pool tower
  user gate build
  money --> build
  build --> tower
  
  auto converter die
  enemies -tower*0.25-> die
  die --> money
}

