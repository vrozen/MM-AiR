/*
  This test demonstrates starvation in asynchronous time.
*/
auto push all pool oldLady at 10
assert ends : oldLady != 0 "ok"

Pond pond
oldLady .=.> pond.oldLady

Pond(ref oldLady)
{
  pull pool food
  auto pool happyDuck         //this duck always gets fed
  auto all pool starvingDuck  //in asynchonous time this duck starves
  
  oldLady -1-> food
  food --> happyDuck
  food -2-> starvingDuck
  
  assert starvation : starvingDuck == 0 "Starving ducks don't get fed"
}