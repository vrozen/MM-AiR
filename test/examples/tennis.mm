/*
  This experiment demonstrates nested component.
  Note: it does not function yet.
*/

Player p1
Player p2

p1.loose .=.> p2.win
p2.loose .=.> p1.win
p2.return .=.> p2.receive
p1.return .=.> p1.receive

Player(ref receive, ref return, ref win, ref loose)
{
  Score score
  Move move  
  win .=.> score.get
  move.miss .=.> loose
  receive .=.> return
  return .=.> move.return
}

Move(in receive, out miss, ref return)
{
  source ball
  drain miss
  auto push pool receive
  
  receive --> miss
  receive --> return
}

Score(out points, ref get)
{
  assert win : !(p1.score.points > p2.score.points + 10 && p1.score.points > 40) "player wins"

  pool points at 0

  source plusFifteen
  plusFifteen -15-> points

  source plusTen
  plusTen -10-> points

  points . <30  .> plusFifteen
  points . >=30 .> plusTen
  get .*.> plusFifteen
  get .*.> plusTen
}
