/*
  This test demonstates components, flow ranges and converters.
*/

Bird b1
Bird b2
b1.droppings -2..3-> road
b2.droppings -3..5-> road
b1.droppings2 --> road
b2.droppings2 --> road
pool road max 1000

Bird()
{
  source water
  source food
  auto pull all converter eat
  auto push pool droppings max 100
  auto push pool droppings2 max 500
  water -2-> eat
  food -2-> eat
  eat -3-> droppings
  eat -1-> droppings2
}
