unit Water : "water"
unit Food : "food"
unit BirdPoo : "droppings"

source pond of Water
source lady of Food
drain road of BirdPoo
Bird heron
pond --> heron.drink
lady --> heron.eat
heron.droppings --> road

Bird(in water, out food, out droppings)
{
  auto pool drink //birds drink water
  auto pool eat  //birds eat food
  user converter digest //birds can digest
  pool droppings //birds can produce droppings
  drink --> digest   //birds digest water
  eat --> digest    //birds digest food
  eat -2-> droppings //birds produce droppings
}
